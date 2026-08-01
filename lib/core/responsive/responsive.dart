import 'package:flutter/material.dart';

/// Layout classes. The mockups are drawn at a 375pt phone; everything wider
/// gets progressively more room rather than a stretched phone layout.
enum FormFactor { compact, medium, expanded }

abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1000.0;

  /// Reading-comfort ceiling. Beyond this the column is centred instead of
  /// growing, so line lengths stay phone-like on desktop.
  static const contentMaxWidth = 520.0;

  /// Master pane width when a two-pane layout is active.
  static const listPaneWidth = 420.0;
}

extension ResponsiveContext on BuildContext {
  Size get _size => MediaQuery.sizeOf(this);

  double get screenWidth => _size.width;
  double get screenHeight => _size.height;

  FormFactor get formFactor {
    final w = screenWidth;
    if (w >= Breakpoints.expanded) return FormFactor.expanded;
    if (w >= Breakpoints.medium) return FormFactor.medium;
    return FormFactor.compact;
  }

  bool get isCompact => formFactor == FormFactor.compact;
  bool get isMedium => formFactor == FormFactor.medium;
  bool get isExpanded => formFactor == FormFactor.expanded;

  /// Bottom nav on phones, side rail once there is horizontal room to spare.
  bool get usesRail => screenWidth >= Breakpoints.medium;

  /// Search shows map + list side by side only when genuinely wide.
  bool get usesTwoPane => screenWidth >= Breakpoints.expanded;

  /// Short viewports (landscape phone, small web window) drop hero flourishes.
  bool get isShort => screenHeight < 620;

  /// Pick a value per form factor without a switch at every call site.
  T responsive<T>({required T compact, T? medium, T? expanded}) =>
      switch (formFactor) {
        FormFactor.compact => compact,
        FormFactor.medium => medium ?? compact,
        FormFactor.expanded => expanded ?? medium ?? compact,
      };

  /// Horizontal page padding that opens up as the window grows.
  double get pagePadding => responsive(compact: 14, medium: 20, expanded: 24);

  /// Scales a design-time dimension for larger screens, capped so nothing
  /// balloons on a desktop monitor.
  double scaled(double value) =>
      value * responsive(compact: 1.0, medium: 1.08, expanded: 1.12);
}

/// Centres and width-caps its child so long-form content never spans a
/// 27-inch monitor. Used by every scrollable body.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Sliver flavour of [ContentWidth] for CustomScrollView bodies.
class SliverContentWidth extends StatelessWidget {
  const SliverContentWidth({
    super.key,
    required this.sliver,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      sliver: sliver,
    );
  }
}

/// Clamps OS font scaling so a 200% system setting can't shatter dense rows
/// like the OTP boxes or the stat strip.
class ClampedTextScale extends StatelessWidget {
  const ClampedTextScale({
    super.key,
    required this.child,
    this.max = 1.3,
    this.min = 0.85,
  });

  final Widget child;
  final double max;
  final double min;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: min,
          maxScaleFactor: max,
        ),
      ),
      child: child,
    );
  }
}
