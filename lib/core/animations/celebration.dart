import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The green tick that announces a success — a disc that pops in, a ring that
/// sweeps around it, rays that fire outward, and a check drawn by hand.
///
/// Built as one painter rather than a stack of animated widgets: every layer
/// reads the same clock, so the sweep, the rays and the stroke stay in step no
/// matter how the frame budget wobbles.
class SuccessBurst extends StatefulWidget {
  const SuccessBurst({
    super.key,
    this.size = 96,
    this.color = AppColors.success,
    this.accent = AppColors.successDark,
    this.tick = AppColors.white,
  });

  /// Diameter of the whole effect, rays and rings included. The green disc is
  /// roughly two thirds of it.
  final double size;

  final Color color;
  final Color accent;
  final Color tick;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Reduce motion" gets the finished tick, not a missing one — the shape is
    // the message; the movement is only the delivery.
    final progress = MediaQuery.disableAnimationsOf(context) ? 1.0 : null;
    if (progress != null) {
      return CustomPaint(
        size: Size.square(widget.size),
        painter: _SuccessBurstPainter(
          progress: progress,
          color: widget.color,
          accent: widget.accent,
          tick: widget.tick,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _SuccessBurstPainter(
          progress: _c.value,
          color: widget.color,
          accent: widget.accent,
          tick: widget.tick,
        ),
      ),
    );
  }
}

class _SuccessBurstPainter extends CustomPainter {
  _SuccessBurstPainter({
    required this.progress,
    required this.color,
    required this.accent,
    required this.tick,
  });

  final double progress;
  final Color color;
  final Color accent;
  final Color tick;

  /// Maps the global 0–1 clock onto one layer's own window, so each layer can
  /// be written as if it ran alone.
  static double _phase(double p, double start, double end, {Curve? curve}) {
    final t = ((p - start) / (end - start)).clamp(0.0, 1.0);
    return curve == null ? t : curve.transform(t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final discR = r * 0.62;

    _glow(canvas, center, r);
    _rings(canvas, center, r, discR);
    _rays(canvas, center, r, discR);
    _disc(canvas, center, discR);
    _sweep(canvas, center, discR);
    _check(canvas, center, discR);
  }

  /// A soft green wash behind everything, brightest as the disc lands.
  void _glow(Canvas canvas, Offset center, double r) {
    final t = _phase(progress, 0, 0.42, curve: Curves.easeOut);
    final settle = _phase(progress, 0.42, 0.9, curve: Curves.easeOut);
    final alpha = (0.30 * t) - (0.16 * settle);
    if (alpha <= 0.01) return;

    canvas.drawCircle(
      center,
      r * (0.62 + 0.38 * t),
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  /// Two haloes pushing outward, the second half a beat behind the first.
  void _rings(Canvas canvas, Offset center, double r, double discR) {
    for (var i = 0; i < 2; i++) {
      final t = _phase(progress, 0.10 + i * 0.15, 0.68 + i * 0.15);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      canvas.drawCircle(
        center,
        discR + (r - discR) * eased,
        Paint()
          ..color = color.withValues(alpha: (1 - t) * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * (1 - t) + 0.8,
      );
    }
  }

  /// The little spokes that read as a pop rather than a fade-in.
  void _rays(Canvas canvas, Offset center, double r, double discR) {
    final t = _phase(progress, 0.26, 0.72, curve: Curves.easeOutCubic);
    if (t <= 0) return;
    final fade = 1 - _phase(progress, 0.52, 0.86);
    if (fade <= 0.01) return;

    const count = 10;
    final gap = r - discR;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.55 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.055
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      // Half a step of offset so the spokes never line up with the tick.
      final angle = (i / count) * 2 * math.pi + math.pi / count;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final inner = discR + gap * (0.18 + 0.55 * t);
      final outer = inner + gap * 0.34 * t;
      canvas.drawLine(center + dir * inner, center + dir * outer, paint);
    }
  }

  /// The green disc itself, arriving with a spring overshoot.
  void _disc(Canvas canvas, Offset center, double discR) {
    final pop = _phase(progress, 0, 0.38, curve: Curves.easeOutBack);
    if (pop <= 0) return;
    canvas.drawCircle(center, discR * pop, Paint()..color = color);
  }

  /// One turn of a darker arc around the rim — the "it went through" gesture.
  void _sweep(Canvas canvas, Offset center, double discR) {
    final t = _phase(progress, 0.08, 0.58, curve: Curves.easeInOutCubic);
    if (t <= 0) return;
    final fade = 1 - _phase(progress, 0.62, 0.95);
    if (fade <= 0.01) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: discR * 1.16),
      -math.pi / 2,
      2 * math.pi * t,
      false,
      Paint()
        ..color = accent.withValues(alpha: 0.8 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = discR * 0.13
        ..strokeCap = StrokeCap.round,
    );
  }

  /// The check, drawn stroke-first so it looks written rather than stamped.
  void _check(Canvas canvas, Offset center, double discR) {
    final t = _phase(progress, 0.28, 0.70, curve: Curves.easeOutCubic);
    if (t <= 0) return;

    final p1 = center + Offset(-discR * 0.42, discR * 0.04);
    final p2 = center + Offset(-discR * 0.12, discR * 0.34);
    final p3 = center + Offset(discR * 0.46, -discR * 0.30);

    final leg1 = (p2 - p1).distance;
    final leg2 = (p3 - p2).distance;
    final drawn = (leg1 + leg2) * t;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= leg1) {
      final k = drawn / leg1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * k, p1.dy + (p2.dy - p1.dy) * k);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final k = ((drawn - leg1) / leg2).clamp(0.0, 1.0);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * k, p2.dy + (p3.dy - p2.dy) * k);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = tick
        ..style = PaintingStyle.stroke
        ..strokeWidth = discR * 0.19
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SuccessBurstPainter old) => old.progress != progress;
}

/// Paper thrown from a point, then left to gravity and air.
///
/// Two waves rather than one: a single burst all lands at the same moment and
/// the screen goes flat, which is exactly when a celebration stops feeling like
/// one. Everything scales off the widget's own size, so it looks the same on a
/// small phone and on a tablet.
class Confetti extends StatefulWidget {
  const Confetti({
    super.key,
    this.count = 54,
    this.origin = const Alignment(0, -0.5),
    this.seed,
  });

  /// Pieces in the first wave. The second wave adds another two thirds.
  final int count;

  /// Where the popper is pointed from, in the usual -1…1 alignment space.
  final Alignment origin;

  /// Fixed seed for tests and screenshots; random when null.
  final int? seed;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  /// Long enough for the slowest piece to fall off the bottom.
  static const _span = Duration(milliseconds: 3400);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _span,
  );

  late final List<_Confetto> _pieces;

  @override
  void initState() {
    super.initState();
    // Built once: respawning the field on every frame would reshuffle the paper
    // mid-flight.
    _pieces = _spawn(
      math.Random(widget.seed ?? DateTime.now().microsecondsSinceEpoch),
      widget.count,
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static List<_Confetto> _spawn(math.Random rnd, int count) {
    // In palette: the brand yellows, the success greens, and the ink. White is
    // deliberately absent — it disappears against the card.
    const colors = [
      AppColors.yellow,
      AppColors.yellowDark,
      AppColors.success,
      AppColors.successDark,
      AppColors.black,
      // A lighter mint, so the two greens do not read as one blob.
      Color(0xFF8BD79B),
    ];

    double between(double a, double b) => a + rnd.nextDouble() * (b - a);

    return [
      for (var wave = 0; wave < 2; wave++)
        // The follow-up wave is smaller and thrown a little softer.
        for (var i = 0; i < (wave == 0 ? count : count * 2 ~/ 3); i++)
          _Confetto(
            // A fan pointing up: mostly vertical, wide enough to clear the card.
            angle: -math.pi / 2 + between(-1.15, 1.15),
            speed: between(230, 620) * (wave == 0 ? 1 : 0.82),
            gravity: between(620, 950),
            drag: between(0.55, 0.95),
            width: between(5.5, 11),
            aspect: between(0.34, 1.0),
            round: rnd.nextInt(4) == 0,
            color: colors[rnd.nextInt(colors.length)],
            spin: between(1.6, 5.2) * (rnd.nextBool() ? 1 : -1),
            flip: between(2.2, 6.0),
            phase: between(0, math.pi * 2),
            delay: wave == 0 ? between(0, 0.12) : between(0.26, 0.44),
            life: between(1.7, 2.9),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            pieces: _pieces,
            elapsed: _c.value * _span.inMilliseconds / 1000,
            origin: widget.origin,
          ),
        ),
      ),
    );
  }
}

/// One piece of paper. Everything about the flight is decided at launch, so the
/// painter stays a pure function of elapsed time — no per-frame state to drift.
@immutable
class _Confetto {
  const _Confetto({
    required this.angle,
    required this.speed,
    required this.gravity,
    required this.drag,
    required this.width,
    required this.aspect,
    required this.round,
    required this.color,
    required this.spin,
    required this.flip,
    required this.phase,
    required this.delay,
    required this.life,
  });

  final double angle;
  final double speed;
  final double gravity;

  /// Time constant of the air resistance, in seconds. Bigger drifts further.
  final double drag;

  final double width;

  /// Height as a fraction of [width] — under 1 it reads as a ribbon.
  final double aspect;

  final bool round;
  final Color color;

  /// Turns per second about the centre, and about the horizontal axis.
  final double spin;
  final double flip;

  final double phase;
  final double delay;
  final double life;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.pieces,
    required this.elapsed,
    required this.origin,
  });

  final List<_Confetto> pieces;
  final double elapsed;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Tuned against a mid-size phone, then scaled so a tablet does not get a
    // handful of slow specks.
    final scale = (size.shortestSide / 390).clamp(0.8, 1.7);
    final launch = origin.alongSize(size);
    final paint = Paint();

    for (final piece in pieces) {
      final t = elapsed - piece.delay;
      if (t <= 0 || t > piece.life) continue;

      // Linear drag with gravity, integrated exactly: the paper shoots out,
      // slows, and settles into a terminal fall instead of accelerating away.
      final damp = piece.drag * (1 - math.exp(-t / piece.drag));
      final x =
          launch.dx +
          math.cos(piece.angle) * piece.speed * damp * scale +
          math.sin(t * 3 + piece.phase) * 9 * scale;
      final y =
          launch.dy +
          (math.sin(piece.angle) * piece.speed * damp +
                  piece.gravity * (t - damp)) *
              scale;

      if (y > size.height + 40 || x < -40 || x > size.width + 40) continue;

      // Full opacity while it matters, then let go over the last third.
      final fade = 1 - ((t / piece.life - 0.62) / 0.38).clamp(0.0, 1.0);
      paint.color = piece.color.withValues(alpha: fade);

      final w = piece.width * scale;
      final h = w * piece.aspect;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * t * 2 * math.pi);
      // Squashing the height as it turns is what sells it as a flat sheet
      // tumbling, rather than a coloured dot sliding down the screen.
      final squash = math.cos(piece.flip * t * 2 * math.pi).abs();
      canvas.scale(1, squash.clamp(0.12, 1.0));

      if (piece.round) {
        canvas.drawCircle(Offset.zero, w / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            Radius.circular(w * 0.18),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.elapsed != elapsed;
}
