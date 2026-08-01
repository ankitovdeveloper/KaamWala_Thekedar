import 'package:flutter/material.dart';

import '../../../core/animations/effects.dart';
import '../../../core/animations/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';

/// Stylised map stand-in matching the mockup's CSS-drawn streets. Pins drop in
/// on load and the "you are here" dot pulses continuously.
///
/// Swapping in a real map SDK means replacing the painter and positioning pins
/// from `Labour.latLng` — the pin widgets themselves stay as they are.
class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.labours,
    required this.onPinTap,
    this.selectedId,
    this.height = 200,
  });

  final List<Labour> labours;
  final ValueChanged<Labour> onPinTap;
  final int? selectedId;
  final double height;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: Motion.lazy,
  );

  @override
  void initState() {
    super.initState();
    _drop.forward();
  }

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _StreetPainter())),
            // Soft vignette keeps the search bar legible over the map.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1F000000), Color(0x00000000)],
                    stops: [0, 0.45],
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < widget.labours.length; i++)
                    _positioned(
                      constraints: constraints,
                      labour: widget.labours[i],
                      order: i,
                    ),
                  // "You" marker, anchored centre-ish like the mockup.
                  Positioned(
                    left: constraints.maxWidth * 0.40,
                    top: constraints.maxHeight * 0.52,
                    child: _youPin(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Projects each labour's real coordinates onto the canvas, normalised
  /// against the bounding box of the whole result set. Workers without
  /// coordinates fall back to a stable spread so they still appear.
  Offset _normalised(Labour labour, int order) {
    final located = widget.labours
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();

    if (labour.latitude == null ||
        labour.longitude == null ||
        located.isEmpty) {
      // Golden-ratio scatter: deterministic, and never stacks two pins.
      return Offset((order * 0.618) % 1.0, (order * 0.382 + 0.15) % 1.0);
    }

    final lats = located.map((l) => l.latitude!);
    final lngs = located.map((l) => l.longitude!);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    // A single result (or a perfectly flat span) has no extent to divide by.
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;

    return Offset(
      lngSpan < 1e-9 ? 0.5 : (labour.longitude! - minLng) / lngSpan,
      // Screen Y grows downward; latitude grows north, so invert.
      latSpan < 1e-9 ? 0.5 : (maxLat - labour.latitude!) / latSpan,
    );
  }

  Widget _positioned({
    required BoxConstraints constraints,
    required Labour labour,
    required int order,
  }) {
    final position = _normalised(labour, order);
    // Inset so pins never sit flush against an edge on narrow screens.
    final x = 20 + position.dx * (constraints.maxWidth - 90);
    final y = 14 + position.dy * (constraints.maxHeight - 80);

    final anim = CurvedAnimation(
      parent: _drop,
      curve: Interval(
        (order * 0.12).clamp(0.0, 0.7),
        ((order * 0.12) + 0.5).clamp(0.1, 1.0),
        curve: Curves.easeOutBack,
      ),
    );

    return Positioned(
      left: x,
      top: y,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, child) => Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.translate(
            // Pins fall the last few pixels into place.
            offset: Offset(0, -26 * (1 - anim.value)),
            child: Transform.scale(
              scale: 0.6 + 0.4 * anim.value,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        ),
        child: _LabourPin(
          labour: labour,
          selected: labour.id == widget.selectedId,
          onTap: () => widget.onPinTap(labour),
        ),
      ),
    );
  }

  Widget _youPin() {
    return PulseRings(
      maxRadius: 24,
      ringCount: 3,
      color: AppColors.black,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: AppColors.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.black, width: 3),
        ),
      ),
    );
  }
}

class _LabourPin extends StatelessWidget {
  const _LabourPin({
    required this.labour,
    required this.selected,
    required this.onTap,
  });

  final Labour labour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            duration: Motion.normal,
            curve: Motion.spring,
            scale: selected ? 1.25 : 1,
            child: Transform.rotate(
              angle: -0.785398, // -45°, the classic teardrop pin
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border.all(color: AppColors.yellow, width: 3),
                  boxShadow: AppColors.floatingShadow,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.yellow : AppColors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              labour.name.split(' ').first,
              style: AppType.nano.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.black : AppColors.yellow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the grid, roads and building blocks from the mockup's CSS layers.
class _StreetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapWater);

    // 30px grid
    final grid = Paint()
      ..color = AppColors.veil06
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Building blocks, placed proportionally so they survive any width.
    final block = Paint()..color = AppColors.mapBlock;
    final blocks = <Rect>[
      Rect.fromLTWH(
        size.width * 0.26,
        size.height * 0.39,
        size.width * 0.31,
        size.height * 0.24,
      ),
      Rect.fromLTWH(
        size.width * 0.61,
        size.height * 0.39,
        size.width * 0.21,
        size.height * 0.24,
      ),
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.72,
        size.width * 0.18,
        size.height * 0.18,
      ),
      Rect.fromLTWH(
        size.width * 0.68,
        size.height * 0.74,
        size.width * 0.24,
        size.height * 0.16,
      ),
    ];
    for (final r in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(2)),
        block,
      );
    }

    // Roads
    final road = Paint()..color = AppColors.mapRoad;
    for (final t in [0.35, 0.65]) {
      canvas.drawRect(Rect.fromLTWH(0, size.height * t, size.width, 5), road);
    }
    for (final t in [0.24, 0.59]) {
      canvas.drawRect(Rect.fromLTWH(size.width * t, 0, 5, size.height), road);
    }
  }

  @override
  bool shouldRepaint(_StreetPainter oldDelegate) => false;
}
