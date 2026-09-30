import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'core/notifications/notification_service.dart';
import 'core/responsive/responsive.dart';
import 'core/router/routes.dart';
import 'core/theme/app_theme.dart';
import 'data/session.dart';

class KaamWalaApp extends StatefulWidget {
  const KaamWalaApp({super.key, this.session});

  /// Injected by tests and by the mock demo build; production creates its own.
  final Session? session;

  @override
  State<KaamWalaApp> createState() => _KaamWalaAppState();
}

class _KaamWalaAppState extends State<KaamWalaApp> {
  late final Session _session = widget.session ?? Session();

  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    // Always restore, injected session or not — the splash route waits on
    // `isRestored`, and a mock session's restore is a no-op that just flips the
    // flag so tests still reach the login screen.
    _session.restore();

    // Fire-and-forget: Firebase init + the permission prompt must not hold up
    // the first frame, and a build without google-services.json just never
    // becomes ready (see NotificationService's own try/catch). Skipped for an
    // injected (test/mock) session, which has no real backend to register a
    // token with anyway.
    if (widget.session == null) {
      NotificationService.instance
        ..onToken = _session.registerFcmToken
        ..onTap = _handleNotificationTap;
      NotificationService.instance.init();
    }
  }

  /// When the server invalidates the token mid-session, drop straight back to
  /// login rather than leaving a screen full of failed requests.
  void _onSessionChanged() {
    final isAuthed = _session.isAuthenticated;
    if (_wasAuthenticated && !isAuthed) {
      Routes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Routes.login,
        (_) => false,
      );
    }
    _wasAuthenticated = isAuthed;
  }

  /// A tapped notification always carries `type: booking` today (see the
  /// backend's `FcmService::sendBooking`) and a `booking_id` this Thekedar
  /// already owns — there is no "pending request" state on this side the way
  /// there is for the Labour app, so every push opens the same detail screen.
  void _handleNotificationTap(Map<String, String> data) {
    final bookingId = int.tryParse(data['booking_id'] ?? '');
    if (bookingId == null) return;
    Routes.navigatorKey.currentState?.pushNamed(
      Routes.bookingDetail,
      arguments: bookingId,
    );
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: MaterialApp(
        title: 'KaamWala',
        debugShowCheckedModeBanner: false,
        navigatorKey: Routes.navigatorKey,
        theme: AppTheme.light,
        // The splash decides between login and home once the persisted token
        // has been read; booting straight to login would throw that away.
        initialRoute: Routes.splash,
        onGenerateRoute: Routes.onGenerateRoute,
        // One place to clamp OS font scaling and stop touch/mouse drag from
        // behaving differently across platforms.
        builder: (context, child) => ClampedTextScale(
          child: ScrollConfiguration(
            behavior: const _AppScrollBehavior(),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Lets desktop/web users drag-scroll lists with the mouse, and removes the
/// Android glow in favour of the iOS-style stretch used throughout.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
