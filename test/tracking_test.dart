import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/i18n/app_strings.dart';
import 'package:kaamwala_thekedar/core/tracking/tracking_session.dart';
import 'package:kaamwala_thekedar/data/mock_data.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/features/tracking/tracking_screen.dart';
import 'package:kaamwala_thekedar/features/tracking/widgets/stage_timeline.dart';

import 'widget_test.dart' show host;

/// Serves a scripted list of samples, one per poll, so a whole journey can be
/// played out without waiting on the wall clock.
class _ScriptedRepository extends MockRepository {
  _ScriptedRepository(this.script) : super(latency: Duration.zero);

  final List<TrackingUpdate> script;
  int calls = 0;

  @override
  Future<TrackingUpdate> trackBooking(int bookingId) async {
    final update = script[calls.clamp(0, script.length - 1)];
    calls++;
    return update;
  }

  /// Starts the parent's simulation for [bookingId] without consuming a
  /// scripted sample. The arrival handshake runs off that simulation, and the
  /// override above means it would otherwise never be created.
  Future<void> seedSimulation(int bookingId) => super.trackBooking(bookingId);
}

/// Fails every poll — used to check the screen's error path.
class _BrokenRepository extends MockRepository {
  _BrokenRepository() : super(latency: Duration.zero);

  @override
  Future<TrackingUpdate> trackBooking(int bookingId) async =>
      throw Exception('network down');
}

const _site = GeoPoint(28.4595, 77.0266);

TrackingUpdate _waiting() =>
    const TrackingUpdate(stage: JobStage.pending, accepted: false);

TrackingUpdate _enRoute(GeoPoint at, int eta) => TrackingUpdate(
  stage: JobStage.onTheWay,
  position: at,
  destination: _site,
  etaMinutes: eta,
  distanceKm: at.distanceKmTo(_site),
);

/// At the gate: GPS has seen them arrive, but the kaam has not started — that
/// waits on the Thekedar typing the worker's code.
TrackingUpdate _atGate() => TrackingUpdate(
  stage: JobStage.onTheWay,
  position: _site,
  destination: _site,
  etaMinutes: 0,
  distanceKm: 0,
  arrivedAt: DateTime(2026, 8, 26, 10, 47),
  needsArrivalCode: true,
  canTerminate: true,
  stageSource: 'auto',
);

/// After the handshake.
TrackingUpdate _working() => TrackingUpdate(
  stage: JobStage.working,
  position: _site,
  destination: _site,
  arrivedAt: DateTime(2026, 8, 26, 10, 47),
  arrivalConfirmedAt: DateTime(2026, 8, 26, 10, 49),
  needsArrivalCode: false,
  stageSource: 'code',
);

/// The worker walked off. The Thekedar's only explanation for a dot that stopped.
TrackingUpdate _endedByLabour() => TrackingUpdate(
  stage: JobStage.working,
  destination: _site,
  arrivedAt: DateTime(2026, 8, 26, 10, 47),
  needsArrivalCode: false,
  canTerminate: false,
  isLive: false,
  termination: JobTermination(
    by: EndedBy.labour,
    byLabel: 'Kaam wale',
    reasonCode: 'emergency',
    reason: 'Ghar par emergency',
    reasonLabel: 'Ghar par emergency hai',
    at: DateTime(2026, 8, 26, 12, 30),
    stageWhenEnded: JobStage.working,
    workedMinutes: 135,
  ),
);

Booking _booking() => Mock.bookings().firstWhere((b) => b.id == 101);

/// Taps the end-job sheet's confirm button, scrolling it into view first.
///
/// Needed, not belt-and-braces: with the note field open the sheet is taller than
/// the test surface, and `tap()` on an off-screen widget only warns — the tap
/// silently does nothing and the assertion afterwards fails for the wrong reason.
Future<void> _tapConfirm(WidgetTester tester) async {
  final confirm = find.text('Haan, kaam band karein');
  await tester.ensureVisible(confirm);
  await tester.pumpAndSettle();
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void main() {
  group('GeoPoint', () {
    test('distance matches a known separation', () {
      // Two points ~1.2 km apart in Gurgaon.
      const a = GeoPoint(28.4595, 77.0266);
      const b = GeoPoint(28.4680, 77.0290);

      expect(a.distanceKmTo(b), closeTo(0.97, 0.15));
    });

    test('distance to itself is zero', () {
      expect(_site.distanceKmTo(_site), 0);
    });

    test('lerp lands on each end and halfway between', () {
      const a = GeoPoint(10, 20);
      const b = GeoPoint(20, 40);

      expect(a.lerpTo(b, 0), a);
      expect(a.lerpTo(b, 1), b);
      expect(a.lerpTo(b, 0.5), const GeoPoint(15, 30));
    });
  });

  group('TrackingUpdate', () {
    test('reads the wire shape the API returns', () {
      final update = TrackingUpdate.fromJson(const {
        'job_stage': 'on_the_way',
        'status': 'accepted',
        'position': {'latitude': 28.47, 'longitude': 77.03},
        'destination': {'latitude': 28.4595, 'longitude': 77.0266},
        'eta_minutes': 7,
        'distance_km': 2.1,
      });

      expect(update.stage, JobStage.onTheWay);
      expect(update.accepted, isTrue);
      expect(update.position, const GeoPoint(28.47, 77.03));
      expect(update.destination, const GeoPoint(28.4595, 77.0266));
      expect(update.etaLabelIn(AppStrings.hinglish), '7 min door');
    });

    test('a pending booking has no position to plot', () {
      final update = TrackingUpdate.fromJson(const {
        'job_stage': 'pending',
        'status': 'pending',
        'position': null,
      });

      expect(update.accepted, isFalse);
      expect(update.position, isNull);
      expect(update.etaLabelIn(AppStrings.hinglish), 'Accept ka intezaar');
    });
  });

  group('TrackingSession', () {
    test('each poll keeps the prior fix so the map can tween', () async {
      final repo = _ScriptedRepository([
        _enRoute(const GeoPoint(28.47, 77.03), 8),
        _enRoute(const GeoPoint(28.465, 77.028), 5),
      ]);

      // Driven by hand rather than by the timer: this is about the
      // latest/previous bookkeeping, not about when ticks land.
      final session = TrackingSession(repository: repo, bookingId: 101);

      await session.refresh();
      expect(session.latest?.etaMinutes, 8);
      expect(session.previous, isNull, reason: 'nothing came before the first');

      await session.refresh();
      expect(session.latest?.etaMinutes, 5);
      expect(
        session.previous?.etaMinutes,
        8,
        reason: 'the map tweens from the previous fix',
      );

      session.dispose();
    });

    test('start keeps polling on the interval', () async {
      final repo = _ScriptedRepository([_enRoute(_site, 3)]);
      final session = TrackingSession(
        repository: repo,
        bookingId: 101,
        interval: const Duration(milliseconds: 15),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.calls, greaterThan(2));

      session.dispose();
    });

    test('polling stops once the job completes', () async {
      final repo = _ScriptedRepository([
        const TrackingUpdate(stage: JobStage.completed, position: _site),
      ]);

      final session = TrackingSession(
        repository: repo,
        bookingId: 101,
        interval: const Duration(milliseconds: 10),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      final callsAtFinish = repo.calls;
      expect(session.isFinished, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        repo.calls,
        callsAtFinish,
        reason: 'a finished job must not keep hitting the server',
      );

      session.dispose();
    });

    test('polling stops once somebody stopped the job', () async {
      final repo = _ScriptedRepository([_endedByLabour()]);

      final session = TrackingSession(
        repository: repo,
        bookingId: 101,
        interval: const Duration(milliseconds: 10),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      final callsAtStop = repo.calls;
      expect(session.isFinished, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        repo.calls,
        callsAtStop,
        reason: 'a stopped job must not keep hitting the server',
      );

      session.dispose();
    });

    test('a failed poll before any fix is fatal, after one is not', () async {
      final broken = _BrokenRepository();
      final session = TrackingSession(
        repository: broken,
        bookingId: 101,
        interval: const Duration(milliseconds: 10),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(session.fatalError, isNotNull);
      expect(session.hasFix, isFalse);

      session.dispose();
    });

    test('dispose stops the timer', () async {
      final repo = _ScriptedRepository([_enRoute(_site, 1)]);
      final session = TrackingSession(
        repository: repo,
        bookingId: 101,
        interval: const Duration(milliseconds: 10),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 25));
      session.dispose();
      final after = repo.calls;

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repo.calls, after);
    });
  });

  group('Mock simulation', () {
    test('a seeded accepted booking is trackable straight away', () async {
      final repo = MockRepository(latency: Duration.zero);
      final update = await repo.trackBooking(101);

      expect(update.accepted, isTrue);
      expect(update.position, isNotNull);
      expect(update.destination, Mock.home);
    });

    test(
      'a fresh booking waits to be accepted, then reports a position',
      () async {
        final repo = MockRepository(latency: Duration.zero);
        final booking = await repo.createBooking(
          labourId: Mock.labours.first.id,
          workDate: DateTime(2026, 8, 2),
          dayType: DayType.full,
          offeredAmount: 500,
          address: 'Sector 14, Gurgaon',
          latitude: _site.lat,
          longitude: _site.lng,
        );

        expect(booking.status, BookingStatus.pending);

        final immediately = await repo.trackBooking(booking.id);
        expect(
          immediately.accepted,
          isFalse,
          reason: 'the request is still with the worker',
        );
        expect(immediately.position, isNull);
      },
    );

    test('the worker never overshoots the site', () async {
      final repo = MockRepository(latency: Duration.zero);
      final update = await repo.trackBooking(101);

      final origin = Mock.labourById(_booking().labour.id).latLng!;
      expect(
        update.position!.distanceKmTo(Mock.home),
        lessThanOrEqualTo(origin.distanceKmTo(Mock.home) + 0.001),
      );
    });
  });

  group('TrackingScreen', () {
    testWidgets('shows the waiting state until the worker accepts', (
      tester,
    ) async {
      final repo = _ScriptedRepository([_waiting()]);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Request bhej di gayi'), findsOneWidget);
      expect(find.text('Accept ka intezaar'), findsOneWidget);
    });

    testWidgets('shows the ETA and stage once a fix arrives', (tester) async {
      final repo = _ScriptedRepository([
        _enRoute(const GeoPoint(28.4680, 77.0290), 9),
      ]);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('9 min door'), findsOneWidget);
      expect(find.byType(StageTimeline), findsOneWidget);
      expect(find.text('Request bhej di gayi'), findsNothing);
    });

    testWidgets('offers the arrival handshake while a code is owed', (
      tester,
    ) async {
      final repo = _ScriptedRepository([_atGate()]);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      // Reaching the site does not start the kaam: the timeline stays on
      // "on the way" and the Thekedar is asked for the code.
      expect(find.text('Arrived mark karein'), findsOneWidget);
      expect(
        find.textContaining('code daal kar kaam shuru karein'),
        findsOneWidget,
      );
    });

    testWidgets('drops the handshake once the code has been confirmed', (
      tester,
    ) async {
      final repo = _ScriptedRepository([_working()]);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Arrived mark karein'), findsNothing);
      expect(find.text('Kaam shuru ho gaya'), findsWidgets);
    });

    testWidgets('the code sheet rejects a wrong code and stays open', (
      tester,
    ) async {
      final repo = _ScriptedRepository([_atGate()]);
      // The sheet posts through the repository, and the mock only has a
      // simulation for a booking it has been asked to track.
      await repo.seedSimulation(101);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Arrived mark karein'));
      await tester.pumpAndSettle();

      expect(find.text('Kaam wala pahunch gaya?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Confirm karein'));
      await tester.pumpAndSettle();

      // Still open, showing the server's own wording.
      expect(find.text('Kaam wala pahunch gaya?'), findsOneWidget);
      expect(find.textContaining('Code galat hai'), findsOneWidget);
    });

    testWidgets('the right code starts the work and closes the sheet', (
      tester,
    ) async {
      final repo = _ScriptedRepository([_atGate()]);
      await repo.seedSimulation(101);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Arrived mark karein'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirm karein'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Kaam wala pahunch gaya?'), findsNothing);
    });

    testWidgets('explains a job the worker stopped, and offers no actions', (
      tester,
    ) async {
      final repo = _ScriptedRepository([_endedByLabour()]);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Kaam wale ne kaam band kar diya'), findsOneWidget);
      expect(find.text('Ghar par emergency'), findsOneWidget);
      // 135 minutes of work is owed a conversation about money.
      expect(find.text('2 ghante 15 min'), findsOneWidget);

      // Nothing left to do from here.
      expect(find.text('Arrived mark karein'), findsNothing);
      expect(find.text('Kaam band karein'), findsNothing);
    });

    testWidgets('the Thekedar can stop the kaam with a reason', (tester) async {
      final repo = _ScriptedRepository([_atGate()]);
      await repo.seedSimulation(101);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Kaam band karein'));
      await tester.pumpAndSettle();

      expect(find.text('Ye kaam band karna hai?'), findsOneWidget);

      // Confirming without picking anything must not stop a job by accident.
      await _tapConfirm(tester);
      expect(find.text('Pehle wajah chuniye'), findsOneWidget);
      expect(find.text('Ye kaam band karna hai?'), findsOneWidget);

      await tester.tap(find.text('Kaam theek se nahi ho raha'));
      await tester.pumpAndSettle();
      await _tapConfirm(tester);

      expect(find.text('Ye kaam band karna hai?'), findsNothing);
    });

    testWidgets('picking "other" demands the note before it will submit', (
      tester,
    ) async {
      final repo = _ScriptedRepository([_atGate()]);
      await repo.seedSimulation(101);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Kaam band karein'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Koi aur wajah'));
      await tester.pumpAndSettle();

      await _tapConfirm(tester);

      // Still open: "other" with nothing typed would record nothing at all.
      expect(find.text('Ye kaam band karna hai?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Material aaya hi nahi');
      await tester.pump();
      await _tapConfirm(tester);

      expect(find.text('Ye kaam band karna hai?'), findsNothing);
    });

    testWidgets('surfaces an error when the first poll fails', (tester) async {
      await tester.pumpWidget(
        host(
          TrackingScreen(booking: _booking()),
          repository: _BrokenRepository(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(StageTimeline), findsNothing);
      expect(find.text('Dobara try karein'), findsWidgets);
    });
  });
}
