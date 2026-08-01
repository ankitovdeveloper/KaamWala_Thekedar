import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Page chrome shared by every screen.
///
/// The mockups draw a yellow status bar above a yellow header. Here the real
/// system status bar sits in that same yellow band, so [headerColor] paints
/// behind the notch and the body starts below it.
class KwScaffold extends StatelessWidget {
  const KwScaffold({
    super.key,
    required this.body,
    this.headerColor = AppColors.yellow,
    this.backgroundColor = AppColors.canvas,
    this.bottomBar,
    this.floatingBar,
    this.extendBodyBehindHeader = false,
    this.darkStatusIcons = true,
  });

  final Widget body;

  /// Colour painted behind the system status bar.
  final Color headerColor;
  final Color backgroundColor;

  /// Persistent bar pinned to the bottom (the nav bar in the shell).
  final Widget? bottomBar;

  /// Bar that floats above [bottomBar] — e.g. the sticky "Book Now" CTA.
  final Widget? floatingBar;
  final bool extendBodyBehindHeader;
  final bool darkStatusIcons;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: darkStatusIcons
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: darkStatusIcons
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: bottomBar != null
            ? AppColors.black
            : backgroundColor,
        systemNavigationBarIconBrightness: bottomBar != null
            ? Brightness.light
            : Brightness.dark,
        // Edge-to-edge: let the app's own colour show through instead of the
        // translucent scrim Android otherwise forces behind the gesture bar.
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Status-bar band. Animated so screens with different header
            // colours cross-fade rather than snap.
            AnimatedContainer(
              duration: Motion.normal,
              curve: Motion.enter,
              height: topInset,
              color: headerColor,
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: body,
              ),
            ),
            ?floatingBar,
            ?bottomBar,
          ],
        ),
      ),
    );
  }
}

/// Yellow header block used at the top of most screens.
class KwHeader extends StatelessWidget {
  const KwHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 12),
    this.color = AppColors.yellow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: padding,
      child: child,
    );
  }
}
