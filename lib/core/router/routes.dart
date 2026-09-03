import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/booking_detail/booking_detail_screen.dart';
import '../../features/labour_detail/labour_detail_screen.dart';
import '../../features/search/labours_map_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/tracking/tracking_screen.dart';
import '../theme/app_theme.dart';

abstract final class Routes {
  /// The boot route: it reads the restored session and replaces itself with
  /// [home] or [login]. Nothing else should navigate here.
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';
  static const home = '/home';
  static const laboursMap = '/labours-map';
  static const labourDetail = '/labour';

  /// One booking's whole record. Takes a [Booking] (the row the list already
  /// has, used as a preview while the full record loads) or a bare booking id.
  static const bookingDetail = '/booking';

  static const tracking = '/track';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) =>
      switch (settings.name) {
        splash => _fade(const SplashScreen(), settings),
        login => _fade(const LoginScreen(), settings),
        otp => _slideUp(
          OtpScreen(args: settings.arguments as OtpArgs),
          settings,
        ),
        home => _fade(const HomeShell(), settings),
        laboursMap => _fade(const LaboursMapScreen(), settings),
        labourDetail => _detail(switch (settings.arguments) {
          // The list already has enough for the hero flight, so pass it
          // through as a preview while the full record loads.
          final Labour preview => LabourDetailScreen(
            labourId: preview.id,
            preview: preview,
          ),
          final int id => LabourDetailScreen(labourId: id),
          _ => const SizedBox.shrink(),
        }, settings),
        bookingDetail => _detail(switch (settings.arguments) {
          // The list row carries the worker's name and the status, which is
          // enough to paint the header while the full record loads.
          final Booking preview => BookingDetailScreen(
            bookingId: preview.id,
            preview: preview,
          ),
          final int id => BookingDetailScreen(bookingId: id),
          _ => const SizedBox.shrink(),
        }, settings),
        tracking => _slideUp(
          TrackingScreen(booking: settings.arguments! as Booking),
          settings,
        ),
        _ => null,
      };

  /// Auth steps replace each other — a cross-fade reads as "same flow".
  static Route<T> _fade<T>(Widget child, RouteSettings settings) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.normal,
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (context, animation, _, page) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Motion.enter),
          child: page,
        ),
      );

  /// OTP arrives from below, like a step forward in a wizard.
  static Route<T> _slideUp<T>(Widget child, RouteSettings settings) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.normal,
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (context, animation, _, page) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Motion.emphasized,
            reverseCurve: Motion.exit,
          );
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: page),
          );
        },
      );

  /// Detail push: the Hero handles the avatar, so the page itself only needs a
  /// gentle scale-and-fade that doesn't fight the flying element.
  static Route<T> _detail<T>(Widget child, RouteSettings settings) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.normal,
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (context, animation, _, page) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Motion.emphasized,
            reverseCurve: Motion.exit,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(curved),
              child: page,
            ),
          );
        },
      );
}
