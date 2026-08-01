import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Motion constants. Every animation in the app pulls its duration and curve
/// from here so the whole product moves with one personality:
/// quick, slightly springy, never bouncy enough to feel toy-like.
abstract final class Motion {
  static const instant = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 480);
  static const lazy = Duration(milliseconds: 700);

  /// Staggered list entries fire this far apart.
  static const stagger = Duration(milliseconds: 55);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const spring = Cubic(0.34, 1.4, 0.64, 1.0);
  static const settle = Curves.easeOutBack;
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppType.family,
      fontFamilyFallback: AppType.fallback,
      colorScheme: const ColorScheme.light(
        primary: AppColors.yellow,
        onPrimary: AppColors.black,
        secondary: AppColors.black,
        onSecondary: AppColors.yellow,
        surface: AppColors.white,
        onSurface: AppColors.black,
        surfaceContainerLowest: AppColors.canvas,
        surfaceContainerHighest: AppColors.surfaceAlt,
        error: AppColors.danger,
        outlineVariant: AppColors.border,
      ),
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionBuilder(),
        },
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.black,
        displayColor: AppColors.black,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0.5,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rMd,
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: AppType.body.copyWith(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.black,
        selectionColor: AppColors.yellowLight,
        selectionHandleColor: AppColors.yellowDark,
      ),
      // Yellow status bar with dark icons — matches the mockup's `.status-bar`.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.yellow,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
    );
  }
}

/// A fade-through: the outgoing page fades out and scales down a hair while the
/// incoming one fades up. Reads as "sibling replacement" rather than a stack
/// push, which suits the tab-flavoured navigation in this app.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 1.0, curve: Motion.enter),
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0.0, 0.4, curve: Motion.exit),
    );

    return FadeTransition(
      opacity: incoming,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(incoming),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.0).animate(outgoing),
          child: child,
        ),
      ),
    );
  }
}
