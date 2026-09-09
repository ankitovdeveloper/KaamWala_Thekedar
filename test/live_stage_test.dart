import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/data/api/api_config.dart';
import 'package:kaamwala_thekedar/data/mock_data.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/features/booking_detail/booking_detail_screen.dart';
import 'package:kaamwala_thekedar/features/bookings/bookings_screen.dart';

import 'widget_test.dart' show host;

/// The worker setting off, arriving on a screen that is already open.
///
/// Nothing about a job stage is this Thekedar's to move: the labour's phone
/// does it, and the app finds out by asking. Reloading when the app comes back
/// from the background covered walking away and returning — it did nothing at
/// all for somebody sitting on "Meri Bookings" waiting to see "Raaste mein",
/// which is what people actually do after a request is accepted.

Booking _accepted(JobStage stage) => Mock.bookings()
    .firstWhere((b) => b.id == 101)
    .copyWith(status: BookingStatus.accepted, jobStage: stage);

/// Serves one list per fetch, so a stage moving between two polls can be played
/// out without waiting on anybody.
class _ScriptedBookings extends MockRepository {
  _ScriptedBookings(this.script) : super(latency: Duration.zero);

  final List<List<Booking>> script;
  int calls = 0;

  @override
  Future<List<Booking>> bookings({String tab = 'all'}) async {
    final rows = script[calls.clamp(0, script.length - 1)];
    calls++;
    return rows;
  }
}

/// The same, for the one-booking screen.
class _ScriptedDetail extends MockRepository {
  _ScriptedDetail(this.script) : super(latency: Duration.zero);

  final List<Booking> script;
  int calls = 0;

  @override
  Future<BookingDetail> bookingDetail(int bookingId) async {
    final booking = script[calls.clamp(0, script.length - 1)];
    calls++;
    return BookingDetail(
      booking: booking,
      labour: Mock.labourById(booking.labour.id),
      timeline: const [],
      locations: const BookingLocations(),
      payment: const BookingPayment(amount: 450, status: 'pending'),
      outcome: const BookingOutcome(),
      can: const BookingActions(),
    );
  }
}

/// One poll of the stage timer, plus the frames it schedules.
Future<void> _tick(WidgetTester tester) async {
  await tester.pump(ApiConfig.stagePollInterval);
  await tester.pump();
  await tester.pump();
}

void main() {
  final name = Mock.bookings().firstWhere((b) => b.id == 101).labour.name;

  group('Meri Bookings', () {
    testWidgets('picks up "Raaste mein" without anybody touching the app', (
      tester,
    ) async {
      final repo = _ScriptedBookings([
        [_accepted(JobStage.pending)],
        [_accepted(JobStage.onTheWay)],
      ]);

      await tester.pumpWidget(
        host(const BookingsScreen(), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      // The first load is the baseline: the worker has said yes and no more.
      expect(repo.calls, 1);
      expect(find.text('$name site ke liye nikal gaya'), findsNothing);

      await _tick(tester);

      expect(repo.calls, greaterThan(1));
      expect(find.text('$name site ke liye nikal gaya'), findsOneWidget);
    });

    testWidgets('leaves a settled list alone — nothing there can move', (
      tester,
    ) async {
      final repo = _ScriptedBookings([
        [_accepted(JobStage.pending).copyWith(status: BookingStatus.completed)],
      ]);

      await tester.pumpWidget(
        host(const BookingsScreen(), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      expect(repo.calls, 1);

      await _tick(tester);
      await _tick(tester);

      expect(
        repo.calls,
        1,
        reason: 'a finished booking is history; polling it says nothing',
      );
    });
  });

  group('Booking detail', () {
    testWidgets('moves to "Raaste mein" while the screen stays open', (
      tester,
    ) async {
      final repo = _ScriptedDetail([
        _accepted(JobStage.pending),
        _accepted(JobStage.onTheWay),
      ]);

      await tester.pumpWidget(
        host(const BookingDetailScreen(bookingId: 101), repository: repo),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('$name site ke liye nikal gaya'), findsNothing);

      await _tick(tester);

      expect(find.text('$name site ke liye nikal gaya'), findsOneWidget);
    });
  });
}
