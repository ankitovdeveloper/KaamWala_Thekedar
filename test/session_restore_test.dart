import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaamwala_thekedar/app.dart';
import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/api/api_client.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/location/location_picker_screen.dart';
import 'package:kaamwala_thekedar/widgets/kw_bottom_nav.dart';

/// The token and user keys [Session] persists under.
const _tokenKey = 'kw.auth.token';
const _userKey = 'kw.auth.user';

const _cachedUser = {
  'id': 7,
  'name': 'Amit Khurana',
  'phone': '9876543210',
  'country_code': '+91',
  'role': 'thekedar',
  'city': 'Gurgaon',
  'language': 'hi-en',
};

/// Never actually reached — the repository under test is the mock one. It only
/// exists so [Session] takes the persisted-token path instead of short-circuiting
/// the way an injected repository with no client does.
class _UnusedHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw StateError('No HTTP expected: ${request.url}');
}

Session _sessionWithClient() => Session(
  repository: MockRepository(latency: Duration.zero),
  client: ApiClient(
    client: _UnusedHttpClient(),
    baseUrl: 'http://127.0.0.1:8000/api/v1',
  ),
);

/// Records what reaches `POST /thekedar/profile`.
class _RecordingRepository extends MockRepository {
  _RecordingRepository() : super(latency: Duration.zero);

  bool called = false;
  String? sentName;
  String? sentAddress;
  double? sentLatitude;

  @override
  Future<AppUser> updateProfile({
    String? name,
    String? email,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    called = true;
    sentName = name;
    sentAddress = address;
    sentLatitude = latitude;
    return super.updateProfile(
      name: name,
      email: email,
      city: city,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

/// Puts [child] on a pushed route so the screen under test has something to pop
/// back to, the way it does in the real app.
Widget _pushed(Widget child, Session session) => SessionScope(
  session: session,
  child: MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
        disableAnimations: true,
      ),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => child),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// "Use this location" sits below the map and the saved-address list, so it is
/// off-screen on a phone-sized viewport until scrolled to.
Future<void> _tapSave(WidgetTester tester) async {
  final button = find.text('Yahi location use karein');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('Cold start', () {
    testWidgets('a persisted token opens the shell instead of login', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        _tokenKey: 'sanctum-token',
        _userKey: jsonEncode(_cachedUser),
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: KaamWalaApp(session: _sessionWithClient()),
        ),
      );
      await tester.pumpAndSettle();

      // Search, not the phone-number form.
      expect(find.byType(KwBottomNav), findsOneWidget);
      expect(find.text('OTP Bhejo'), findsNothing);
    });

    testWidgets('no persisted token still lands on login', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: KaamWalaApp(session: _sessionWithClient()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OTP Bhejo'), findsOneWidget);
      expect(find.byType(KwBottomNav), findsNothing);
    });

    test('restore does not wait on /me when a cached user is available', () async {
      SharedPreferences.setMockInitialValues({
        _tokenKey: 'sanctum-token',
        _userKey: jsonEncode(_cachedUser),
      });

      final session = _sessionWithClient();
      await session.restore();

      expect(session.isRestored, isTrue);
      expect(session.isAuthenticated, isTrue);
      expect(session.user!.name, 'Amit Khurana');
      // The account's language came back with it, so the UI opens translated.
      expect(session.language, 'hi-en');
    });

    test('a corrupt cached user does not block startup', () async {
      SharedPreferences.setMockInitialValues({
        _tokenKey: 'sanctum-token',
        _userKey: 'not json',
      });

      final session = Session(
        repository: MockRepository(latency: Duration.zero),
        client: ApiClient(
          client: _UnusedHttpClient(),
          baseUrl: 'http://127.0.0.1:8000/api/v1',
        ),
      );
      await session.restore();

      // Falls through to the repository, which is the mock user here.
      expect(session.isRestored, isTrue);
      expect(session.isAuthenticated, isTrue);
    });
  });

  group('Location picker', () {
    testWidgets('sends the current name, which the server requires', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      final session = Session(repository: repo)
        ..updateUser(
          AppUser.fromJson(Map<String, dynamic>.from(_cachedUser)),
        );

      await tester.pumpWidget(_pushed(const LocationPickerScreen(), session));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Sector 45');
      await _tapSave(tester);

      expect(repo.called, isTrue);
      // Omitting this is what produced "The name field is required".
      expect(repo.sentName, 'Amit Khurana');
      expect(repo.sentAddress, 'Sector 45');
      expect(repo.sentLatitude, isNotNull);
    });

    testWidgets('still refuses a save with no address or city', (tester) async {
      final repo = _RecordingRepository();
      final session = Session(repository: repo)
        ..updateUser(
          AppUser.fromJson(Map<String, dynamic>.from(_cachedUser)),
        );

      await tester.pumpWidget(_pushed(const LocationPickerScreen(), session));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The prefill carries the user's city, so clear both fields first.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.enterText(find.byType(TextField).last, '');
      await _tapSave(tester);

      expect(repo.called, isFalse);
      expect(find.text('Address ya sheher daalein'), findsOneWidget);
    });
  });
}
