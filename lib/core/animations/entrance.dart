import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Direction the content travels in from during its entrance.
enum SlideFrom { bottom, top, left, right, none }

/// Fade + slide + optional scale entrance that plays once when the widget is
/// first mounted. `delay` is what makes staggered lists possible.
///
/// Honours the platform "reduce motion" setting by snapping straight to the
/// resting state — an entrance animation is decorative, never load-bearing.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.from = SlideFrom.bottom,
    this.offset = 18,
    this.beginScale,
    this.curve = Motion.enter,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final SlideFrom from;

  /// Travel distance in logical pixels.
  final double offset;

  /// When set, the child also scales up from this value (1.0 == no scaling).
  final double? beginScale;
  final Curve curve;

  /// Convenience for list items: index-based delay off a shared base.
  factory FadeSlideIn.staggered({
    Key? key,
    required int index,
    required Widget child,
    Duration base = Duration.zero,
    Duration step = Motion.stagger,
    Duration duration = Motion.slow,
    SlideFrom from = SlideFrom.bottom,
    double offset = 18,
    double? beginScale,
  }) => FadeSlideIn(
    key: key,
    delay: base + step * index,
    duration: duration,
    from: from,
    offset: offset,
    beginScale: beginScale,
    child: child,
  );

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Offset _begin() => switch (widget.from) {
    SlideFrom.bottom => Offset(0, widget.offset),
    SlideFrom.top => Offset(0, -widget.offset),
    SlideFrom.left => Offset(-widget.offset, 0),
    SlideFrom.right => Offset(widget.offset, 0),
    SlideFrom.none => Offset.zero,
  };

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: widget.curve);
    final begin = _begin();

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        final dx = begin.dx * (1 - t);
        final dy = begin.dy * (1 - t);
        Widget content = Opacity(opacity: t.clamp(0.0, 1.0), child: child);

        if (widget.beginScale != null) {
          final scale = widget.beginScale! + (1 - widget.beginScale!) * t;
          content = Transform.scale(scale: scale, child: content);
        }
        return Transform.translate(offset: Offset(dx, dy), child: content);
      },
      child: widget.child,
    );
  }
}

/// Wraps every child of a column-like list in a [FadeSlideIn] whose delay grows
/// with its index — one call instead of hand-tuning delays per row.
class Stagger extends StatelessWidget {
  const Stagger({
    super.key,
    required this.children,
    this.base = Duration.zero,
    this.step = Motion.stagger,
    this.from = SlideFrom.bottom,
    this.offset = 18,
    this.beginScale,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.min,
  });

  final List<Widget> children;
  final Duration base;
  final Duration step;
  final SlideFrom from;
  final double offset;
  final double? beginScale;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  /// Just the wrapping, for callers that own their own layout widget.
  static List<Widget> wrap({
    required List<Widget> children,
    Duration base = Duration.zero,
    Duration step = Motion.stagger,
    SlideFrom from = SlideFrom.bottom,
    double offset = 18,
    double? beginScale,
  }) => [
    for (var i = 0; i < children.length; i++)
      FadeSlideIn(
        delay: base + step * i,
        from: from,
        offset: offset,
        beginScale: beginScale,
        child: children[i],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: wrap(
        children: children,
        base: base,
        step: step,
        from: from,
        offset: offset,
        beginScale: beginScale,
      ),
    );
  }
}

/// Horizontal shake used to reject bad input (wrong OTP, empty phone number).
/// Drive it by bumping [trigger]; each new value replays the shake.
class Shake extends StatefulWidget {
  const Shake({
    super.key,
    required this.child,
    required this.trigger,
    this.distance = 9,
  });

  final Widget child;
  final int trigger;
  final double distance;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Decaying sine: three visible oscillations that die out cleanly.
        final t = _c.value;
        final decay = (1 - t) * (1 - t);
        final dx = widget.distance * decay * math.sin(t * 3 * 2 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
