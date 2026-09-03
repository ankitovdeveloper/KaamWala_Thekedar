import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/features/booking_detail/booking_detail_screen.dart';
import 'package:kaamwala_thekedar/features/booking_detail/widgets/booking_timeline.dart';

import 'widget_test.dart' show host;

/// The booking-detail screen and its timeline.
///
/// The screen's whole reason for existing is that it must not lie about what
/// happened on a booking, so that is what these check: a step still ahead reads
/// as ahead, a step nobody reached on a stopped job is not shown at all, and a
/// worker's "no" is visible even though every other field still says the job is
/// finished and paid.
void main() {
  BookingStep step(
    BookingStepCode code,
    BookingStepState state, {
    DateTime? at,
    String? note,
    String title = 'server text',
  }) => BookingStep(
    code: code,
    state: state,
    title: title,
    note: note,
    at: at,
    actor: 'labour',
  );

  Widget timeline(List<BookingStep> steps) =>
      host(Scaffold(body: SingleChildScrollView(child: BookingTimeline(steps: steps))));

  group('Booking timeline', () {
    testWidgets('reads each step in the session language, not the server text', (
      tester,
    ) async {
      await tester.pumpWidget(
        timeline([
          step(
            BookingStepCode.requested,
            BookingStepState.done,
            at: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          step(BookingStepCode.accepted, BookingStepState.current),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Booking bheji'), findsOneWidget);
      expect(find.text('Kaam wale ke jawab ka intezaar'), findsOneWidget);
      // The API speaks only Hinglish; a known code never renders its title.
      expect(find.text('server text'), findsNothing);
    });

    testWidgets('the same step reads differently depending on where it stands', (
      tester,
    ) async {
      await tester.pumpWidget(
        timeline([step(BookingStepCode.payment, BookingStepState.pending)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payment baaki hai'), findsOneWidget);

      await tester.pumpWidget(
        timeline([
          step(
            BookingStepCode.payment,
            BookingStepState.done,
            at: DateTime.now(),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payment ho gaya'), findsOneWidget);
    });

    testWidgets('a step the server does not explain falls back to its title', (
      tester,
    ) async {
      await tester.pumpWidget(
        timeline([
          step(
            BookingStepCode.unknown,
            BookingStepState.done,
            at: DateTime.now(),
            title: 'Kuch naya hua',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // A newer backend can add a step without this build dropping it.
      expect(find.text('Kuch naya hua'), findsOneWidget);
    });

    testWidgets('a failed step shows the note the server attached', (
      tester,
    ) async {
      await tester.pumpWidget(
        timeline([
          step(
            BookingStepCode.labourConfirm,
            BookingStepState.failed,
            at: DateTime.now(),
            note: 'Poora paisa nahi mila',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kaam wale ne aapatti darj ki'), findsOneWidget);
      // Free text no string table could hold, so it comes through as it is.
      expect(find.text('Poora paisa nahi mila'), findsOneWidget);
    });

    testWidgets('says how long ago a step happened', (tester) async {
      await tester.pumpWidget(
        timeline([
          step(
            BookingStepCode.arrived,
            BookingStepState.done,
            at: DateTime.now().subtract(const Duration(minutes: 25)),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('25 min pehle'), findsOneWidget);
    });

    testWidgets('an empty history says so rather than rendering nothing', (
      tester,
    ) async {
      await tester.pumpWidget(timeline(const []));
      await tester.pumpAndSettle();

      expect(find.textContaining('abhi kuch hua nahi'), findsOneWidget);
    });
  });

  group('Booking detail screen', () {
    /// The mock's booking 101 — accepted, worker on the way.
    Future<void> open(WidgetTester tester, int bookingId) async {
      await tester.pumpWidget(host(BookingDetailScreen(bookingId: bookingId)));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the booking, not the worker profile', (tester) async {
      await open(tester, 101);

      expect(find.text('Booking ki puri jankari'), findsOneWidget);
      expect(find.text('Booking #101'), findsOneWidget);
      // Every section a booking's record needs.
      expect(find.text('KYA KYA HUA'), findsOneWidget);
      expect(find.text('KAAM WALE KI JANKARI'), findsOneWidget);
    });

    testWidgets('a live job leads with the step it is waiting on', (
      tester,
    ) async {
      await open(tester, 101);

      // Worker is on the way, so the arrival is what is owed next.
      expect(find.text('Kaam wala site ke liye nikla'), findsOneWidget);
      expect(find.text('Pahunchne ka intezaar'), findsOneWidget);
      // ...and following them is the primary action.
      expect(find.text('Live track'), findsOneWidget);
    });

    testWidgets('an unanswered request waits at the accept step', (
      tester,
    ) async {
      await open(tester, 102);

      expect(find.text('Kaam wale ke jawab ka intezaar'), findsOneWidget);
      // Nothing to follow yet, so no tracking button.
      expect(find.text('Live track'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('a finished job puts the money first', (tester) async {
      await open(tester, 103);

      expect(find.text('Kaam poora hua'), findsOneWidget);
      expect(find.text('Payment baaki hai'), findsOneWidget);
      expect(find.text('Payment done'), findsOneWidget);
    });

    testWidgets('carries the full worker record, not just a name', (
      tester,
    ) async {
      await open(tester, 101);

      expect(find.text('Saal ka anubhav'), findsOneWidget);
      expect(find.text('Kaam kiye'), findsOneWidget);
      expect(find.text('Poori profile dekhein'), findsOneWidget);
    });

    testWidgets('shows where the worker accepted from and where they are', (
      tester,
    ) async {
      await open(tester, 101);

      expect(find.text('Kaam ki jagah'), findsOneWidget);
      expect(find.text('Accept karte waqt yahan the'), findsOneWidget);
    });

    testWidgets('a booking that does not exist shows an error, not a blank', (
      tester,
    ) async {
      await open(tester, 999);

      expect(find.text('Kuch galat ho gaya'), findsOneWidget);
      expect(find.text('Ye booking nahi mili.'), findsOneWidget);
      expect(find.text('Dobara try karein'), findsOneWidget);
    });
  });
}
