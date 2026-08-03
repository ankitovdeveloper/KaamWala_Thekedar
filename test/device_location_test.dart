import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:kaamwala_thekedar/core/location/device_location.dart';
import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/api/api_config.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/location/location_picker_screen.dart';
import 'package:kaamwala_thekedar/widgets/kw_map.dart';

/// Stands in for the native geolocator so the picker's GPS button can be driven
/// from a widget test.
///
/// Without this the real channel has no implementation and its
/// `MissingPluginException` is delivered on the real event loop, which
/// `tester.pump` cannot advance — so the button would appear to hang.
class _FakeGeolocator {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position = const {'latitude': 19.076, 'longitude': 72.8777},
  });

  bool serviceEnabled;
  LocationPermission permission;
  Map<String, dynamic>? position;

  /// Set when `requestPermission` was reached, to prove the flow stops early
  /// when the device's location switch is off.
  var didRequestPermission = false;

  static const _channel = MethodChannel('flutter.baseflow.com/geolocator');

  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'isLocationServiceEnabled':
          return serviceEnabled;
        case 'checkPermission':
          // Report "denied" so the flow always goes through the request step,
          // which is the real first-run path.
          return LocationPermission.denied.index;
        case 'requestPermission':
          didRequestPermission = true;
          return permission.index;
        case 'getCurrentPosition':
        case 'getLastKnownPosition':
          return position;
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  }
}

/// The picker in isolation. [language] is a wire code, set on the session the
/// same way Account Settings does, so copy can be asserted in more than one
/// language.
({Widget widget, Session session}) host({String? language}) {
  final session = Session(repository: MockRepository(latency: Duration.zero));
  if (language != null) {
    session.updateUser(
      AppUser(id: 1, name: 'Amit', phone: '9876543210', language: language),
    );
  }
  return (
    widget: SessionScope(
      session: session,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: LocationPickerScreen(),
        ),
      ),
    ),
    session: session,
  );
}

/// Taps the labelled GPS button and lets the fix resolve.
///
/// Never `pumpAndSettle`: the busy spinner is an indeterminate animation that
/// keeps scheduling frames, so a settle would time out.
Future<void> tapCurrentLocation(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

String snackText(WidgetTester tester) => tester
    .widget<Text>(
      find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
          .first,
    )
    .data!;

void main() {
  group('Placemark → address + city', () {
    test('Android shape: the whole first line arrives in street', () {
      final described = DeviceLocationService.describe(
        const Placemark(
          street: '42, Sector 14 Main Road',
          subLocality: 'Sector 14',
          locality: 'Gurgaon',
          administrativeArea: 'Haryana',
          postalCode: '122001',
        ),
      );

      expect(described.city, 'Gurgaon');
      // `subLocality` is already spelled inside `street`, so it must not be
      // repeated; the postcode is new information and is kept.
      expect(described.address, '42, Sector 14 Main Road, 122001');
    });

    test('iOS shape: the first line is split across thoroughfare parts', () {
      final described = DeviceLocationService.describe(
        const Placemark(
          subThoroughfare: '42',
          thoroughfare: 'MG Road',
          subLocality: 'Ashok Nagar',
          locality: 'Gurgaon',
        ),
      );

      expect(described.city, 'Gurgaon');
      expect(described.address, '42, MG Road, Ashok Nagar');
    });

    test('the city never leaks into the address line', () {
      final described = DeviceLocationService.describe(
        const Placemark(street: 'Gurgaon', locality: 'Gurgaon'),
      );

      expect(described.city, 'Gurgaon');
      expect(
        described.address,
        isNull,
        reason: 'the only segment was the city, which has its own field',
      );
    });

    test('city falls back through the administrative areas', () {
      expect(
        DeviceLocationService.describe(
          const Placemark(
            subAdministrativeArea: 'Gurgaon',
            administrativeArea: 'Haryana',
          ),
        ).city,
        'Gurgaon',
      );
      expect(
        DeviceLocationService.describe(
          const Placemark(administrativeArea: 'Haryana'),
        ).city,
        'Haryana',
      );
    });

    test('an empty placemark yields nothing rather than blank strings', () {
      final described = DeviceLocationService.describe(
        const Placemark(street: '   ', locality: ''),
      );

      expect(described.address, isNull);
      expect(described.city, isNull);
    });
  });

  group('Location picker', () {
    testWidgets('offers the current-location route alongside the manual ones', (
      tester,
    ) async {
      final under = host();
      addTearDown(under.session.dispose);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();

      expect(find.text('Meri current location lein'), findsOneWidget);
      // The manual routes are still there — GPS is an addition, not a swap.
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Sheher'), findsOneWidget);
      expect(find.text('Yahi location use karein'), findsOneWidget);
      // No maps key under test, so the pill shows the type-it-in hint.
      expect(find.text('Address type karein'), findsOneWidget);
    });

    testWidgets('a granted fix moves the pin', (tester) async {
      final under = host();
      addTearDown(under.session.dispose);
      _FakeGeolocator().install(tester);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();

      // Starts on the Gurgaon fallback, since the session has no user.
      expect(
        tester.widget<KwMap>(find.byType(KwMap)).center.lat,
        ApiConfig.fallbackLat,
      );

      await tapCurrentLocation(tester, 'Meri current location lein');

      // Reverse geocoding has no implementation under test, so this is the
      // coordinates-only outcome: a success, with a nudge to type the label.
      expect(
        snackText(tester),
        'Location mil gaya, par address nahi mila — khud likh dein',
      );
      expect(
        tester.widget<KwMap>(find.byType(KwMap)).center.lat,
        closeTo(19.076, 0.0001),
      );
    });

    testWidgets('a fix never blanks out an address already typed', (
      tester,
    ) async {
      final under = host();
      addTearDown(under.session.dispose);
      _FakeGeolocator().install(tester);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Plot 7, site gate');
      await tapCurrentLocation(tester, 'Meri current location lein');

      expect(find.text('Plot 7, site gate'), findsOneWidget);
    });

    testWidgets('a switched-off GPS is named, and never asks for permission', (
      tester,
    ) async {
      final under = host();
      addTearDown(under.session.dispose);
      final fake = _FakeGeolocator(serviceEnabled: false);
      fake.install(tester);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();
      await tapCurrentLocation(tester, 'Meri current location lein');

      expect(snackText(tester), 'Phone ka location (GPS) band hai');
      expect(
        fake.didRequestPermission,
        isFalse,
        reason: 'a grant is useless while the radio is off',
      );
      // Fixable from here, so the shortcut is offered.
      expect(find.text('Settings kholein'), findsOneWidget);
    });

    testWidgets('a one-off refusal is not sent to Settings', (tester) async {
      final under = host();
      addTearDown(under.session.dispose);
      _FakeGeolocator(permission: LocationPermission.denied).install(tester);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();
      await tapCurrentLocation(tester, 'Meri current location lein');

      expect(snackText(tester), 'Location ki permission nahi mili');
      expect(
        find.text('Settings kholein'),
        findsNothing,
        reason: 'tapping the button again is the fix, not a settings trip',
      );
    });

    testWidgets('a blocked permission points at Settings', (tester) async {
      final under = host();
      addTearDown(under.session.dispose);
      _FakeGeolocator(
        permission: LocationPermission.deniedForever,
      ).install(tester);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();
      await tapCurrentLocation(tester, 'Meri current location lein');

      expect(
        snackText(tester),
        'Location permission band hai. Settings se allow karein.',
      );
      expect(find.text('Settings kholein'), findsOneWidget);
    });

    testWidgets('failures are spelled in the chosen language', (tester) async {
      final under = host(language: 'en');
      addTearDown(under.session.dispose);
      _FakeGeolocator(serviceEnabled: false).install(tester);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();
      await tapCurrentLocation(tester, 'Use my current location');

      expect(snackText(tester), 'Location (GPS) is turned off on this phone');
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('a fix with no coordinates at all is reported, not thrown', (
      tester,
    ) async {
      final under = host();
      addTearDown(under.session.dispose);
      // Neither a live fix nor a last-known one — the true dead end.
      _FakeGeolocator(position: null).install(tester);

      await tester.pumpWidget(under.widget);
      await tester.pumpAndSettle();
      await tapCurrentLocation(tester, 'Meri current location lein');

      expect(snackText(tester), 'Location nahi mil paya. Dobara try karein.');
      expect(tester.takeException(), isNull);
      // Not a dead end for the user: saving by hand still works from here.
      expect(find.text('Yahi location use karein'), findsOneWidget);
    });
  });
}
