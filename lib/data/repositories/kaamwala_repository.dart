import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';

/// Everything the Thekedar app asks of a backend.
///
/// Two implementations exist: `ApiRepository` talks to the Laravel server,
/// `MockRepository` serves the seeded design data so the UI can be demoed (and
/// widget-tested) with nothing running. Screens depend only on this interface.
abstract interface class KaamWalaRepository {
  // ── Auth ──────────────────────────────────────────────────────────────────

  /// `POST /auth/send-otp`
  Future<OtpChallenge> sendOtp({required String phone, String countryCode});

  /// `POST /auth/resend-otp`
  Future<OtpChallenge> resendOtp({required String phone, String countryCode});

  /// `POST /auth/verify-otp` — issues the Sanctum token.
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    String countryCode,
  });

  /// `POST /auth/logout`
  Future<void> logout();

  /// `GET /me` — used on cold start to validate a stored token.
  Future<AppUser> me();

  // ── Search & detail ───────────────────────────────────────────────────────

  /// `GET /thekedar/labour`
  Future<List<Labour>> searchLabours({
    required double lat,
    required double lng,
    int? skillId,
    String? query,
    int? radiusKm,
    LabourSort sort,
  });

  /// `GET /thekedar/labour/{id}`
  Future<Labour> labourDetail(int id);

  /// `GET /thekedar/all-labours-for-search`
  Future<List<Labour>> allLaboursForSearch();

  /// `GET /skills` — master list for the filter sheet.
  Future<List<Skill>> skills();

  /// `POST /thekedar/saved-labours/{id}/toggle`
  Future<bool> toggleSaved(int labourId);

  // ── Bookings ──────────────────────────────────────────────────────────────

  /// `GET /thekedar/bookings?tab=`
  Future<List<Booking>> bookings({String tab = 'all'});

  /// `POST /thekedar/bookings`
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
  });

  /// `POST /thekedar/bookings/{id}/cancel`
  Future<Booking> cancelBooking(int bookingId);

  /// `GET /thekedar/bookings/{id}/track` — one sample of the worker's
  /// position. Callers poll this; see `TrackingSession`.
  Future<TrackingUpdate> trackBooking(int bookingId);

  /// `GET /thekedar/bookings/{id}/arrival` — what the confirm sheet needs before
  /// it opens: whether a code is still owed, whether GPS has seen the worker
  /// arrive, and whether wrong guesses have locked the entry.
  Future<ArrivalState> arrivalState(int bookingId);

  /// `POST /thekedar/bookings/{id}/arrival` — mark the worker arrived by typing
  /// the four digits they read out. This is what moves the job to Working.
  ///
  /// Throws [ApiException] on a wrong or locked code, with a message meant to be
  /// shown as it is.
  Future<ArrivalState> confirmArrival(int bookingId, String code);

  /// `POST /thekedar/bookings/{id}/complete` — "the kaam is finished".
  ///
  /// The mirror of [confirmArrival]: starting the job took the worker's four
  /// digits, and finishing it is declared here and then confirmed by the worker
  /// from their own app. Until they do, it is one side's word.
  Future<Booking> completeBooking(int bookingId);

  /// `POST /thekedar/bookings/{id}/payment` — "the money is paid".
  ///
  /// Deliberately not folded into [completeBooking]: the kaam ending and the
  /// money changing hands are different events, often hours apart, and one
  /// button for both would record a payment that never happened. The backend
  /// only accepts it once the booking is completed.
  Future<Booking> markPaymentDone(int bookingId);

  /// `GET /thekedar/bookings/end-reasons` — the chips the "stop this kaam"
  /// sheet renders.
  Future<List<EndReason>> endReasons();

  /// `POST /thekedar/bookings/{id}/terminate` — stop a job part-way, with a
  /// reason the worker gets to read. [note] is required by the backend only for
  /// the `other` code.
  Future<JobTermination?> terminateJob(
    int bookingId, {
    required String reasonCode,
    String note,
  });

  /// Hits Google Directions API to get the road path between two points.
  Future<List<LatLng>> getRoutePolyline(LatLng origin, LatLng destination);

  /// `POST /thekedar/bookings/{id}/review`
  Future<void> reviewBooking({
    required int bookingId,
    required int rating,
    String? comment,
  });

  // ── Profile & account ─────────────────────────────────────────────────────

  /// `GET /thekedar/profile` — user, stats and addresses in one call.
  Future<ProfileBundle> profile();

  /// `POST /thekedar/profile` — every field is optional server-side, so this
  /// backs both the edit-profile form and the location picker, which sends
  /// only an address and a coordinate pair.
  Future<AppUser> updateProfile({
    String? name,
    String? email,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
  });

  /// `POST /thekedar/profile/photo` — multipart, field `photo`.
  ///
  /// Both photo calls answer with the whole user, not just the new URL, so the
  /// caller can hand the result straight to `Session.updateUser`.
  Future<AppUser> updateProfilePhoto({
    required Uint8List bytes,
    required String filename,
  });

  /// `DELETE /thekedar/profile/photo` — idempotent server-side.
  Future<AppUser> removeProfilePhoto();

  /// `GET /thekedar/account`
  Future<AccountSettings> account();

  /// `PUT /thekedar/account/preferences`
  Future<AccountSettings> updatePreferences({
    String? language,
    bool? notifyPush,
    bool? notifyWhatsapp,
    bool? notifySms,
  });

  /// `GET /thekedar/addresses`
  Future<List<SavedAddress>> addresses();
}
