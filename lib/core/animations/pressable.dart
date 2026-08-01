import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Tap target that dips slightly under the finger and springs back on release.
/// Used everywhere instead of bare InkWell so touch feedback is consistent and
/// works on surfaces where an ink ripple would be invisible (yellow on yellow).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
    this.borderRadius,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Depth of the press. Bigger surfaces want a shallower dip.
  final double scale;
  final bool haptic;
  final BorderRadius? borderRadius;
  final HitTestBehavior behavior;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.instant,
    reverseDuration: Motion.fast,
    lowerBound: 0,
    upperBound: 1,
  );

  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: widget.scale,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) {
    if (_enabled) _c.forward();
  }

  void _up(_) {
    if (_enabled) _c.reverse();
  }

  void _cancel() {
    if (_enabled) _c.reverse();
  }

  void _tap() {
    if (!_enabled) return;
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ScaleTransition(scale: _scale, child: widget.child);

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    return Semantics(
      button: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _cancel,
        onTap: _tap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: content,
        ),
      ),
    );
  }
}

/// Card-style surface that lifts on hover (desktop/web) and dips on press.
/// The mockups' `.labour-card:hover{box-shadow:…}` rule, made interactive.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.builder,
    this.onTap,
    this.lift = 2,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final double lift;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: Motion.fast,
        curve: Motion.enter,
        offset: Offset(0, _hovered ? -widget.lift / 40 : 0),
        child: Pressable(
          scale: 0.985,
          onTap: widget.onTap,
          child: widget.builder(context, _hovered),
        ),
      ),
    );
  }
}
