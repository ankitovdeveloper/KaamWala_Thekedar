import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Thin HTTP layer over the Laravel API.
///
/// Every endpoint answers with the same envelope from `App\Traits\ApiResponse`:
/// ```json
/// { "success": true,  "message": "...", "data": { ... } }
/// { "success": false, "message": "...", "errors": { ... } }
/// ```
/// so unwrapping lives here once and callers only ever see `data` — or an
/// [ApiException].
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  String? _token;

  /// Called when the server rejects the token, so the app can bounce to login.
  void Function()? onUnauthorized;

  void setToken(String? token) => _token = token;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final base = Uri.parse('$_baseUrl/$normalized');

    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: '${entry.value}',
      },
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) => _send(
    () => _client.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) => _send(
    () => _client.put(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<dynamic> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  /// Runs the request, maps transport failures onto [ApiException], and
  /// returns the envelope's `data` field.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(ApiConfig.receiveTimeout);
    } on TimeoutException {
      throw const ApiException('Request timed out', kind: ApiErrorKind.timeout);
    } on SocketException catch (e) {
      throw ApiException(e.message, kind: ApiErrorKind.network);
    } on http.ClientException catch (e) {
      // Web throws ClientException for CORS/connection failures too.
      throw ApiException(e.message, kind: ApiErrorKind.network);
    }

    return _unwrap(response);
  }

  dynamic _unwrap(http.Response response) {
    final status = response.statusCode;

    // 204 and empty bodies are legitimate for DELETE / logout.
    if (response.body.isEmpty) {
      if (status >= 200 && status < 300) return null;
      throw ApiException('HTTP $status', statusCode: status);
    }

    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Envelope was not a JSON object');
      }
      json = decoded;
    } on FormatException {
      // A PHP fatal error or an HTML 404 page lands here.
      throw ApiException(
        'Unexpected response from server (HTTP $status)',
        statusCode: status,
        kind: ApiErrorKind.parse,
      );
    }

    final message = json['message'] as String? ?? 'HTTP $status';

    if (status == 401) {
      onUnauthorized?.call();
      throw ApiException(
        message,
        statusCode: status,
        kind: ApiErrorKind.unauthorized,
      );
    }

    final succeeded = json['success'] == true && status >= 200 && status < 300;
    if (!succeeded) {
      throw ApiException(
        message,
        statusCode: status,
        fieldErrors: _parseFieldErrors(json['errors']),
      );
    }

    return json['data'];
  }

  /// Laravel sends `errors` as `{field: [messages]}` on validation failures,
  /// but plain strings or null elsewhere.
  static Map<String, List<String>> _parseFieldErrors(dynamic errors) {
    if (errors is! Map) return const {};
    return {
      for (final entry in errors.entries)
        '${entry.key}': switch (entry.value) {
          final List<dynamic> list => list.map((e) => '$e').toList(),
          final Object value => ['$value'],
          _ => const <String>[],
        },
    };
  }

  void close() => _client.close();
}

/// Helpers for reading loosely-typed JSON without a null check at every field.
/// PHP/MySQL hand back numbers as strings often enough that this matters.
extension JsonMap on Map<String, dynamic> {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    return v == null ? fallback : '$v';
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  int intVal(String key, [int fallback = 0]) {
    final v = this[key];
    return switch (v) {
      final int i => i,
      final double d => d.round(),
      final String s =>
        int.tryParse(s) ?? double.tryParse(s)?.round() ?? fallback,
      _ => fallback,
    };
  }

  double dbl(String key, [double fallback = 0]) {
    final v = this[key];
    return switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? fallback,
      _ => fallback,
    };
  }

  /// Accepts `true`, `1`, `"1"`, `"true"` — all of which MySQL/PHP can produce.
  bool flag(String key, [bool fallback = false]) {
    final v = this[key];
    return switch (v) {
      final bool b => b,
      final num n => n != 0,
      final String s => s == '1' || s.toLowerCase() == 'true',
      _ => fallback,
    };
  }

  DateTime? date(String key) {
    final v = strOrNull(key);
    return v == null ? null : DateTime.tryParse(v)?.toLocal();
  }

  Map<String, dynamic>? mapOrNull(String key) {
    final v = this[key];
    return v is Map<String, dynamic> ? v : null;
  }

  List<Map<String, dynamic>> listOfMaps(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v.whereType<Map<String, dynamic>>().toList();
  }
}

/// Laravel's paginator wraps rows in `{data: [...], current_page, last_page…}`,
/// but some endpoints return a bare list. This accepts either.
List<Map<String, dynamic>> rowsOf(dynamic payload) {
  if (payload is List) {
    return payload.whereType<Map<String, dynamic>>().toList();
  }
  if (payload is Map<String, dynamic>) {
    final inner = payload['data'];
    if (inner is List) return inner.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}
