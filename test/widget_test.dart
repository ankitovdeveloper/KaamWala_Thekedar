import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/app.dart';
import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/mock_data.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/kaamwala_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/account/account_screen.dart';
import 'package:kaamwala_thekedar/features/bookings/bookings_screen.dart';
import 'package:kaamwala_thekedar/features/bookings/widgets/booking_card.dart';
import 'package:kaamwala_thekedar/features/bookings/widgets/booking_tabs.dart';
import 'package:kaamwala_thekedar/features/search/search_screen.dart';
import 'package:kaamwala_thekedar/features/shell/home_shell.dart';
import 'package:kaamwala_thekedar/widgets/kw_bottom_nav.dart';
import 'package:kaamwala_thekedar/widgets/kw_common.dart';

/// Wraps a screen in just enough app chrome to pump it in isolation, backed by
/// the zero-latency mock repository.
///
/// `disableAnimations` is what makes `pumpAndSettle` usable here: the app runs
/// several looping decorative animations (map pulse, floating icons, the
/// pending-badge breath) that otherwise never let the tree go quiet.
Widget host(
  Widget child, {
  Size size = const Size(390, 844),
  KaamWalaRepository? repository,
}) => SessionScope(
  session: repository == null
      ? Session.mock()
      : Session(repository: repository),
  child: MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: true),
      child: child,
    ),
  ),
);

/// Same trick for tests that boot the real app: `MediaQueryData.fromView`
/// prefers an ancestor's platform flags, so this reaches inside MaterialApp.
Widget hostApp() => MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: KaamWalaApp(session: Session.mock()),
);

void main() {
  group('Login', () {
    testWidgets('renders and rejects a short phone number', (tester) async {
      await tester.pumpWidget(hostApp());
      await tester.pumpAndSettle();

      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('OTP Bhejo'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '98765');
      await tester.tap(find.text('OTP Bhejo'));
      await tester.pump();

      expect(find.text('Poora 10-digit number daalein'), findsOneWidget);
    });

    testWidgets('valid number routes to the OTP screen', (tester) async {
      await tester.pumpWidget(hostApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('OTP Bhejo'));
      await tester.pumpAndSettle();

      expect(find.text('OTP Verify karein'), findsOneWidget);
      expect(find.text('Verify & Login'), findsOneWidget);
    });

    testWidgets('verifying the OTP signs in and lands on Search', (
      tester,
    ) async {
      await tester.pumpWidget(hostApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('OTP Bhejo'));
      await tester.pumpAndSettle();

      // The mock challenge echoes a debug code, so the boxes arrive prefilled.
      await tester.tap(find.text('Verify & Login'));
      await tester.pumpAndSettle();

      expect(find.text('Aapka location'), findsOneWidget);
      expect(find.byType(KwBottomNav), findsOneWidget);
    });
  });

  group('Search', () {
    testWidgets('lists workers returned by the repository', (tester) async {
      await tester.pumpWidget(host(const SearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ramesh Kumar'), findsWidgets);
      expect(
        find.text('${Mock.labours.length} kaam wale milein paas mein'),
        findsOneWidget,
      );
    });

    testWidgets('search query filters the list', (tester) async {
      await tester.pumpWidget(host(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'plumber');
      // Typing is debounced before the request fires.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Suresh Yadav'), findsWidgets);
      expect(find.text('Ramesh Kumar'), findsNothing);
    });
  });

  /// Scrolls "Meri Bookings" down to the finished rows. Four cards do not fit on
  /// a phone, and a ListView never builds what is below the fold — so without
  /// this the completed bookings simply are not in the tree to be found.
  Future<void> scrollBookings(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
  }

  group('Bookings', () {
    testWidgets('tab switch narrows the list to pending only', (tester) async {
      await tester.pumpWidget(host(const BookingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Meri Bookings'), findsOneWidget);

      // "Pending" is both a tab label and a status badge — scope to the tabs.
      await tester.tap(
        find.descendant(
          of: find.byType(BookingTabs),
          matching: find.text('Pending'),
        ),
      );
      await tester.pumpAndSettle();

      // Only Suresh's booking is pending in the mock set.
      expect(find.text('Suresh Yadav'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsNothing);
    });

    testWidgets('a running job offers "kaam poora hua"; finished ones ask for '
        'the money', (tester) async {
      await tester.pumpWidget(host(const BookingsScreen()));
      await tester.pumpAndSettle();

      // Booking 101 is accepted and under way.
      expect(find.text('Kaam poora hua'), findsOneWidget);

      // The finished ones are below the fold on a phone.
      await scrollBookings(tester);
      expect(find.text('Payment done'), findsWidgets);
      expect(find.text('Payment baaki'), findsWidgets);
    });

    testWidgets('marking the kaam done asks first, then waits on the worker',
        (tester) async {
      await tester.pumpWidget(host(const BookingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kaam poora hua'));
      await tester.pumpAndSettle();

      // Behind a confirm: it ends the job for both sides.
      expect(find.text('Kaam poora ho gaya?'), findsOneWidget);
      await tester.tap(find.text('Haan, poora hua'));
      await tester.pumpAndSettle();

      // One side's word so far, and the card says whose answer is missing.
      expect(
        find.textContaining('ke confirm ka intezaar'),
        findsOneWidget,
        reason: 'the worker still has to agree the kaam is finished',
      );
      // Nothing left to mark done on that row.
      expect(find.text('Kaam poora hua'), findsNothing);
    });

    testWidgets('a stray tap cannot mark the payment done', (tester) async {
      await tester.pumpWidget(host(const BookingsScreen()));
      await tester.pumpAndSettle();
      await scrollBookings(tester);

      await tester.tap(find.text('Payment done').first);
      await tester.pumpAndSettle();

      expect(find.text('Paisa de diya?'), findsOneWidget);
      await tester.tap(find.text('Abhi nahi'));
      await tester.pumpAndSettle();

      // Backed out, so the row still offers it and still reads as unpaid.
      expect(find.text('Payment done'), findsWidgets);
      expect(find.text('Payment baaki'), findsWidgets);
    });
  });

  group('Booking card wrap-up state', () {
    Booking finished({String? response, String? remark}) => Booking(
      id: 501,
      labour: Mock.labours.first.ref,
      skillName: 'Painter',
      workDate: DateTime(2026, 8, 26),
      dayType: DayType.full,
      price: 400,
      status: BookingStatus.completed,
      jobStage: JobStage.completed,
      completedBy: 'thekedar',
      paymentStatus: 'completed',
      completionResponse: response,
      completionRemark: remark,
    );

    Widget card(Booking booking) => host(
      Scaffold(
        body: SingleChildScrollView(
          child: BookingCard(
            booking: booking,
            onCall: () {},
            onDetails: () {},
            onCancel: () {},
            onReview: () {},
            onTrack: () {},
            onComplete: () {},
            onPaymentDone: () {},
          ),
        ),
      ),
    );

    testWidgets('says whose answer is still missing', (tester) async {
      await tester.pumpWidget(card(finished()));
      await tester.pumpAndSettle();

      expect(find.textContaining('ke confirm ka intezaar'), findsOneWidget);
    });

    testWidgets('an agreement reads as settled', (tester) async {
      await tester.pumpWidget(card(finished(response: 'agreed')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ne confirm kar diya'), findsOneWidget);
    });

    testWidgets('a refusal is shown with the worker\'s own words',
        (tester) async {
      await tester.pumpWidget(
        card(finished(response: 'disputed', remark: 'Paisa nahi mila')),
      );
      await tester.pumpAndSettle();

      // Nothing else on the row says this: status and payment both still read
      // as finished, because they record what was declared.
      expect(
        find.textContaining('ne aapatti darj ki: Paisa nahi mila'),
        findsOneWidget,
      );
      expect(find.textContaining('ke confirm ka intezaar'), findsNothing);
    });
  });

  group('Account language', () {
    testWidgets('picker offers every supported language', (tester) async {
      await tester.pumpWidget(host(const AccountScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Language / Bhasha'));
      await tester.pumpAndSettle();

      expect(find.text('Bhasha chunein'), findsOneWidget);
      for (final language in AppLanguage.values) {
        // Hindi is the current setting, so it also shows in the row behind
        // the sheet — match widgets rather than exactly one.
        expect(find.text(language.label), findsWidgets);
      }
    });

    testWidgets('picking Bhojpuri updates the row', (tester) async {
      await tester.pumpWidget(host(const AccountScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppLanguage.hindi.label), findsOneWidget);

      await tester.tap(find.text('Language / Bhasha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLanguage.bhojpuri.label));
      await tester.pumpAndSettle();

      expect(find.text(AppLanguage.bhojpuri.label), findsOneWidget);
      expect(find.text(AppLanguage.hindi.label), findsNothing);
    });
  });

  group('Shell', () {
    testWidgets('bottom nav moves between destinations', (tester) async {
      await tester.pumpWidget(host(const HomeShell()));
      await tester.pumpAndSettle();

      expect(find.byType(KwBottomNav), findsOneWidget);
      expect(find.text('Aapka location'), findsOneWidget);

      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();

      expect(find.text('Meri Bookings'), findsOneWidget);
    });

    testWidgets('wide viewport swaps the bottom bar for a rail', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const HomeShell(), size: const Size(1280, 900)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KwNavRail), findsOneWidget);
      expect(find.byType(KwBottomNav), findsNothing);
    });
  });

  group('Profile photo', () {
    testWidgets('a photo URL renders an image over the monogram', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Center(
            child: KwAvatar(
              initials: 'AK',
              photoUrl: 'http://localhost/storage/profile-photos/a.png',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a URL that fails to load falls back to the monogram', (
      tester,
    ) async {
      // The test binding answers every network image with a 400, which is
      // exactly the case this guards: a deleted file must leave initials on
      // screen, not an error box.
      await tester.pumpWidget(
        host(
          const Center(
            child: KwAvatar(
              initials: 'AK',
              photoUrl: 'http://localhost/gone.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AK'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty URL is treated as no photo at all', (tester) async {
      await tester.pumpWidget(
        host(const Center(child: KwAvatar(initials: 'AK', photoUrl: '  '))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('AK'), findsOneWidget);
    });
  });
}
