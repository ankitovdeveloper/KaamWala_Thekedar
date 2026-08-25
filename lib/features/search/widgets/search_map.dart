import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/maps/map_styles.dart';
import '../../../core/maps/marker_generator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_map.dart';

/// The search map: everyone inside the radius, drawn around the search origin.
class SearchMap extends StatefulWidget {
  const SearchMap({
    super.key,
    required this.origin,
    required this.radiusKm,
    required this.labours,
    required this.onPinTap,
    this.selectedId,
    this.height,
    this.padding = EdgeInsets.zero,
  });

  final GeoPoint origin;
  final int radiusKm;
  final List<Labour> labours;
  final ValueChanged<Labour> onPinTap;
  final int? selectedId;
  final double? height;
  final EdgeInsets padding;

  @override
  State<SearchMap> createState() => _SearchMapState();
}

class _SearchMapState extends State<SearchMap> {
  static final LatLngBounds _indiaBounds = LatLngBounds(
    southwest: const LatLng(6.4626999, 68.1097),
    northeast: const LatLng(35.513327, 97.3953586),
  );

  GoogleMapController? _controller;
  final Map<int, BitmapDescriptor> _customIcons = {};

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
  }

  @override
  void didUpdateWidget(SearchMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labours != widget.labours) {
      _loadCustomIcons();
    }
    // Re-frame when the area being searched changes, or when labours data updates.
    if (oldWidget.radiusKm != widget.radiusKm ||
        oldWidget.origin != widget.origin ||
        oldWidget.labours != widget.labours) {
      _fitRadius();
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  Future<void> _loadCustomIcons() async {
    for (final labour in widget.labours) {
      if (labour.skills.isNotEmpty) {
        final icon = labour.skills.first.emoji;
        final isSelected = labour.id == widget.selectedId;
        
        if (!_customIcons.containsKey(labour.id) || 
            (isSelected && !_customIcons.containsKey(-labour.id))) {
          final bitmap = await MarkerGenerator.createCustomMarkerBitmap(
            icon,
            selected: isSelected,
          );
          if (mounted) {
            setState(() {
              // Use negative ID for selected markers in cache to avoid collision
              _customIcons[isSelected ? -labour.id : labour.id] = bitmap;
            });
          }
        }
      }
    }
  }

  void _fitRadius() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final bounds = _calculateBounds();
    // Use a slightly larger padding for street level to ensure context
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  LatLngBounds _calculateBounds() {
    final radiusBounds = _radiusBounds();
    
    if (widget.labours.isEmpty) return radiusBounds;

    double? minLat, maxLat, minLng, maxLng;

    for (final labour in widget.labours) {
      if (labour.latitude != null && labour.longitude != null) {
        final lat = labour.latitude!;
        final lng = labour.longitude!;
        
        minLat = minLat == null ? lat : math.min(minLat, lat);
        maxLat = maxLat == null ? lat : math.max(maxLat, lat);
        minLng = minLng == null ? lng : math.min(minLng, lng);
        maxLng = maxLng == null ? lng : math.max(maxLng, lng);
      }
    }

    if (minLat == null) return radiusBounds;

    // Include the user's origin in the bounds too
    minLat = math.min(minLat, widget.origin.lat);
    maxLat = math.max(maxLat!, widget.origin.lat);
    minLng = math.min(minLng!, widget.origin.lng);
    maxLng = math.max(maxLng!, widget.origin.lng);

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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
    final Set<Marker> markers = {};

    // Labour markers from API
    for (final labour in widget.labours) {
      if (labour.latitude != null && labour.longitude != null) {
        final position = LatLng(labour.latitude!, labour.longitude!);
        final isSelected = labour.id == widget.selectedId;
        final icon = _customIcons[isSelected ? -labour.id : labour.id];

        markers.add(
          Marker(
            markerId: MarkerId('labour-${labour.id}'),
            position: position,
            icon: icon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  isSelected
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueYellow,
                ),
            zIndexInt: isSelected ? 10 : 5,
            infoWindow: InfoWindow(
              title: labour.name,
              snippet:
                  '₹${labour.dailyRate}${s.perDay} · ${labour.primarySkillIn(s)}',
              onTap: () => widget.onPinTap(labour),
            ),
          ),
        );
      }
    }
    return markers;
  }

  Set<Circle> get _circles => {
    Circle(
      circleId: const CircleId('radius'),
      center: widget.origin.toLatLng(),
      radius: widget.radiusKm * 1000,
      fillColor: AppColors.yellow.withValues(alpha: 0.1),
      strokeColor: AppColors.yellowDark.withValues(alpha: 0.4),
      strokeWidth: 1,
    ),
  };


  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.origin.toLatLng(),
        zoom: 18.0,
      ),
      markers: _markers,
      circles: _circles,
      padding: widget.padding,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      style: MapStyles.silver,
      cameraTargetBounds: CameraTargetBounds(_indiaBounds),
      minMaxZoomPreference: const MinMaxZoomPreference(0, 21),
      onMapCreated: (controller) {
        _controller = controller;
        // Small delay to ensure the map is ready for camera animation
        Future.delayed(const Duration(milliseconds: 300), _fitRadius);
      },
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    ),
  );
}
