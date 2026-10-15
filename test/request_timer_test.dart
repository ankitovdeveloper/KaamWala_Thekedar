import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/i18n/app_strings.dart';
import 'package:kaamwala_thekedar/data/mock_data.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/features/bookings/widgets/booking_card.dart';
import 'package:kaamwala_thekedar/features/tracking/tracking_screen.dart';
import 'package:kaamwala_thekedar/widgets/request_countdown.dart';

import 'widget_test.dart' show host;

/// A request nobody answers in twenty seconds cancels itself — and the Thekedar
/// watches it happen: a countdown while it is out, then a plain "nobody
/// answered" with a way to try again.
///
/// The seconds come from the server's "N seconds left", not from a timestamp, so
/// every deadline here is built from the local clock plus a short wait.

final _s = AppStrings.hinglish;

Booking _pending({DateTime? expiresAt, int? crewId}) => Booking(
  id: 5,
  labour: const LabourRef(id: 11, name: 'Ramesh Kumar'),
  status: BookingStatus.pending,
  jobStage: JobStage.pending,
  price: 450,
  site: Mock.home,
  requestExpiresAt: expiresAt,
  crewId: crewId,
  crewSize: crewId == null ? null : 3,
);

/// The server's side of the tracking poll: pending until the deadline, then
/// cancelled-as-expired.
class _Unanswered extends MockRepository {
  _Unanswered(this.deadline) : super(latency: Duration.zero);

  final DateTime deadline;
  int polls = 0;

  @override
  Future<TrackingUpdate> trackBooking(int bookingId) async {
    polls++;
    if (DateTime.now().isBefore(deadline)) {
      return TrackingUpdate(
        stage: JobStage.pending,
        accepted: false,
        isLive: false,
        requestExpiresAt: deadline,
      );
    }
    return const TrackingUpdate(
      stage: JobStage.pending,
      accepted: false,
      isLive: false,
      expired: true,
    );
  }
}

/// A backend that predates the answer window: pending, with no deadline.
class _NoWindow extends MockRepository {
  _NoWindow() : super(latency: Duration.zero);

  @override
  Future<TrackingUpdate> trackBooking(int bookingId) async =>
      const TrackingUpdate(
        stage: JobStage.pending,
        accepted: false,
        isLive: false,
      );
}

void main() {
  group('wire models', () {
    test('a pending booking turns "N seconds left" into a deadline', () {
      final before = DateTime.now();
      final booking = Booking.fromJson({
        'id': 1,
        'labour_id': 2,
        'status': 'pending',
        'offered_amount': 500,
        'request_seconds_left': 14,
        'request_ttl_seconds': 20,
      });

      expect(booking.requestTtlSeconds, 20);
      final left = booking.requestExpiresAt!.difference(before);
      expect(left.inSeconds, inInclusiveRange(13, 14));
      expect(booking.isAwaitingAnswer, isTrue);
    });

    test(
      'an answered booking has no deadline and is not awaiting anything',
      () {
        final booking = Booking.fromJson({
          'id': 1,
          'labour_id': 2,
          'status': 'accepted',
          'offered_amount': 500,
          'request_seconds_left': null,
          'request_ttl_seconds': null,
        });

        expect(booking.requestExpiresAt, isNull);
        expect(booking.requestTtlSeconds, Booking.defaultRequestTtlSeconds);
        expect(booking.isAwaitingAnswer, isFalse);
      },
    );

    test('a request that withdrew itself is recognised by its reason', () {
      final expired = Booking.fromJson({
        'id': 1,
        'labour_id': 2,
        'status': 'cancelled',
        'offered_amount': 500,
        'cancellation_reason_code': 'expired',
      });
      final cancelled = Booking.fromJson({
        'id': 2,
        'labour_id': 2,
        'status': 'cancelled',
        'offered_amount': 500,
        'cancelled_by': 'thekedar',
      });

      expect(expired.wasExpired, isTrue);
      expect(expired.isAwaitingAnswer, isFalse);
      expect(cancelled.wasExpired, isFalse);
    });

    test('the tracking poll carries the countdown, and then the expiry', () {
      final waiting = TrackingUpdate.fromJson({
        'status': 'pending',
        'job_stage': 'pending',
        'request_seconds_left': 9,
        'request_ttl_seconds': 20,
      });
      expect(waiting.accepted, isFalse);
      expect(waiting.expired, isFalse);
      expect(waiting.requestExpiresAt, isNotNull);

      final gone = TrackingUpdate.fromJson({
        'status': 'cancelled',
        'job_stage': 'pending',
        'expired': true,
      });
      expect(gone.expired, isTrue);
      expect(gone.requestExpiresAt, isNull);
      expect(gone.etaLabelIn(_s), _s.requestExpiredTitle);
    });

    test('the outcome kind knows about an expired request', () {
      expect(BookingOutcomeKind.parse('expired'), BookingOutcomeKind.expired);
      expect(BookingOutcomeKind.expired.isBad, isTrue);
    });

    test('the countdown reads in minutes and seconds, rounded up', () {
      expect(countdownLabel(const Duration(seconds: 20)), '0:20');
      expect(countdownLabel(const Duration(milliseconds: 14100)), '0:15');
      expect(countdownLabel(Duration.zero), '0:00');
      expect(countdownLabel(const Duration(seconds: 75)), '1:15');
      expect(isRunningOut(const Duration(seconds: 5)), isTrue);
      expect(isRunningOut(const Duration(seconds: 6)), isFalse);
    });
  });

  group('RequestCountdown', () {
    testWidgets('fires onExpired once, when the time runs out', (tester) async {
      var fired = 0;
      final deadline = DateTime.now().add(const Duration(milliseconds: 600));

      await tester.pumpWidget(
        MaterialApp(
          home: RequestCountdown(
            expiresAt: deadline,
            onExpired: () => fired++,
            builder: (_, left) => Text(countdownLabel(left)),
          ),
        ),
      );
      expect(fired, 0);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 900)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(fired, 1);
      expect(find.text('0:00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a deadline already behind fires straight away', (
      tester,
    ) async {
      var fired = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: RequestCountdown(
            expiresAt: DateTime.now().subtract(const Duration(seconds: 3)),
            onExpired: () => fired++,
            builder: (_, left) => Text(countdownLabel(left)),
          ),
        ),
      );
      await tester.pump();

      expect(fired, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Booking card', () {
    Widget card(Booking booking) => host(
      Scaffold(
        body: SingleChildScrollView(
          child: BookingCard(
            booking: booking,
            onCall: () {},
            onDetails: () {},
            onBookAgain: () {},
            onCancel: () {},
            onReview: () {},
            onTrack: () {},
            onComplete: () {},
            onPaymentDone: () {},
          ),
        ),
      ),
    );

    testWidgets('a pending request shows how long the worker has left', (
      tester,
    ) async {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      await tester.pumpWidget(card(_pending(expiresAt: deadline)));
      await tester.pump();

      expect(find.textContaining('me jawab na aaya to cancel'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a request with no deadline, or one in a crew, shows none', (
      tester,
    ) async {
      await tester.pumpWidget(card(_pending()));
      await tester.pump();
      expect(find.textContaining('me jawab na aaya to cancel'), findsNothing);

      // A crew member's request is passed on, not cancelled.
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      await tester.pumpWidget(card(_pending(expiresAt: deadline, crewId: 9)));
      await tester.pump();
      expect(find.textContaining('me jawab na aaya to cancel'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Tracking', () {
    testWidgets('waiting counts down, then says nobody answered', (
      tester,
    ) async {
      final deadline = DateTime.now().add(const Duration(milliseconds: 1200));
      final repo = _Unanswered(deadline);

      await tester.pumpWidget(
        host(
          TrackingScreen(booking: _pending(expiresAt: deadline)),
          repository: repo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Still waiting: the ring is up and says how long this will take.
      expect(find.byType(RequestCountdownRing), findsOneWidget);
      expect(find.text(_s.requestAnswerHint(20)), findsOneWidget);
      expect(find.text(_s.requestExpiredTitle), findsNothing);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)),
      );
      // The ring reaches zero, asks the server once more, and the answer is
      // that the request is gone.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.byType(RequestCountdownRing), findsNothing);
      expect(find.text(_s.requestExpiredTitle), findsWidgets);
      expect(
        find.text(_s.requestExpiredBody('Ramesh Kumar', 20)),
        findsOneWidget,
      );
      expect(find.text(_s.resendRequest), findsOneWidget);
      expect(find.text(_s.findAnotherWorker), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a backend with no answer window keeps the plain spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(TrackingScreen(booking: _pending()), repository: _NoWindow()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RequestCountdownRing), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text(_s.requestAnswerHint(20)), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Mock repository', () {
    test('a request nobody answers cancels itself', () async {
      final repo = MockRepository(latency: Duration.zero, workerAnswers: false);
      final booking = await repo.createBooking(
        labourId: Mock.labours.first.id,
        workDate: DateTime.now(),
        dayType: DayType.full,
        offeredAmount: 450,
        address: 'Site',
      );

      expect(booking.isAwaitingAnswer, isTrue);
      final update = await repo.trackBooking(booking.id);
      expect(update.expired, isFalse);
      expect(update.requestExpiresAt, isNotNull);
    });
  });
}
