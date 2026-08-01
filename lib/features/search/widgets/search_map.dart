import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_map.dart';
import 'map_canvas.dart';

/// The search map: everyone inside the radius, drawn around the search origin.
///
/// The circle is the search itself made visible — its size is the `radius` the
/// API filters by, so widening the slider visibly grows the area and brings
/// more pins in. Without a Maps key this degrades to the stylised [MapCanvas],
/// which keeps the screen working and the widget tests renderable.
class SearchMap extends StatefulWidget {
  const SearchMap({
    super.key,
    required this.origin,
    required this.radiusKm,
    required this.labours,
    required this.onPinTap,
    this.selectedId,
    this.height = 200,
  });

  final GeoPoint origin;
  final int radiusKm;
  final List<Labour> labours;
  final ValueChanged<Labour> onPinTap;
  final int? selectedId;
  final double height;

  @override
  State<SearchMap> createState() => _SearchMapState();
}

class _SearchMapState extends State<SearchMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(SearchMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-frame when the area being searched changes, not when results churn
    // inside an unchanged area — otherwise the map jumps on every keystroke.
    if (oldWidget.radiusKm != widget.radiusKm ||
        oldWidget.origin != widget.origin) {
      _fitRadius();
    }
  }

  void _fitRadius() {
    final controller = _controller;
    if (controller == null) return;
    controller.animateCamera(CameraUpdate.newLatLngBounds(_radiusBounds(), 24));
  }

  /// The square that just contains the search circle.
  LatLngBounds _radiusBounds() {
    const kmPerLatDegree = 111.32;
    final latDelta = widget.radiusKm / kmPerLatDegree;
    // Longitude degrees shrink towards the poles.
    final lngDelta =
        widget.radiusKm /
        (kmPerLatDegree * math.cos(widget.origin.lat * math.pi / 180)).abs();

    return LatLngBounds(
      southwest: LatLng(
        widget.origin.lat - latDelta,
        widget.origin.lng - lngDelta,
      ),
      northeast: LatLng(
        widget.origin.lat + latDelta,
        widget.origin.lng + lngDelta,
      ),
    );
  }

  Set<Marker> get _markers {
    final s = context.s;
    return {
    Marker(
      markerId: const MarkerId('origin'),
      position: widget.origin.toLatLng(),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(title: s.youAreHere),
      zIndexInt: 2,
    ),
    for (final labour in widget.labours)
      if (labour.latLng case final position?)
        Marker(
          markerId: MarkerId('labour-${labour.id}'),
          position: position.toLatLng(),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            labour.id == widget.selectedId
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(
            title: labour.name,
            snippet:
                '₹${labour.dailyRate}${s.perDay} · '
                '${labour.primarySkillIn(s)}',
          ),
          onTap: () => widget.onPinTap(labour),
        ),
    };
  }

  Set<Circle> get _circles => {
    Circle(
      circleId: const CircleId('radius'),
      center: widget.origin.toLatLng(),
      radius: widget.radiusKm * 1000,
      fillColor: AppColors.yellow.withValues(alpha: 0.14),
      strokeColor: AppColors.yellowDark,
      strokeWidth: 2,
    ),
  };

  /// Wide radius → zoomed out. Each doubling of the radius is one zoom level.
  double get _zoom => (14 - math.log(widget.radiusKm) / math.ln2).clamp(9, 15);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: KwMap(
      center: widget.origin,
      zoom: _zoom,
      markers: _markers,
      circles: _circles,
      onMapCreated: (controller) {
        _controller = controller;
        _fitRadius();
      },
      fallback: MapCanvas(
        labours: widget.labours,
        selectedId: widget.selectedId,
        height: widget.height,
        onPinTap: widget.onPinTap,
      ),
    ),
  );
}
