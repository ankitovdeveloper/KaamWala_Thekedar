import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/location/location_prompt.dart';
import 'package:kaamwala_thekedar/features/search/search_screen.dart';
import 'package:kaamwala_thekedar/features/shell/home_shell.dart';

/// The signed-in Thekedar, with the location freshness under test.
///
/// Pinned to Hinglish — `AppUser` defaults to `hi`, and these tests assert on
/// the copy in the base string table.
AppUser _thekedar({double? lat, double? lng, DateTime? stampedAt}) => AppUser(
  id: 1,
  name: 'Amit Khurana',
  phone: '9876543210',
  address: 'Sector 45',
  city: 'Gurgaon',
  latitude: lat,
  longitude: lng,
  locationUpdatedAt: stampedAt,
  language: 'hi-en',
);

/// A session with a signed-in user but no HTTP client, so nothing touches
/// `shared_preferences` (which has no implementation in a widget test).
({Widget widget, Session session}) _host(
  Widget child, {
  required AppUser user,
  MockRepository? repository,
  Size size = const Size(390, 844),
}) {
  final session = Session(
    repository: repository ?? MockRepository(latency: Duration.zero),
  )..updateUser(user);

  return (
    widget: SessionScope(
      session: session,
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: child,
        ),
      ),
    ),
    session: session,
  );
}

void main() {
  // Process-wide guard inside the prompt; a leaked "open" would silently stop
  // the next test's sheet from ever appearing.
  setUp(LocationPrompt.resetForTest);

  group('Location freshness', () {
    Session sessionWith(AppUser? user) {
      final session = Session(repository: MockRepository(latency: Duration.zero));
      addTearDown(session.dispose);
      if (user != null) session.updateUser(user);
      return session;
    }

    test('nobody signed in is never asked', () {
      expect(sessionWith(null).needsLocationUpdate, isFalse);
    });

    test('an account with no coordinates is asked', () {
      expect(sessionWith(_thekedar()).needsLocationUpdate, isTrue);
    });

    test('coordinates with no stamp are treated as unknown age', () {
      // The column is missing on older deploys, so "has a point, no idea when"
      // has to resolve to asking rather than to trusting it forever.
      final session = sessionWith(_thekedar(lat: 28.45, lng: 77.02));
      expect(session.needsLocationUpdate, isTrue);
    });

    test('a point saved just now is left alone', () {
      final session = sessionWith(
        _thekedar(lat: 28.45, lng: 77.02, stampedAt: DateTime.now()),
      );
      expect(session.needsLocationUpdate, isFalse);
    });

    test('a point saved under four hours ago is still trusted', () {
      final session = sessionWith(
        _thekedar(
          lat: 28.45,
          lng: 77.02,
          stampedAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 55)),
        ),
      );
      expect(session.needsLocationUpdate, isFalse);
    });

    test('past four hours it asks again', () {
      final session = sessionWith(
        _thekedar(
          lat: 28.45,
          lng: 77.02,
          stampedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 1)),
        ),
      );
      expect(session.needsLocationUpdate, isTrue);
    });

    test('a stamp from the future reads as fresh, not as overdue', () {
      // A device clock behind the server's must not produce a prompt on every
      // single launch.
      final session = sessionWith(
        _thekedar(
          lat: 28.45,
          lng: 77.02,
          stampedAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      expect(session.needsLocationUpdate, isFalse);
    });

    test('saveLocation starts the clock even with no server stamp', () {
      final session = sessionWith(_thekedar());
      expect(session.needsLocationUpdate, isTrue);

      // What an older deploy answers with: coordinates, no `location_updated_at`.
      session.saveLocation(_thekedar(lat: 19.07, lng: 72.87));
      expect(session.needsLocationUpdate, isFalse);
      expect(session.locationUpdatedAt, isNotNull);
    });
  });

  group('On-open prompt', () {
    testWidgets('opens the app asking where the Thekedar is', (tester) async {
      final host = _host(
        const HomeShell(),
        user: _thekedar(
          lat: 28.45,
          lng: 77.02,
          stampedAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      );
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();

      expect(find.text('Aap abhi kahan hain?'), findsOneWidget);

      // Skipping is always allowed — the old point still searches.
      await tester.tap(find.text('Baad mein'));
      await tester.pumpAndSettle();
      expect(find.text('Aap abhi kahan hain?'), findsNothing);
      // And because nothing was saved, the next open asks again.
      expect(host.session.needsLocationUpdate, isTrue);
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      final host = _host(
        const HomeShell(),
        user: _thekedar(
          lat: 28.45,
          lng: 77.02,
          stampedAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        size: const Size(320, 568),
      );
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();

      // An overflow paints as a FlutterError, which fails the test on its own.
      expect(find.text('Aap abhi kahan hain?'), findsOneWidget);

      await tester.tap(find.text('Baad mein'));
      await tester.pumpAndSettle();
    });

    testWidgets('stays out of the way when the point is fresh', (tester) async {
      final host = _host(
        const HomeShell(),
        user: _thekedar(
          lat: 28.45,
          lng: 77.02,
          stampedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      );
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();

      expect(find.text('Aap abhi kahan hain?'), findsNothing);
    });

    testWidgets('confirming the saved point re-stamps it and closes', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      final host = _host(
        const HomeShell(),
        user: _thekedar(
          lat: 28.45,
          lng: 77.02,
          stampedAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        repository: repo,
      );
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wahi jagah theek hai'));
      await tester.pumpAndSettle();

      // Same coordinates back to the server — the point of the call is the
      // freshness stamp it writes.
      expect(repo.sentLatitude, 28.45);
      expect(repo.sentLongitude, 77.02);
      // Older deploys 422 a location-only save without the name.
      expect(repo.sentName, 'Amit Khurana');
      expect(find.text('Aap abhi kahan hain?'), findsNothing);
      expect(host.session.needsLocationUpdate, isFalse);
    });
  });

  group('Search follows the saved location', () {
    testWidgets('a moved origin re-runs the same search from the new point', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      final host = _host(
        const SearchScreen(),
        user: _thekedar(lat: 28.45, lng: 77.02, stampedAt: DateTime.now()),
        repository: repo,
      );
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();

      expect(repo.searches, hasLength(1));
      expect(repo.searches.first.lat, 28.45);

      // What the prompt does once a new location is saved.
      host.session.saveLocation(
        _thekedar(lat: 19.07, lng: 72.87, stampedAt: DateTime.now()),
      );
      await tester.pumpAndSettle();

      expect(repo.searches, hasLength(2));
      expect(repo.searches.last.lat, 19.07);
      expect(repo.searches.last.lng, 72.87);
      // Same search, from somewhere else: the filters ride along untouched.
      expect(repo.searches.last.skillId, repo.searches.first.skillId);
      expect(repo.searches.last.radiusKm, repo.searches.first.radiusKm);
      expect(repo.searches.last.sort, repo.searches.first.sort);
    });

    testWidgets('a session change that did not move the pin fetches nothing', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      final host = _host(
        const SearchScreen(),
        user: _thekedar(lat: 28.45, lng: 77.02, stampedAt: DateTime.now()),
        repository: repo,
      );
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();
      expect(repo.searches, hasLength(1));

      // A language switch notifies every listener too.
      await host.session.setLanguage('en');
      await tester.pumpAndSettle();

      expect(repo.searches, hasLength(1));
    });
  });
}

/// Mock repository that remembers what search and profile calls were made with.
class _RecordingRepository extends MockRepository {
  _RecordingRepository() : super(latency: Duration.zero);

  final searches =
      <({double lat, double lng, int? skillId, int? radiusKm, LabourSort sort})>[];

  String? sentName;
  double? sentLatitude;
  double? sentLongitude;

  @override
  Future<List<Labour>> searchLabours({
    required double lat,
    required double lng,
    int? skillId,
    String? query,
    int? radiusKm,
    LabourSort sort = LabourSort.distance,
  }) {
    searches.add((
      lat: lat,
      lng: lng,
      skillId: skillId,
      radiusKm: radiusKm,
      sort: sort,
    ));
    return super.searchLabours(
      lat: lat,
      lng: lng,
      skillId: skillId,
      query: query,
      radiusKm: radiusKm,
      sort: sort,
    );
  }

  @override
  Future<AppUser> updateProfile({
    String? name,
    String? email,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    sentName = name;
    sentLatitude = latitude;
    sentLongitude = longitude;
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
