import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/animations/effects.dart';
import '../../../core/maps/map_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api/api_config.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';

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
    this.routePoints = const [],
  });

  /// Latest reported position.
  final GeoPoint worker;

  /// The fix before it — the tween's starting point. Null on the first sample,
  /// where there is nothing to animate from.
  final GeoPoint? previous;

  final GeoPoint? destination;
  final JobStage stage;
  final List<LatLng> routePoints;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<GeoPoint>(
      tween: GeoPointTween(begin: previous ?? worker, end: worker),
      duration: ApiConfig.trackingPollInterval,
      curve: Curves.linear,
      builder: (context, position, _) => _MapAt(
        position: position,
        destination: destination,
        stage: stage,
        routePoints: routePoints,
      ),
    );
  }
}

class _MapAt extends StatefulWidget {
  const _MapAt({
    required this.position,
    required this.destination,
    required this.stage,
    required this.routePoints,
  });

  final GeoPoint position;
  final GeoPoint? destination;
  final JobStage stage;
  final List<LatLng> routePoints;

  @override
  State<_MapAt> createState() => _MapAtState();
}

class _MapAtState extends State<_MapAt> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(_MapAt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) _follow();
  }

  /// Keeps both ends of the journey in frame while the worker is moving; once
  /// they arrive there is nothing to span, so the camera just centres on them.
  void _follow() {
    final controller = _controller;
    if (controller == null || !mounted) return;

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

  Set<Marker> get _markers {
    final s = context.s;
    return {
      Marker(
        markerId: const MarkerId('worker'),
        position: widget.position.toLatLng(),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: s.workerMarker),
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      ),
      if (widget.destination case final destination?)
        Marker(
          markerId: const MarkerId('site'),
          position: destination.toLatLng(),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: s.siteMarker),
        ),
    };
  }

  /// A real road path from Directions API. If fetching fails or they're
  /// not moving, it returns no polyline.
  Set<Polyline> get _polylines {
    // UI DEBUG LOG
    dev.log('TRACKING_UI: Route points count = ${widget.routePoints.length}', name: 'TRACKING_DEBUG');
    
    if (widget.destination == null || 
        widget.stage != JobStage.onTheWay || 
        widget.routePoints.isEmpty) {
      return const {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        // Points are already ordered road coordinates from Google.
        points: widget.routePoints,
        color: AppColors.black.withValues(alpha: 0.8),
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.hasMapsKey) {
      return _TrackingFallback(stage: widget.stage);
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.position.toLatLng(),
        zoom: 14.5,
      ),
      markers: _markers,
      polylines: _polylines,
      onMapCreated: (controller) {
        _controller = controller;
        _follow();
      },
      style: MapStyles.silver,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    );
  }
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
          Text(stage.labelIn(context.s), style: AppType.bodyStrong),
          const SizedBox(height: 2),
          Text(
            context.s.mapsKeyMissing,
            style: AppType.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
