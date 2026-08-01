import '../../core/i18n/app_strings.dart';

/// A failed API call, already translated into something a screen can show.
///
/// The backend answers errors with `{success:false, message, errors}`
/// (`App\Traits\ApiResponse::error`), and Laravel's validator adds a
/// field-keyed `errors` map on 422 — both are preserved here.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
    this.kind = ApiErrorKind.server,
  });

  final String message;
  final int? statusCode;

  /// Laravel 422 shape: `{"phone": ["The phone field is required."]}`.
  final Map<String, List<String>> fieldErrors;
  final ApiErrorKind kind;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;

  /// First validation message for [field], if the server flagged it.
  String? fieldError(String field) => fieldErrors[field]?.firstOrNull;

  /// Message safe to drop straight into a snackbar, in the user's language for
  /// the cases the backend can't phrase itself.
  ///
  /// `server` errors keep the backend's own wording: it is the only party that
  /// knows what actually went wrong, and it already answers in a readable
  /// sentence.
  String userMessageIn(AppStrings s) => switch (kind) {
    ApiErrorKind.network => s.errNetwork,
    ApiErrorKind.timeout => s.errTimeout,
    ApiErrorKind.parse => s.errParse,
    ApiErrorKind.unauthorized => s.errUnauthorized,
    ApiErrorKind.server => message,
  };

  /// Hinglish shorthand for callers with no `BuildContext` (logs, tests).
  String get userMessage => userMessageIn(AppStrings.hinglish);

  @override
  String toString() => 'ApiException($statusCode, $kind): $message';
}

enum ApiErrorKind { network, timeout, parse, unauthorized, server }
