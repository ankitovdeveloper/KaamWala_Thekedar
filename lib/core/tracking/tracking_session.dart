import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/repositories/kaamwala_repository.dart';

/// Keeps one booking's live position fresh by polling
/// `GET /thekedar/bookings/{id}/track`.
///
/// Polling, not sockets: a GET every few seconds needs nothing extra on the
/// Laravel side. Smoothness is not this class's job — it publishes discrete
/// samples and the map tweens between [previous] and [latest], which is what
/// makes a 4-second poll read as continuous movement.
///
/// The loop stops on its own once the job reaches a terminal stage, so a
/// screen left open on a finished job isn't still hitting the server.
class TrackingSession extends ChangeNotifier {
  TrackingSession({
    required this.repository,
    required this.bookingId,
    this.interval = ApiConfig.trackingPollInterval,
  });

  final KaamWalaRepository repository;
  final int bookingId;
  final Duration interval;

  Timer? _timer;
  bool _disposed = false;
  bool _inFlight = false;

  TrackingUpdate? _latest;
  TrackingUpdate? _previous;
  List<LatLng> _routePoints = [];
  Object? _error;

  /// Most recent sample from the server.
  TrackingUpdate? get latest => _latest;

  /// The sample before it — the start point for the marker's tween.
  TrackingUpdate? get previous => _previous;

  /// The road-based polyline points between worker and destination.
  List<LatLng> get routePoints => _routePoints;

  Object? get error => _error;

  bool get hasFix => _latest != null;

  /// Only surfaced before the first successful poll; a later failure keeps the
  /// last known position on screen rather than blanking the map.
  Object? get fatalError => _latest == null ? _error : null;

  bool get isFinished => _latest?.stage == JobStage.completed;

  /// Fetches once immediately, then every [interval].
  void start() {
    if (_disposed || _timer != null) return;
    unawaited(_poll());
    _timer = Timer.periodic(interval, (_) => unawaited(_poll()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Pulls a sample now without disturbing the schedule — used by the
  /// pull-to-refresh on the tracking sheet.
  Future<void> refresh() => _poll();

  Future<void> _poll() async {
    // A slow response must not stack up behind the next tick.
    if (_disposed || _inFlight) return;
    _inFlight = true;

    try {
      final update = await repository.trackBooking(bookingId);
      if (_disposed) return;
      _previous = _latest;
      _latest = update;
      _error = null;

      // Fetch the road route if the worker is on the way.
      if (update.stage == JobStage.onTheWay &&
          update.position != null &&
          update.destination != null) {
        
        final posChanged = _previous?.position?.lat != update.position?.lat ||
            _previous?.position?.lng != update.position?.lng;
        final destChanged = _previous?.destination?.lat != update.destination?.lat ||
            _previous?.destination?.lng != update.destination?.lng;

        // Force fetch if route is empty OR if either position or destination has changed
        if (_routePoints.isEmpty || posChanged || destChanged) {
          _routePoints = await repository.getRoutePolyline(
            update.position!.toLatLng(),
            update.destination!.toLatLng(),
          );
        }
      } else {
        _routePoints = [];
      }

      if (update.stage == JobStage.completed) stop();
    } on Object catch (e) {
      if (_disposed) return;
      _error = e;
    } finally {
      _inFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
