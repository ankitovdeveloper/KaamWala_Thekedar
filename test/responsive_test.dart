import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/mock_data.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/account/account_screen.dart';
import 'package:kaamwala_thekedar/features/auth/login_screen.dart';
import 'package:kaamwala_thekedar/features/auth/otp_screen.dart';
import 'package:kaamwala_thekedar/features/bookings/bookings_screen.dart';
import 'package:kaamwala_thekedar/features/labour_detail/labour_detail_screen.dart';
import 'package:kaamwala_thekedar/features/profile/profile_screen.dart';
import 'package:kaamwala_thekedar/features/search/search_screen.dart';
import 'package:kaamwala_thekedar/features/shell/home_shell.dart';

/// Viewports the layouts are expected to survive, from a small budget Android
/// through tablets to a desktop browser window.
const _viewports = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'phone 390x844': Size(390, 844),
  'large phone 430x932': Size(430, 932),
  'landscape phone 844x390': Size(844, 390),
  'tablet portrait 768x1024': Size(768, 1024),
  'tablet landscape 1112x834': Size(1112, 834),
  'desktop 1440x900': Size(1440, 900),
  'wide desktop 1920x1080': Size(1920, 1080),
};

Widget _host(Widget child, Size size, {double textScale = 1.0}) {
  // Zero-latency mock repository so `pumpAndSettle` isn't racing a timer.
  final session = Session.mock();
  return SessionScope(
    session: session,
    child: MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

/// Renders [builder] at every viewport. A RenderFlex overflow (or any other
/// layout assertion) surfaces as a test failure, so this is a real check that
/// nothing breaks off-screen rather than a smoke test.
void expectsCleanLayoutEverywhere(
  String label,
  Widget Function() builder, {
  double textScale = 1.0,
}) {
  for (final entry in _viewports.entries) {
    testWidgets('$label renders clean at ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(builder(), entry.value, textScale: textScale),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

void main() {
  group('Login', () {
    expectsCleanLayoutEverywhere('Login', LoginScreen.new);
  });

  group('OTP', () {
    expectsCleanLayoutEverywhere(
      'OTP',
      () => const OtpScreen(args: OtpArgs(phone: '9876543210')),
    );
  });

  group('Search', () {
    expectsCleanLayoutEverywhere('Search', SearchScreen.new);
  });

  group('Labour detail', () {
    expectsCleanLayoutEverywhere(
      'Labour detail',
      () => LabourDetailScreen(labourId: Mock.labours.first.id),
    );
  });

  group('Bookings', () {
    expectsCleanLayoutEverywhere('Bookings', BookingsScreen.new);
  });

  group('Profile', () {
    expectsCleanLayoutEverywhere('Profile', ProfileScreen.new);
  });

  group('Account', () {
    expectsCleanLayoutEverywhere('Account', AccountScreen.new);
  });

  group('Shell', () {
    expectsCleanLayoutEverywhere('Shell', HomeShell.new);
  });

  // The app clamps OS font scaling at 1.3x; verify the dense screens hold up
  // at that ceiling, since that's where rows are most likely to overflow.
  group('Large text (1.3x)', () {
    expectsCleanLayoutEverywhere('Search', SearchScreen.new, textScale: 1.3);
    expectsCleanLayoutEverywhere(
      'Bookings',
      BookingsScreen.new,
      textScale: 1.3,
    );
    expectsCleanLayoutEverywhere('Profile', ProfileScreen.new, textScale: 1.3);
    expectsCleanLayoutEverywhere(
      'OTP',
      () => const OtpScreen(args: OtpArgs(phone: '9876543210')),
      textScale: 1.3,
    );
  });

  group('Shell tab traversal', () {
    for (final entry in _viewports.entries) {
      testWidgets('every tab renders clean at ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(const HomeShell(), entry.value));
        await tester.pumpAndSettle();

        for (final label in ['Bookings', 'Profile', 'Account', 'Search']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$label tab');
        }
      });
    }
  });
}
