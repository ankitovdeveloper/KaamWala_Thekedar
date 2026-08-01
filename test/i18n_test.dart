import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/i18n/app_strings.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/account/account_screen.dart';
import 'package:kaamwala_thekedar/features/shell/home_shell.dart';
import 'package:kaamwala_thekedar/widgets/kw_bottom_nav.dart';

/// Same host as `widget_test.dart`, but keeps a handle on the session so a
/// test can change the language the way Account Settings does.
({Widget widget, Session session}) hostWithSession(Widget child) {
  final session = Session(repository: MockRepository(latency: Duration.zero));
  return (
    widget: SessionScope(
      session: session,
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        ),
      ),
    ),
    session: session,
  );
}

void main() {
  group('String tables', () {
    test('every wire code resolves to its own table', () {
      expect(AppStrings.forCode('hi'), same(AppStrings.hindi));
      expect(AppStrings.forCode('en'), same(AppStrings.english));
      expect(AppStrings.forCode('bho'), same(AppStrings.bhojpuri));
      expect(AppStrings.forCode('hi-en'), same(AppStrings.hinglish));
    });

    test('an unknown or missing code falls back to Hinglish', () {
      expect(AppStrings.forCode(null), same(AppStrings.hinglish));
      expect(AppStrings.forCode('fr'), same(AppStrings.hinglish));
    });

    test('Bhojpuri inherits Hindi for anything it does not translate', () {
      // `siteMarker` is only overridden on Hindi, so Bhojpuri must not fall
      // all the way through to the Latin-script base.
      expect(AppStrings.bhojpuri.siteMarker, isNot(AppStrings.hinglish.siteMarker));
    });

    test('model labels follow the table they are given', () {
      expect(JobStage.onTheWay.labelIn(AppStrings.hinglish), 'Raaste mein');
      expect(JobStage.onTheWay.labelIn(AppStrings.english), 'On the way');
      expect(DayType.half.labelIn(AppStrings.english), 'Half day booking');
      expect(LabourSort.rating.labelIn(AppStrings.english), 'Top rated');
    });

    test('a booking date is spelled in the chosen language', () {
      const booking = Booking(
        id: 1,
        labour: LabourRef(id: 2, name: 'Ramesh Kumar'),
        status: BookingStatus.completed,
        jobStage: JobStage.completed,
        price: 450,
        workDate: null,
      );
      expect(booking.whenLabelIn(AppStrings.hindi), '');

      final dated = Booking.fromJson(const {
        'id': 1,
        'labour': {'id': 2, 'name': 'Ramesh Kumar'},
        'status': 'completed',
        'work_date': '2026-06-19',
        'offered_amount': 450,
      });
      expect(dated.whenLabelIn(AppStrings.english), '19 June 2026');
      expect(dated.whenLabelIn(AppStrings.hindi), '19 जून 2026');
    });
  });

  group('Session language', () {
    test('defaults to Hinglish and follows the signed-in user', () {
      final session = Session(
        repository: MockRepository(latency: Duration.zero),
      );
      addTearDown(session.dispose);

      expect(session.language, 'hi-en');
      expect(session.strings, same(AppStrings.hinglish));

      session.updateUser(
        const AppUser(id: 1, name: 'Amit', phone: '9876543210', language: 'en'),
      );
      expect(session.strings, same(AppStrings.english));
    });
  });

  group('Language switch', () {
    testWidgets('changing it re-labels the whole shell', (tester) async {
      final host = hostWithSession(const HomeShell());
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();

      // Signed out, so the app opens in the Hinglish default.
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Aapka location'), findsOneWidget);

      await host.session.setLanguage('en');
      await tester.pumpAndSettle();

      expect(find.text('Your location'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);

      await host.session.setLanguage('hi');
      await tester.pumpAndSettle();

      expect(find.text('आपका लोकेशन'), findsOneWidget);
      expect(find.text('खोजें'), findsOneWidget);
      expect(find.text('Aapka location'), findsNothing);
    });

    testWidgets('picking a language in Account Settings applies it', (
      tester,
    ) async {
      final host = hostWithSession(const AccountScreen());
      addTearDown(host.session.dispose);

      await tester.pumpWidget(host.widget);
      await tester.pumpAndSettle();

      expect(find.text('Account Settings'), findsOneWidget);

      await tester.tap(find.text('Language / Bhasha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLanguage.english.label));
      await tester.pumpAndSettle();

      expect(host.session.language, 'en');
      expect(find.text('Account settings'), findsOneWidget);
      expect(find.text('Account Settings'), findsNothing);
      // The row that was just tapped is itself re-labelled.
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Language / Bhasha'), findsNothing);
    });
  });

  group('Bottom nav insets', () {
    testWidgets('clears the system navigation bar completely', (tester) async {
      const inset = 48.0;
      final session = Session(
        repository: MockRepository(latency: Duration.zero),
      );
      addTearDown(session.dispose);

      await tester.pumpWidget(
        SessionScope(
          session: session,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                viewPadding: EdgeInsets.only(bottom: inset),
                padding: EdgeInsets.only(bottom: inset),
                disableAnimations: true,
              ),
              child: const HomeShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The lowest label must sit above the gesture bar, not under it.
      final bar = tester.getRect(find.byType(KwBottomNav));
      final label = tester.getRect(
        find.descendant(
          of: find.byType(KwBottomNav),
          matching: find.text('Search'),
        ),
      );
      expect(
        label.bottom,
        lessThanOrEqualTo(bar.bottom - inset),
        reason: 'labels must clear the full system navigation inset',
      );
    });
  });
}
