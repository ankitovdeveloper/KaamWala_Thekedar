import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/animations/entrance.dart';
import '../../core/animations/pressable.dart';
import '../../core/async/loadable.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_map.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_scaffold.dart';

class LaboursMapScreen extends StatefulWidget {
  const LaboursMapScreen({super.key});

  @override
  State<LaboursMapScreen> createState() => _LaboursMapScreenState();
}

class _LaboursMapScreenState extends State<LaboursMapScreen> {
  late final Loadable<List<Labour>> _labours = Loadable(
    () => context.repo.allLaboursForSearch(),
  );

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _labours.addListener(_fitMarkers);
    _labours.load();
  }

  @override
  void dispose() {
    _labours.removeListener(_fitMarkers);
    _labours.dispose();
    super.dispose();
  }

  GeoPoint get _origin {
    final user = context.session.user;
    return GeoPoint(
      user?.latitude ?? ApiConfig.fallbackLat,
      user?.longitude ?? ApiConfig.fallbackLng,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMarkers();
  }

  void _fitMarkers() {
    final controller = _mapController;
    final labours = _labours.value;
    if (controller == null || labours == null || labours.isEmpty) return;

    final positions = labours
        .map((l) => l.latLng)
        .whereType<GeoPoint>()
        .followedBy([_origin])
        .map((p) => p.toLatLng())
        .toList();

    if (positions.isEmpty) return;

    if (positions.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(positions.first, 14));
      return;
    }

    var bounds = LatLngBounds(
      southwest: positions.first,
      northeast: positions.first,
    );

    for (final p in positions) {
      bounds = LatLngBounds(
        southwest: LatLng(
          p.latitude < bounds.southwest.latitude ? p.latitude : bounds.southwest.latitude,
          p.longitude < bounds.southwest.longitude ? p.longitude : bounds.southwest.longitude,
        ),
        northeast: LatLng(
          p.latitude > bounds.northeast.latitude ? p.latitude : bounds.northeast.latitude,
          p.longitude > bounds.northeast.longitude ? p.longitude : bounds.northeast.longitude,
        ),
      );
    }

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Set<Marker> _markers(List<Labour> labours) {
    final s = context.s;
    return {
      Marker(
        markerId: const MarkerId('origin'),
        position: _origin.toLatLng(),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: s.youAreHere),
        zIndexInt: 2,
      ),
      for (final labour in labours)
        if (labour.latLng case final position?)
          Marker(
            markerId: MarkerId('labour-${labour.id}'),
            position: position.toLatLng(),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            infoWindow: InfoWindow(
              title: labour.name,
              snippet: '₹${labour.dailyRate}${s.perDay} · ${labour.primarySkillIn(s)}',
              onTap: () => Navigator.of(context).pushNamed(
                Routes.labourDetail,
                arguments: labour,
              ),
            ),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return KwScaffold(
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _labours,
            builder: (context, _) {
              final rows = _labours.value ?? const [];
              
              if (_labours.isInitialLoad) {
                return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
              }

              if (_labours.error != null && rows.isEmpty) {
                return ApiErrorState(
                  error: _labours.error!,
                  onRetry: () => _labours.load(),
                );
              }

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _origin.toLatLng(),
                  zoom: 12,
                ),
                markers: _markers(rows),
                onMapCreated: _onMapCreated,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              );
            },
          ),

          // Header with back button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
                child: Row(
                  children: [
                    Pressable(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                    ),
                    Gap.hLg,
                    Text(
                      s.allLaboursMap,
                      style: AppType.h4.copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // "My Location" button
          Positioned(
            right: Gap.xl,
            bottom: Gap.x4l,
            child: FadeSlideIn(
              from: SlideFrom.bottom,
              child: Pressable(
                onTap: _fitMarkers,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.floatingShadow,
                  ),
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
