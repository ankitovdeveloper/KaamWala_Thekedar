import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/maps/maps_loader.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/api/api_config.dart';
import '../data/models/models.dart';

/// Google Maps, with a graceful path for every state that isn't "a map".
///
/// When no `GOOGLE_MAPS_API_KEY` is configured this renders [fallback] — the
/// app's stylised canvas — instead of Google's grey error tiles. That keeps the
/// app usable without a key and keeps widget tests renderable, since the maps
/// plugin has no test harness implementation.
class KwMap extends StatefulWidget {
  const KwMap({
    super.key,
    required this.center,
    required this.fallback,
    this.zoom = 13,
    this.markers = const {},
    this.circles = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.onCameraIdle,
    this.onCameraMove,
    this.interactive = true,
    this.padding = EdgeInsets.zero,
  });

  final GeoPoint center;
  final double zoom;

  /// Shown when there is no API key, while the web SDK loads, and if that load
  /// fails — the surrounding screen never has to handle a missing map.
  final Widget fallback;

  final Set<Marker> markers;
  final Set<Circle> circles;
  final Set<Polyline> polylines;

  final ValueChanged<GoogleMapController>? onMapCreated;
  final VoidCallback? onCameraIdle;
  final ValueChanged<CameraPosition>? onCameraMove;

  /// False for the small preview maps, where a stray scroll shouldn't pan.
  final bool interactive;
  final EdgeInsets padding;

  @override
  State<KwMap> createState() => _KwMapState();
}

class _KwMapState extends State<KwMap> {
  /// Web has to pull the JS API in before the first map is built; the stub
  /// implementation completes immediately everywhere else.
  late final Future<void> _ready = ApiConfig.hasMapsKey
      ? ensureMapsLoaded(ApiConfig.mapsApiKey)
      : Future<void>.value();

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.hasMapsKey) return widget.fallback;

    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) => switch (snapshot.connectionState) {
        ConnectionState.done when snapshot.hasError => _LoadFailed(
          fallback: widget.fallback,
        ),
        ConnectionState.done => _map(),
        _ => widget.fallback,
      },
    );
  }

  Widget _map() => GoogleMap(
    initialCameraPosition: CameraPosition(
      target: widget.center.toLatLng(),
      zoom: widget.zoom,
    ),
    markers: widget.markers,
    circles: widget.circles,
    polylines: widget.polylines,
    onMapCreated: widget.onMapCreated,
    onCameraIdle: widget.onCameraIdle,
    onCameraMove: widget.onCameraMove,
    padding: widget.padding,
    // The app draws its own controls in the theme's style.
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
    myLocationButtonEnabled: false,
    compassEnabled: false,
    scrollGesturesEnabled: widget.interactive,
    zoomGesturesEnabled: widget.interactive,
    rotateGesturesEnabled: false,
    tiltGesturesEnabled: false,
  );
}

/// A bad key or an offline page — say so quietly over the stylised map rather
/// than replacing the screen with an error.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.fallback});

  final Widget fallback;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      fallback,
      Positioned(
        left: 0,
        right: 0,
        bottom: 8,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Map load nahi hua',
              style: AppType.nano.copyWith(
                fontSize: 10,
                color: AppColors.yellow,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Bridges the SDK-free [GeoPoint] the data layer speaks to the plugin's type.
extension GeoPointMaps on GeoPoint {
  LatLng toLatLng() => LatLng(lat, lng);
}

extension LatLngGeo on LatLng {
  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}
