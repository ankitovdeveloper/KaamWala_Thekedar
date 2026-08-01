import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/api_config.dart';
import 'models/models.dart';
import 'repositories/api_repository.dart';
import 'repositories/kaamwala_repository.dart';
import 'repositories/mock_repository.dart';

/// Holds the signed-in user and the Sanctum token, and hands the rest of the
/// app its [KaamWalaRepository].
///
/// The token survives restarts via `shared_preferences`; a 401 from any call
/// clears it and flips [isAuthenticated], which the app listens to in order to
/// bounce back to login.
class Session extends ChangeNotifier {
  Session({KaamWalaRepository? repository, ApiClient? client})
    : _client = client ?? (repository == null ? ApiClient() : null) {
    _repository =
        repository ??
        (ApiConfig.useMocks ? MockRepository() : ApiRepository(_client!));
    _client?.onUnauthorized = _onUnauthorized;
  }

  /// Test/demo constructor: no HTTP, no persistence.
  factory Session.mock({Duration latency = Duration.zero}) =>
      Session(repository: MockRepository(latency: latency));

  static const _tokenKey = 'kw.auth.token';
  static const _userKey = 'kw.auth.user';

  final ApiClient? _client;
  late final KaamWalaRepository _repository;

  KaamWalaRepository get repo => _repository;

  AppUser? _user;
  AppUser? get user => _user;

  bool _restored = false;

  /// True once [restore] has run, so the app knows whether to keep the splash.
  bool get isRestored => _restored;

  bool get isAuthenticated =>
      _user != null && (_client == null || _client.isAuthenticated);

  /// Reads any persisted token on cold start. Falls back to the cached user if
  /// the network is down, so the app opens offline instead of forcing a login.
  Future<void> restore() async {
    if (_client == null) {
      // Mock session: nothing to restore, start signed out at the login screen.
      _restored = true;
      notifyListeners();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final cached = prefs.getString(_userKey);

      if (token != null && token.isNotEmpty) {
        _client.setToken(token);
        if (cached != null) {
          _user = AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
        // Confirm the token is still good; a 401 clears it via onUnauthorized.
        try {
          _user = await _repository.me();
          await _persistUser(_user!);
        } on Object {
          // Offline or server down — keep the cached user and carry on.
        }
      }
    } on Object {
      // A corrupt prefs entry must never block startup.
    }

    _restored = true;
    notifyListeners();
  }

  Future<void> signIn(AuthResult result) async {
    _user = result.user;
    _client?.setToken(result.token);
    notifyListeners();

    // Persistence is a convenience, not part of being signed in — a storage
    // failure (or a mock session with no platform plugins) must not block the
    // user from getting into the app.
    if (_client == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, result.token);
      await _persistUser(result.user);
    } on Object {
      // Next cold start will just ask for the OTP again.
    }
  }

  Future<void> signOut() async {
    // Best-effort server-side revoke; local state is cleared either way.
    try {
      await _repository.logout();
    } on Object {
      // Already invalid, or offline — nothing more to do.
    }
    await _clear();
  }

  /// Keeps the cached user in step after a profile or preferences change.
  void updateUser(AppUser user) {
    _user = user;
    unawaited(_persistUser(user));
    notifyListeners();
  }

  void _onUnauthorized() {
    // The server rejected the token; drop it and let the app route to login.
    unawaited(_clear());
  }

  Future<void> _clear() async {
    _user = null;
    _client?.setToken(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } on Object {
      // Nothing to clean up.
    }
    notifyListeners();
  }

  Future<void> _persistUser(AppUser user) async {
    if (_client == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } on Object {
      // Caching the user is an optimisation, not a requirement.
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}

/// Fire-and-forget without pulling in `dart:async` at every call site.
void unawaited(Future<void> future) {
  future.catchError((Object _) {});
}

/// Puts the [Session] in the tree. `context.session` / `context.repo` read it.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({
    super.key,
    required Session session,
    required super.child,
  }) : super(notifier: session);

  static Session of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget');
    return scope!.notifier!;
  }

  /// Reads without subscribing — for callbacks that only need the repository.
  static Session read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget');
    return scope!.notifier!;
  }
}

extension SessionContext on BuildContext {
  Session get session => SessionScope.of(this);

  /// The repository, without subscribing to session changes.
  KaamWalaRepository get repo => SessionScope.read(this).repo;
}
