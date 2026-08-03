/// One-shot GPS fix, reverse-geocoded to something a person can read.
///
/// The location picker is the only caller: the user taps "use my current
/// location" and gets back coordinates plus, when the platform can manage it, a
/// street address and a city to prefill the text fields with.
///
/// Everything that can go wrong is funnelled into [LocationFailure] so the UI
/// has one message per cause instead of a raw plugin exception. A missing
/// address is *not* a failure — the coordinates are the part the search API
/// needs, and the user can always type the label themselves.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/models.dart';

/// A GPS fix, with whatever the reverse geocoder could make of it.
class DeviceLocation {
  const DeviceLocation({required this.point, this.address, this.city});

  final GeoPoint point;

  /// Street-level line, or null when reverse geocoding was unavailable or came
  /// back empty. Never contains [city].
  final String? address;
  final String? city;

  /// False when only coordinates came back, which the screen calls out so the
  /// user knows to fill the address in by hand.
  bool get hasLabel => address != null || city != null;
}

/// Why a fix could not be taken. Each value maps to one line of copy.
enum LocationFailure {
  /// The phone's location toggle is off — nothing to ask permission for yet.
  serviceOff,

  /// Declined this time; asking again is fine.
  denied,

  /// Declined permanently (or blocked by policy) — only app settings can undo
  /// it, so the plugin will not even show a prompt again.
  deniedForever,

  /// Timed out, no last-known position, or the platform has no implementation.
  unavailable,
}

class LocationException implements Exception {
  const LocationException(this.reason);

  final LocationFailure reason;

  @override
  String toString() => 'LocationException(${reason.name})';
}

abstract final class DeviceLocationService {
  /// How long to wait for a first fix before falling back to the last known
  /// one. Long enough for a cold GPS start indoors, short enough that the
  /// button does not look stuck.
  static const _fixTimeout = Duration(seconds: 15);

  /// Reverse geocoding is only implemented on Android and iOS. Elsewhere the
  /// plugin's platform factory is null and constructing [Geocoding] throws, so
  /// don't try — coordinates only is a valid result.
  static bool get _canReverseGeocode =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Asks for permission if needed, takes a fix, and resolves it to an address.
  ///
  /// Throws [LocationException] and nothing else.
  static Future<DeviceLocation> current() async {
    await _ensurePermission();
    final position = await _fix();
    final described = await _resolve(position);
    return DeviceLocation(
      point: GeoPoint(position.latitude, position.longitude),
      address: described?.address,
      city: described?.city,
    );
  }

  /// Opens the OS screen that can undo [reason], for the snackbar action.
  /// Returns false when there is no such screen for that reason.
  static Future<bool> openSettingsFor(LocationFailure reason) =>
      switch (reason) {
        LocationFailure.serviceOff => Geolocator.openLocationSettings(),
        LocationFailure.deniedForever => Geolocator.openAppSettings(),
        _ => Future.value(false),
      };

  static Future<void> _ensurePermission() async {
    // A permission grant is useless while the device's location switch is off,
    // and on Android the fix would simply hang, so check the service first.
    if (!await _guard(Geolocator.isLocationServiceEnabled)) {
      throw const LocationException(LocationFailure.serviceOff);
    }

    var permission = await _guard(Geolocator.checkPermission);
    if (permission == LocationPermission.denied) {
      permission = await _guard(Geolocator.requestPermission);
    }

    switch (permission) {
      case LocationPermission.deniedForever:
        throw const LocationException(LocationFailure.deniedForever);
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        throw const LocationException(LocationFailure.denied);
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return;
    }
  }

  static Future<Position> _fix() async {
    try {
      return await Geolocator.getCurrentPosition(
        // `high` rather than `best`: a few metres either way makes no
        // difference to a search radius measured in kilometres, and it settles
        // noticeably faster.
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
    } on Object {
      // A timeout indoors is the common case here. The last known position is
      // usually the same neighbourhood, which beats making the user start over.
      final last = await Geolocator.getLastKnownPosition().onError(
        (_, _) => null,
      );
      if (last == null) {
        throw const LocationException(LocationFailure.unavailable);
      }
      return last;
    }
  }

  /// Coordinates → address. Failure here is silent by design: the caller still
  /// has a usable point and the text fields are editable.
  static Future<({String? address, String? city})?> _resolve(
    Position position,
  ) async {
    if (!_canReverseGeocode) return null;

    try {
      final places = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isEmpty) return null;
      return describe(places.first);
    } on Object {
      return null;
    }
  }

  /// Squeezes a [Placemark] into the two fields the profile stores.
  ///
  /// The parts overlap heavily and inconsistently across platforms — Android
  /// often puts the whole first line in `street` while iOS splits it across
  /// `subThoroughfare`/`thoroughfare` — so segments are appended only when they
  /// add something the line does not already say.
  @visibleForTesting
  static ({String? address, String? city}) describe(Placemark place) {
    final city = _first([
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]);

    final line = <String>[];
    for (final part in [
      place.street,
      if ((place.street ?? '').isEmpty) place.subThoroughfare,
      if ((place.street ?? '').isEmpty) place.thoroughfare,
      place.subLocality,
      place.postalCode,
    ]) {
      final segment = part?.trim() ?? '';
      // Skip the city: it has its own field, and repeating it in the address
      // makes the header read "Gurgaon, Gurgaon".
      if (segment.isEmpty || _sameAs(segment, city)) continue;
      if (line.any((existing) => _contains(existing, segment))) continue;
      line.add(segment);
    }

    return (address: line.isEmpty ? null : line.join(', '), city: city);
  }

  static String? _first(List<String?> candidates) {
    for (final candidate in candidates) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static bool _sameAs(String a, String? b) =>
      b != null && a.toLowerCase() == b.toLowerCase();

  static bool _contains(String haystack, String needle) =>
      haystack.toLowerCase().contains(needle.toLowerCase());

  /// The permission calls throw `MissingPluginException` on platforms with no
  /// implementation (and in widget tests). Treat that as "cannot locate" rather
  /// than letting a raw plugin error reach the UI.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LocationException {
      rethrow;
    } on Object {
      throw const LocationException(LocationFailure.unavailable);
    }
  }
}
