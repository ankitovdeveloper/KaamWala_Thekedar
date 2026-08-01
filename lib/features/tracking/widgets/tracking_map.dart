import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/animations/effects.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api/api_config.dart';
import '../../../data/models/models.dart';
import '../../../widgets/kw_map.dart';

/// Interpolates between two fixes so a polled position can be animated.
class GeoPointTween extends Tween<GeoPoint> {
  GeoPointTween({required GeoPoint super.begin, required GeoPoint super.end});

  @override
  GeoPoint lerp(double t) => begin!.lerpTo(end!, t);
}

/// The worker's marker moving towards the job site.
///
/// Polls land every few seconds, which on their own would make the marker jump.
/// Each new fix is animated from the previous one over roughly the poll
/// interval, so the dot slides the way a delivery map's does — the smoothness
/// is a rendering concern here, not something the server has to provide.
class TrackingMap extends StatelessWidget {
  const TrackingMap({
    super.key,
    required this.worker,
    this.previous,
    this.destination,
    this.stage = JobStage.onTheWay,
  });

  /// Latest reported position.
  final GeoPoint worker;

  /// The fix before it — the tween's starting point. Null on the first sample,
  /// where there is nothing to animate from.
  final GeoPoint? previous;

  final GeoPoint? destination;
  final JobStage stage;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<GeoPoint>(
      tween: GeoPointTween(begin: previous ?? worker, end: worker),
      duration: ApiConfig.trackingPollInterval,
      curve: Curves.linear,
      builder: (context, position, _) =>
          _MapAt(position: position, destination: destination, stage: stage),
    );
  }
}

class _MapAt extends StatefulWidget {
  const _MapAt({
    required this.position,
    required this.destination,
    required this.stage,
  });

  final GeoPoint position;
  final GeoPoint? destination;
  final JobStage stage;

  @override
  State<_MapAt> createState() => _MapAtState();
}

class _MapAtState extends State<_MapAt> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(_MapAt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) _follow();
  }

  /// Keeps both ends of the journey in frame while the worker is moving; once
  /// they arrive there is nothing to span, so the camera just centres on them.
  void _follow() {
    final controller = _controller;
    if (controller == null) return;

    final destination = widget.destination;
    if (destination == null || widget.stage != JobStage.onTheWay) {
      controller.animateCamera(
        CameraUpdate.newLatLng(widget.position.toLatLng()),
      );
      return;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            widget.position.lat < destination.lat
                ? widget.position.lat
                : destination.lat,
            widget.position.lng < destination.lng
                ? widget.position.lng
                : destination.lng,
          ),
          northeast: LatLng(
            widget.position.lat > destination.lat
                ? widget.position.lat
                : destination.lat,
            widget.position.lng > destination.lng
                ? widget.position.lng
                : destination.lng,
          ),
        ),
        72,
      ),
    );
  }

  Set<Marker> get _markers => {
    Marker(
      markerId: const MarkerId('worker'),
      position: widget.position.toLatLng(),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: const InfoWindow(title: 'Kaam wala'),
      flat: true,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 2,
    ),
    if (widget.destination case final destination?)
      Marker(
        markerId: const MarkerId('site'),
        position: destination.toLatLng(),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Kaam ki jagah'),
      ),
  };

  /// A straight line, not a routed path: turn-by-turn geometry would need the
  /// Directions API, and the remaining-distance cue reads fine without it.
  Set<Polyline> get _polylines => switch (widget.destination) {
    final destination? when widget.stage == JobStage.onTheWay => {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.position.toLatLng(), destination.toLatLng()],
        color: AppColors.black.withValues(alpha: 0.55),
        width: 4,
        patterns: [PatternItem.dash(18), PatternItem.gap(10)],
      ),
    },
    _ => const {},
  };

  @override
  Widget build(BuildContext context) => KwMap(
    center: widget.position,
    zoom: 14.5,
    markers: _markers,
    polylines: _polylines,
    onMapCreated: (controller) {
      _controller = controller;
      _follow();
    },
    fallback: _TrackingFallback(stage: widget.stage),
  );
}

/// Shown when no Maps key is configured — conveys movement without tiles.
class _TrackingFallback extends StatelessWidget {
  const _TrackingFallback({required this.stage});

  final JobStage stage;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.mapWater,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseRings(
            maxRadius: 34,
            ringCount: 3,
            color: AppColors.black,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black, width: 3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(stage.label, style: AppType.bodyStrong),
          const SizedBox(height: 2),
          Text(
            'Map ke liye Google Maps key chahiye',
            style: AppType.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
