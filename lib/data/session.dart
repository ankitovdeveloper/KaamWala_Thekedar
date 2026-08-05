import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_strings.dart';
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
  static const _languageKey = 'kw.pref.language';

  final ApiClient? _client;
  late final KaamWalaRepository _repository;

  KaamWalaRepository get repo => _repository;

  AppUser? _user;
  AppUser? get user => _user;

  /// Language for anyone not signed in yet — the login and OTP screens have no
  /// user to read `users.language` from, so the last choice is kept locally.
  String _localLanguage = AppLanguage.hinglish.wire;

  /// The signed-in user's language wins; before that, the local preference.
  String get language => _user?.language ?? _localLanguage;

  /// String table for [language]. Read through `context.s` from widgets.
  AppStrings get strings => AppStrings.forCode(language);

  /// Switches language without a signed-in user (or ahead of the server round
  /// trip). Account Settings still persists the choice through
  /// `PUT /thekedar/account/preferences`; this only keeps the UI in step.
  Future<void> setLanguage(String code) async {
    if (code == _localLanguage && _user == null) return;
    _localLanguage = code;
    if (_user != null) _user = _user!.copyWith(language: code);
    notifyListeners();
    await _persistLanguage(code);
  }

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

      // Language first: the login screen must already be in the right language
      // even when there is no token to restore.
      final saved = prefs.getString(_languageKey);
      if (saved != null && saved.isNotEmpty) _localLanguage = saved;

      if (token != null && token.isNotEmpty) {
        _client.setToken(token);
        if (cached != null) {
          try {
            _user = AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
          } on Object {
            // A cache written by an older build — fall through to `me()`.
          }
        }

        if (_user != null) {
          // Open the app on the cached identity straight away and confirm the
          // token in the background. Waiting on `me()` here would hold the
          // splash for the full receive timeout on a slow or dead network, and
          // a 401 still bounces to login through onUnauthorized.
          _restored = true;
          notifyListeners();
          unawaited(_refreshUser());
          return;
        }

        // No usable cache, so the server is the only thing that knows who this
        // token belongs to — this one has to be awaited.
        try {
          _user = await _repository.me();
          await _persistUser(_user!);
        } on Object {
          // Offline with nothing cached: start at login rather than in a shell
          // with no user.
        }
      }
    } on Object {
      // A corrupt prefs entry must never block startup.
    }

    _restored = true;
    notifyListeners();
  }

  /// Re-reads `GET /me` behind an already-open app, so a profile changed on
  /// another device shows up without a sign-out.
  Future<void> _refreshUser() async {
    try {
      final fresh = await _repository.me();
      _user = fresh;
      notifyListeners();
      await _persistUser(fresh);
    } on Object {
      // Offline or server down — the cached user stands.
    }
  }

  Future<void> signIn(AuthResult result) async {
    _user = result.user;
    // Carry the account's language into the local preference so logging out
    // doesn't snap the login screen back to the default.
    _localLanguage = result.user.language;
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
    _localLanguage = user.language;
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
      // Mirror the language so the next cold start renders the login screen
      // correctly before the cached user has been read back.
      await prefs.setString(_languageKey, user.language);
    } on Object {
      // Caching the user is an optimisation, not a requirement.
    }
  }

  Future<void> _persistLanguage(String code) async {
    if (_client == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, code);
    } on Object {
      // Falls back to the default on the next start; not worth failing over.
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

  /// Localised strings for the current user's language.
  ///
  /// Subscribes to the session, so changing the language in Account Settings
  /// rebuilds every screen that reads this. Outside a [SessionScope] — a
  /// widget pumped bare in a test — it falls back to the base (Hinglish)
  /// table rather than asserting.
  AppStrings get s {
    final scope = dependOnInheritedWidgetOfExactType<SessionScope>();
    return scope?.notifier?.strings ?? AppStrings.hinglish;
  }
}
