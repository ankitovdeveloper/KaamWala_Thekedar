import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/mock_data.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/booking_detail/booking_detail_screen.dart';
import 'package:kaamwala_thekedar/features/tracking/tracking_screen.dart';
import 'package:kaamwala_thekedar/widgets/kw_celebration.dart';

import 'widget_test.dart' show host;

const _site = GeoPoint(28.4595, 77.0266);

Booking _booking() => Mock.bookings().firstWhere((b) => b.id == 101);

/// Serves one scripted sample per poll, so a request being accepted can be
/// played out without waiting on anybody.
class _ScriptedTracker extends MockRepository {
  _ScriptedTracker(this.script) : super(latency: Duration.zero);

  final List<TrackingUpdate> script;
  int calls = 0;

  @override
  Future<TrackingUpdate> trackBooking(int bookingId) async {
    final update = script[calls.clamp(0, script.length - 1)];
    calls++;
    return update;
  }
}

/// Serves one scripted detail per fetch — the worker's answer landing between
/// two loads is exactly the case the screen has to notice.
class _ScriptedDetail extends MockRepository {
  _ScriptedDetail(this.script) : super(latency: Duration.zero);

  final List<BookingDetail> script;
  int calls = 0;

  @override
  Future<BookingDetail> bookingDetail(int bookingId) async {
    final detail = script[calls.clamp(0, script.length - 1)];
    calls++;
    return detail;
  }
}

/// A finished, paid booking — with or without the worker having said the money
/// reached them.
BookingDetail _paidDetail({DateTime? confirmedAt}) {
  final booking = _booking().copyWith(
    status: BookingStatus.completed,
    completedBy: 'thekedar',
  );

  return BookingDetail(
    booking: booking,
    labour: Mock.labourById(booking.labour.id),
    timeline: const [],
    locations: const BookingLocations(),
    payment: BookingPayment(
      amount: 1200,
      status: 'completed',
      done: true,
      markedAt: DateTime(2026, 8, 26, 18, 30),
      confirmedAt: confirmedAt,
      awaitingLabourConfirm: confirmedAt == null,
    ),
    outcome: const BookingOutcome(),
    can: const BookingActions(),
  );
}

TrackingUpdate _waiting() =>
    const TrackingUpdate(stage: JobStage.pending, accepted: false);

TrackingUpdate _enRoute() => const TrackingUpdate(
  stage: JobStage.onTheWay,
  position: GeoPoint(28.4680, 77.0290),
  destination: _site,
  etaMinutes: 9,
  distanceKm: 1.2,
);

/// Runs the tracking screen forward by one poll and lets the popup settle.
Future<void> _poll(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

/// The success popup, and the two moments nobody taps for.
///
/// The popup itself is decoration over a result that already happened, so what
/// is worth testing is not that it looks nice: it is that it fires on the
/// *change* and only on the change. A celebration that greets you every time
/// you open an old booking is one people learn to dismiss without reading.
void main() {
  group('Success celebration', () {
    testWidgets('says what happened and closes on the button', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => KwCelebration.show(
                    context,
                    title: 'Payment ho gaya!',
                    message: 'Paisa dena record ho gaya.',
                    detail: '₹1200',
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Payment ho gaya!'), findsOneWidget);
      expect(find.text('Paisa dena record ho gaya.'), findsOneWidget);
      expect(find.text('₹1200'), findsOneWidget);

      await tester.tap(find.text('Theek hai'));
      await tester.pumpAndSettle();

      expect(find.text('Payment ho gaya!'), findsNothing);
    });

    // The tick, the rays and the paper are all driven by tickers. A repeating
    // one would look identical on screen and hang every `pumpAndSettle` in the
    // suite, so it is worth pinning down that they all end.
    testWidgets('settles — nothing in it loops for ever', (tester) async {
      await tester.pumpWidget(
        SessionScope(
          session: Session.mock(),
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        KwCelebration.show(context, title: 'Kaam poora!'),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Kaam poora!'), findsOneWidget);
    });
  });

  group('The worker accepting', () {
    testWidgets('is announced when it lands while the screen is open', (
      tester,
    ) async {
      final repo = _ScriptedTracker([_waiting(), _enRoute()]);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Accept ka intezaar'), findsOneWidget);
      expect(find.textContaining('haan kar di'), findsNothing);

      await _poll(tester);

      expect(
        find.text('${_booking().labour.name} ne haan kar di!'),
        findsOneWidget,
      );
    });

    testWidgets('is not re-announced on a booking accepted long ago', (
      tester,
    ) async {
      final repo = _ScriptedTracker([_enRoute()]);

      await tester.pumpWidget(
        host(TrackingScreen(booking: _booking()), repository: repo),
      );
      await tester.pump();
      await tester.pump();
      await _poll(tester);

      expect(find.textContaining('haan kar di'), findsNothing);
      expect(find.text('9 min door'), findsOneWidget);
    });
  });

  group('The worker confirming the payment', () {
    testWidgets('is announced when it lands between two loads', (tester) async {
      final repo = _ScriptedDetail([
        _paidDetail(),
        _paidDetail(confirmedAt: DateTime(2026, 8, 26, 19, 10)),
      ]);

      await tester.pumpWidget(
        host(const BookingDetailScreen(bookingId: 101), repository: repo),
      );
      await tester.pumpAndSettle();

      // The first load is the baseline, not news.
      expect(find.textContaining('payment confirm kar di'), findsNothing);

      // Coming back to the app is what asks the server again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      final name = Mock.labourById(_booking().labour.id).name;
      expect(find.text('$name ne payment confirm kar di!'), findsOneWidget);
      expect(find.text('₹1200'), findsWidgets);
    });

    testWidgets('is left alone on a booking that was settled already', (
      tester,
    ) async {
      final repo = _ScriptedDetail([
        _paidDetail(confirmedAt: DateTime(2026, 8, 26, 19, 10)),
      ]);

      await tester.pumpWidget(
        host(const BookingDetailScreen(bookingId: 101), repository: repo),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.textContaining('payment confirm kar di'), findsNothing);
    });
  });
}
