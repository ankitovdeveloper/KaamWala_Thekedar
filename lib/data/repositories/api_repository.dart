import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../models/models.dart';
import 'kaamwala_repository.dart';

/// Talks to the Laravel API. Every path here matches a line in
/// `RoziRoti/routes/api.php` under the `v1` prefix.
class ApiRepository implements KaamWalaRepository {
  ApiRepository(this._api);

  final ApiClient _api;

  static Map<String, dynamic> _obj(dynamic payload) =>
      payload is Map<String, dynamic> ? payload : const {};

  // ── Auth ──────────────────────────────────────────────────────────────────

  @override
  Future<OtpChallenge> sendOtp({
    required String phone,
    String countryCode = '+91',
  }) async {
    final data = await _api.post(
      'auth/send-otp',
      body: {
        'phone': phone,
        'country_code': countryCode,
        'role': ApiConfig.role,
      },
    );
    return OtpChallenge.fromJson(_obj(data));
  }

  @override
  Future<OtpChallenge> resendOtp({
    required String phone,
    String countryCode = '+91',
  }) async {
    final data = await _api.post(
      'auth/resend-otp',
      body: {
        'phone': phone,
        'country_code': countryCode,
        'role': ApiConfig.role,
      },
    );
    return OtpChallenge.fromJson(_obj(data));
  }

  @override
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    String countryCode = '+91',
  }) async {
    final data = await _api.post(
      'auth/verify-otp',
      body: {
        'phone': phone,
        'otp': otp,
        'country_code': countryCode,
        'role': ApiConfig.role,
      },
    );
    return AuthResult.fromJson(_obj(data));
  }

  @override
  Future<void> logout() => _api.post('auth/logout');

  @override
  Future<AppUser> me() async => AppUser.fromJson(_obj(await _api.get('me')));

  // ── Search & detail ───────────────────────────────────────────────────────

  @override
  Future<List<Labour>> searchLabours({
    required double lat,
    required double lng,
    int? skillId,
    String? query,
    int? radiusKm,
    LabourSort sort = LabourSort.distance,
  }) async {
    final data = await _api.get(
      'thekedar/labour',
      query: {
        'lat': lat,
        'lng': lng,
        'radius': radiusKm ?? ApiConfig.defaultRadiusKm,
        'sort': sort.wire,
        'skill_id': ?skillId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    dev.log('API RESPONSE: $data', name: 'SEARCH_DEBUG');

    // The endpoint paginates, so rows sit under `data.data`.
    return rowsOf(data).map(Labour.fromJson).toList();
  }

  @override
  Future<Labour> labourDetail(int id) async =>
      Labour.fromJson(_obj(await _api.get('thekedar/labour/$id')));

  @override
  Future<List<Labour>> allLaboursForSearch() async {
    final data = await _api.get('thekedar/all-labours-for-search');
    return rowsOf(data).map(Labour.fromJson).toList();
  }

  @override
  Future<List<Skill>> skills() async =>
      rowsOf(await _api.get('skills')).map(Skill.fromJson).toList();

  @override
  Future<bool> toggleSaved(int labourId) async {
    final data = await _api.post('thekedar/saved-labours/$labourId/toggle');
    return _obj(data).flag('is_saved');
  }

  // ── Bookings ──────────────────────────────────────────────────────────────

  @override
  Future<List<Booking>> bookings({String tab = 'all'}) async {
    final data = await _api.get('thekedar/bookings', query: {'tab': tab});
    return rowsOf(data).map(Booking.fromJson).toList();
  }

  @override
  Future<BookingDetail> bookingDetail(int bookingId) async =>
      BookingDetail.fromJson(
        _obj(await _api.get('thekedar/bookings/$bookingId')),
      );

  @override
  Future<Booking> createBooking({
    required int labourId,
    int? skillId,
    required DateTime workDate,
    String? startTime,
    required DayType dayType,
    required int offeredAmount,
    required String address,
    String? city,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final data = await _api.post(
      'thekedar/bookings',
      body: {
        'labour_id': labourId,
        'skill_id': ?skillId,
        // The server validates `date` + `after_or_equal:today`, so send a bare
        // Y-m-d in local time — an ISO timestamp in UTC can slip a day back.
        'work_date': _ymd(workDate),
        'start_time': ?startTime,
        'day_type': dayType.name,
        'duration_hours': dayType == DayType.full ? 8 : 4,
        'offered_amount': offeredAmount,
        'address': address,
        'city': ?city,
        'latitude': ?latitude,
        'longitude': ?longitude,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return Booking.fromJson(_obj(data));
  }

  @override
  Future<Booking> cancelBooking(int bookingId) async => Booking.fromJson(
    _obj(await _api.post('thekedar/bookings/$bookingId/cancel')),
  );

  @override
  Future<TrackingUpdate> trackBooking(int bookingId) async =>
      TrackingUpdate.fromJson(
        _obj(await _api.get('thekedar/bookings/$bookingId/track')),
      );

  @override
  Future<ArrivalState> arrivalState(int bookingId) async =>
      ArrivalState.fromJson(
        _obj(await _api.get('thekedar/bookings/$bookingId/arrival')),
      );

  @override
  Future<ArrivalState> confirmArrival(int bookingId, String code) async =>
      ArrivalState.fromJson(
        _obj(
          await _api.post(
            'thekedar/bookings/$bookingId/arrival',
            body: {'code': code},
          ),
        ),
      );

  @override
  Future<Booking> completeBooking(int bookingId) async => Booking.fromJson(
    _obj(await _api.post('thekedar/bookings/$bookingId/complete')),
  );

  @override
  Future<Booking> markPaymentDone(int bookingId) async => Booking.fromJson(
    _obj(await _api.post('thekedar/bookings/$bookingId/payment')),
  );

  @override
  Future<List<EndReason>> endReasons() async {
    final data = _obj(await _api.get('thekedar/bookings/end-reasons'));
    return data
        .listOfMaps('reasons')
        .map(EndReason.fromJson)
        .toList(growable: false);
  }

  @override
  Future<JobTermination?> terminateJob(
    int bookingId, {
    required String reasonCode,
    String note = '',
  }) async {
    final data = _obj(
      await _api.post(
        'thekedar/bookings/$bookingId/terminate',
        body: {
          'reason_code': reasonCode,
          if (note.trim().isNotEmpty) 'reason': note.trim(),
        },
      ),
    );

    return switch (data.mapOrNull('termination')) {
      final t? => JobTermination.fromJson(t),
      _ => null,
    };
  }

  @override
  Future<List<LatLng>> getRoutePolyline(
    LatLng origin,
    LatLng destination,
  ) async {
    // Migration to Google Routes API (New V2)
    final response = await _api.postRaw(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
      headers: {
        'X-Goog-Api-Key': ApiConfig.mapsApiKey,
        'X-Goog-FieldMask': 'routes.polyline',
      },
      body: {
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            }
          }
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            }
          }
        },
        'travelMode': 'DRIVE',
      },
    );

    final data = _obj(response);
    dev.log('ROUTES API FULL RESPONSE: $data', name: 'TRACKING_DEBUG');

    final routes = data['routes'] as List?;

    if (routes == null || routes.isEmpty) {
      dev.log('ROUTES API ERROR: ${data['error']?['message'] ?? 'No routes found'}',
          name: 'TRACKING_DEBUG');
      return [];
    }

    final encodedPolyline =
        (routes.first as Map)['polyline']?['encodedPolyline'] as String?;

    if (encodedPolyline == null) return [];

    final decoded = _decodePolyline(encodedPolyline);
    dev.log('ROUTES API: Fetched ${decoded.length} points',
        name: 'TRACKING_DEBUG');
    return decoded;
  }

  /// Decodes an encoded polyline string into a list of LatLng points.
  /// (Algorithm from Google Maps SDK)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  @override
  Future<void> reviewBooking({
    required int bookingId,
    required int rating,
    String? comment,
  }) => _api.post(
    'thekedar/bookings/$bookingId/review',
    body: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    },
  );

  // ── Profile & account ─────────────────────────────────────────────────────

  @override
  Future<ProfileBundle> profile() async =>
      ProfileBundle.fromJson(_obj(await _api.get('thekedar/profile')));

  @override
  Future<AppUser> updateProfile({
    String? name,
    String? email,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    // `sometimes` validation on the server: an omitted key is left alone,
    // while an explicit null clears the column. Only send what changed.
    final data = await _api.post(
      'thekedar/profile',
      body: {
        'name': ?name,
        'email': ?email,
        'city': ?city,
        'address': ?address,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
    return AppUser.fromJson(_obj(data));
  }

  @override
  Future<AppUser> updateProfilePhoto({
    required Uint8List bytes,
    required String filename,
  }) async {
    final data = await _api.postFile(
      'thekedar/profile/photo',
      field: 'photo',
      bytes: bytes,
      filename: filename,
    );
    return AppUser.fromJson(_obj(data));
  }

  @override
  Future<AppUser> removeProfilePhoto() async => AppUser.fromJson(
    _obj(await _api.delete('thekedar/profile/photo')),
  );

  @override
  Future<AccountSettings> account() async =>
      AccountSettings.fromJson(_obj(await _api.get('thekedar/account')));

  @override
  Future<AccountSettings> updatePreferences({
    String? language,
    bool? notifyPush,
    bool? notifyWhatsapp,
    bool? notifySms,
  }) async {
    // The endpoint returns only the preference fields, not the `preferences`
    // wrapper `GET /account` uses — re-wrap so one parser handles both.
    final data = _obj(
      await _api.put(
        'thekedar/account/preferences',
        // The endpoint uses `sometimes` validation, so omitted keys are left
        // untouched — only send what actually changed.
        body: {
          'language': ?language,
          'notify_push': ?notifyPush,
          'notify_whatsapp': ?notifyWhatsapp,
          'notify_sms': ?notifySms,
        },
      ),
    );
    return AccountSettings.fromJson({'preferences': data});
  }

  @override
  Future<List<SavedAddress>> addresses() async => rowsOf(
    await _api.get('thekedar/addresses'),
  ).map(SavedAddress.fromJson).toList();

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
