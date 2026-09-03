import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/maps/map_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_map.dart';

/// The three points a booking has, on one small map: the job site, where the
/// worker was standing when they accepted, and where they are now.
///
/// Not a tracker — it does not poll, and it is deliberately not interactive.
/// Its job is the one question the live map cannot answer after the fact: *how
/// far away was he when he took this job?* The accept point survives on a
/// finished booking (it is a fact about the job); the live dot does not.
class BookingJourneyMap extends StatelessWidget {
  const BookingJourneyMap({super.key, required this.locations, this.onTap});

  final BookingLocations locations;

  /// Opens live tracking. Null on a booking with nothing left to follow.
  final VoidCallback? onTap;

  /// Every point that actually exists, in draw order.
  List<GeoPoint> get _points => [
    if (locations.site case final site?) site.point,
    if (locations.acceptedFrom case final origin?) origin.point,
    if (locations.live case final live?) live.point,
  ];

  Set<Marker> _markers(BuildContext context) {
    final s = context.s;

    return {
      if (locations.site case final site?)
        Marker(
          markerId: const MarkerId('site'),
          position: site.point.toLatLng(),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: s.siteOnMap),
        ),
      if (locations.acceptedFrom case final origin?)
        Marker(
          markerId: const MarkerId('accepted-from'),
          position: origin.point.toLatLng(),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(title: s.acceptedFromHere),
        ),
      if (locations.live case final live?)
        Marker(
          markerId: const MarkerId('live'),
          position: live.point.toLatLng(),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: live.isLive ? s.workerRightNow : s.workerLastSeen,
          ),
        ),
    };
  }

  /// A straight hint of the journey from the accept point to the site.
  ///
  /// Deliberately not a road route: this is a summary, and a Directions call per
  /// booking opened would be a network round trip for a decoration.
  Set<Polyline> get _polylines {
    final origin = locations.acceptedFrom;
    final site = locations.site;
    if (origin == null || site == null) return const {};

    return {
      Polyline(
        polylineId: const PolylineId('accepted-to-site'),
        points: [origin.point.toLatLng(), site.point.toLatLng()],
        color: AppColors.black.withValues(alpha: 0.35),
        width: 3,
        patterns: [PatternItem.dash(18), PatternItem.gap(10)],
      ),
    };
  }

  /// A centre and zoom that fit every point — the plugin cannot be handed
  /// bounds before its first frame, and this map never moves afterwards, so the
  /// span is worked out here instead of animating the camera.
  (GeoPoint, double) get _camera {
    final points = _points;
    if (points.isEmpty) return (const GeoPoint(0, 0), 12);
    if (points.length == 1) return (points.first, 14.5);

    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;

    for (final point in points.skip(1)) {
      minLat = point.lat < minLat ? point.lat : minLat;
      maxLat = point.lat > maxLat ? point.lat : maxLat;
      minLng = point.lng < minLng ? point.lng : minLng;
      maxLng = point.lng > maxLng ? point.lng : maxLng;
    }

    final centre = GeoPoint((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final span = [maxLat - minLat, maxLng - minLng].reduce((a, b) => a > b ? a : b);

    // Rough degrees-to-zoom ladder. Coarse on purpose: one step out is a map
    // with some slack round the pins, one step in cuts a pin off.
    final zoom = switch (span) {
      < 0.005 => 15.0,
      < 0.02 => 13.5,
      < 0.06 => 12.0,
      < 0.2 => 10.5,
      < 0.6 => 9.0,
      _ => 7.5,
    };

    return (centre, zoom);
  }

  @override
  Widget build(BuildContext context) {
    if (!locations.hasAny) return const SizedBox.shrink();

    final (centre, zoom) = _camera;

    final map = SizedBox(
      height: 170,
      width: double.infinity,
      child: KwMap(
        center: centre,
        zoom: zoom,
        markers: _markers(context),
        polylines: _polylines,
        interactive: false,
        style: MapStyles.silver,
        fallback: const _MapFallback(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: Radii.rSm,
          child: onTap == null
              ? map
              : Stack(
                  children: [
                    map,
                    // The whole map is the tap target, over the (non-interactive)
                    // plugin view rather than around it.
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(onTap: onTap),
                      ),
                    ),
                  ],
                ),
        ),
        Gap.vXl,
        ..._legend(context),
      ],
    );
  }

  /// One line per point, with what makes it worth showing: the address for the
  /// site, the distance for the other two, and how stale the live one is.
  List<Widget> _legend(BuildContext context) {
    final s = context.s;

    return [
      if (locations.site case final site?)
        _LegendRow(
          colour: const Color(0xFF4A90D9),
          label: s.siteOnMap,
          detail: site.address,
        ),
      if (locations.acceptedFrom case final origin?)
        _LegendRow(
          colour: const Color(0xFF8E5AD6),
          label: s.acceptedFromHere,
          detail: origin.distanceLabelIn(s),
        ),
      if (locations.live case final live?)
        _LegendRow(
          colour: const Color(0xFFE8833A),
          label: live.isLive ? s.workerRightNow : s.workerLastSeen,
          detail: [
            ?live.distanceLabelIn(s),
            // A dot that is not live looks parked rather than out of date, so
            // the line has to say which it is.
            if (!live.isLive) s.locationStale,
          ].join(' · '),
          warn: !live.isLive,
        ),
    ];
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.colour,
    required this.label,
    this.detail,
    this.warn = false,
  });

  final Color colour;
  final String label;
  final String? detail;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
          ),
          Gap.hLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppType.caption.copyWith(fontSize: 12.5)),
                if (detail case final detail? when detail.isNotEmpty)
                  Text(
                    detail,
                    style: AppType.micro.copyWith(
                      color: warn ? AppColors.danger : AppColors.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when no Maps key is configured. The legend underneath still carries
/// every fact the map would have, so nothing is actually lost here.
class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.mapWater,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 26, color: AppColors.muted),
          Gap.vSm,
          Text(
            context.s.mapsKeyMissing,
            style: AppType.micro.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
