import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Counts a number up from zero on first paint. Used by the stat strips so the
/// screen feels like it's reporting live figures rather than static text.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = Motion.lazy,
    this.delay = Duration.zero,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.groupThousands = false,
  });

  final num value;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final String prefix;
  final String suffix;
  final int decimals;
  final bool groupThousands;

  String _format(num v) {
    var text = decimals > 0
        ? v.toStringAsFixed(decimals)
        : v.round().toString();
    if (groupThousands) text = _withCommas(text);
    return '$prefix$text$suffix';
  }

  /// Indian digit grouping — 1,35,000 not 135,000. This is an India-first
  /// product, so lakh/crore grouping is the correct default.
  static String _withCommas(String number) {
    final negative = number.startsWith('-');
    var body = negative ? number.substring(1) : number;

    // Group only the integer part; keep any fractional tail untouched.
    final dot = body.indexOf('.');
    final tail = dot == -1 ? '' : body.substring(dot);
    if (dot != -1) body = body.substring(0, dot);

    if (body.length > 3) {
      final last3 = body.substring(body.length - 3);
      var rest = body.substring(0, body.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      body = '${groups.join(',')},$last3';
    }

    return '${negative ? '-' : ''}$body$tail';
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(_format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Motion.emphasized,
      builder: (context, v, _) => Text(_format(v), style: style),
    );
  }
}

/// Starts or stops a looping decorative animation to match the platform's
/// "reduce motion" setting.
///
/// Beyond the accessibility win, this is what keeps a never-ending ticker from
/// blocking `pumpAndSettle` in widget tests.
void syncDecorativeTicker(
  State state,
  AnimationController controller, {
  bool run = true,
  bool reverse = false,
}) {
  final shouldRun = run && !MediaQuery.disableAnimationsOf(state.context);
  if (shouldRun && !controller.isAnimating) {
    controller.repeat(reverse: reverse);
  } else if (!shouldRun && controller.isAnimating) {
    controller.stop();
  }
}

/// Sweeping highlight used for skeleton placeholders while data loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  /// A plain skeleton block sized to [width] x [height].
  static Widget box({
    double? width,
    double height = 12,
    BorderRadius radius = const BorderRadius.all(Radius.circular(6)),
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: radius,
    ),
  );

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncDecorativeTicker(this, _c, run: widget.enabled);
  }

  @override
  void didUpdateWidget(covariant Shimmer old) {
    super.didUpdateWidget(old);
    if (widget.enabled != old.enabled) {
      syncDecorativeTicker(this, _c, run: widget.enabled);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final slide = _c.value * 2 - 0.5;
          return LinearGradient(
            begin: Alignment(slide - 0.6, -0.3),
            end: Alignment(slide + 0.6, 0.3),
            colors: const [
              AppColors.surfaceAlt,
              AppColors.white,
              AppColors.surfaceAlt,
            ],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Expanding rings radiating from a point — the "you are here" pulse on the map
/// and the live-status halo on availability dots.
class PulseRings extends StatefulWidget {
  const PulseRings({
    super.key,
    required this.child,
    this.color = AppColors.yellow,
    this.maxRadius = 26,
    this.ringCount = 2,
    this.period = const Duration(milliseconds: 2200),
  });

  final Widget child;
  final Color color;
  final double maxRadius;
  final int ringCount;
  final Duration period;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncDecorativeTicker(this, _c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => CustomPaint(
        painter: _RingPainter(
          progress: _c.value,
          color: widget.color,
          maxRadius: widget.maxRadius,
          ringCount: widget.ringCount,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.maxRadius,
    required this.ringCount,
  });

  final double progress;
  final Color color;
  final double maxRadius;
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < ringCount; i++) {
      final t = (progress + i / ringCount) % 1.0;
      final radius = maxRadius * Curves.easeOut.transform(t);
      final opacity = (1 - t) * 0.45;
      if (opacity <= 0.01) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// Slow, continuous vertical drift. Gives the login hero a sense of life
/// without demanding attention.
class Floating extends StatefulWidget {
  const Floating({
    super.key,
    required this.child,
    this.amplitude = 5,
    this.period = const Duration(milliseconds: 3600),
  });

  final Widget child;
  final double amplitude;
  final Duration period;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncDecorativeTicker(this, _c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, math.sin(_c.value * 2 * math.pi) * widget.amplitude),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Swaps between children with a cross-fade + slight rise. Used for button
/// label ⇄ spinner ⇄ tick transitions.
class SwapIn extends StatelessWidget {
  const SwapIn({super.key, required this.child, this.duration = Motion.fast});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Animated tick that draws itself — the OTP success confirmation.
class DrawnCheck extends StatefulWidget {
  const DrawnCheck({
    super.key,
    this.size = 56,
    this.color = AppColors.black,
    this.background = AppColors.yellow,
  });

  final double size;
  final Color color;
  final Color background;

  @override
  State<DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<DrawnCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.lazy,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final pop = Curves.easeOutBack.transform(
          (_c.value / 0.45).clamp(0.0, 1.0),
        );
        final stroke = Curves.easeOutCubic.transform(
          ((_c.value - 0.35) / 0.65).clamp(0.0, 1.0),
        );
        return Transform.scale(
          scale: pop,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.background,
              shape: BoxShape.circle,
            ),
            child: CustomPaint(
              painter: _CheckPainter(progress: stroke, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final p1 = Offset(w * 0.28, w * 0.52);
    final p2 = Offset(w * 0.44, w * 0.68);
    final p3 = Offset(w * 0.73, w * 0.36);

    final leg1 = (p2 - p1).distance;
    final leg2 = (p3 - p2).distance;
    final total = leg1 + leg2;
    final drawn = total * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= leg1) {
      final t = drawn / leg1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = ((drawn - leg1) / leg2).clamp(0.0, 1.0);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
