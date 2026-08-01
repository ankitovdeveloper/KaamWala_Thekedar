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
