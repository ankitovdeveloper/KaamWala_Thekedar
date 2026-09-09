import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/animations/celebration.dart';
import 'package:kaamwala_thekedar/core/router/routes.dart';
import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/auth/otp_screen.dart';

/// The OTP screen plus somewhere for it to land: verifying routes to the home
/// tab a second and a half later, and a MaterialApp that cannot answer for
/// `/home` turns that into a route error on the way out of the test.
Widget _host(Widget child) => SessionScope(
  session: Session.mock(),
  child: MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: child,
    ),
    routes: {Routes.home: (_) => const Scaffold(body: Text('home'))},
  ),
);

/// The frame between "OTP accepted" and the home tab.
///
/// It is on screen for a second and a half and nobody can tap anything on it,
/// so the only thing worth pinning down is that it is laid out the way it
/// reads: a tick with the words under it. The column inside it shrink-wraps,
/// and a Stack parks a loose child in the top-start corner — which is how
/// "Login ho gaya!" ended up against the left edge with the tick still centred
/// above it.
void main() {
  testWidgets('the logged-in line sits centred under the tick', (tester) async {
    await tester.pumpWidget(
      _host(
        const OtpScreen(
          // The debug code prefills the boxes, which is what makes the verify
          // button live without typing six digits.
          args: OtpArgs(phone: '9876543210', debugCode: '123456'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Login ho gaya!'), findsNothing);

    await tester.tap(find.text('Verify & Login'));
    // Enough for the mock verify to land and the overlay to be built, and well
    // short of the 1500 ms after which the screen routes away.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final line = find.text('Login ho gaya!');
    expect(line, findsOneWidget);

    final screen = tester.getSize(find.byType(OtpScreen));
    expect(
      tester.getCenter(line).dx,
      moreOrLessEquals(screen.width / 2, epsilon: 1),
      reason: 'the success line must be centred, not pinned to the left edge',
    );

    // ...and under the tick it belongs to, not beside it.
    final burst = tester.getCenter(find.byType(SuccessBurst));
    expect(tester.getCenter(line).dx, moreOrLessEquals(burst.dx, epsilon: 1));
    expect(tester.getCenter(line).dy, greaterThan(burst.dy));

    // Let the screen finish leaving, so the routing timer is not still pending
    // when the tree comes down.
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('home'), findsOneWidget);
  });
}
