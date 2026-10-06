import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';
import '../models/reward_models.dart';

/// Everything the Thekedar app asks of a backend.
///
/// Two implementations exist: `ApiRepository` talks to the Laravel server,
/// `MockRepository` serves the seeded design data so the UI can be demoed (and
/// widget-tested) with nothing running. Screens depend only on this interface.
abstract interface class KaamWalaRepository {
  // ── Auth ──────────────────────────────────────────────────────────────────

  /// `POST /auth/send-otp`
  Future<OtpChallenge> sendOtp({required String phone, String countryCode});

  /// `POST /auth/register` — sign-up step one.
  ///
  /// Refuses a number that already has an account (422), which is the whole
  /// difference from [sendOtp]. The details in [draft] are only *validated*
  /// here; the account does not exist until [verifyOtp] proves the number, so
  /// the same draft has to be replayed on that call.
  Future<OtpChallenge> register({
    required SignupDraft draft,
    String countryCode,
  });

  /// `POST /auth/resend-otp`
  Future<OtpChallenge> resendOtp({required String phone, String countryCode});

  /// `POST /auth/verify-otp` — issues the Sanctum token.
  ///
  /// Pass [draft] for the sign-up flow: it sends `purpose=register` along with
  /// the details typed on the Register screen, which the server writes onto the
  /// account it creates. Omit it and this is an ordinary login.
  ///
  /// [termsVersion] is the wording the user ticked the box against on the
  /// login or register screen. The account does not exist until this call,
  /// so this is the only point at which that consent can be written down.
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    String countryCode,
    SignupDraft? draft,
    String? termsVersion,
    String? fcmToken,
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

  /// `GET /legal/{slug}?app=thekedar` — the Terms & Conditions or Privacy
  /// Policy the login and register screens link to.
  ///
  /// Never throws: a server that predates the endpoint, or no signal at all,
  /// yields [LegalDocument.bundled] rather than an error, because the sheet
  /// sits behind a tick box the user is being asked to agree to and showing
  /// them nothing there is worse than showing slightly stale wording.
  Future<LegalDocument> legalDocument(LegalDoc doc);

  /// `GET /skills` — master list for the filter sheet.
  Future<List<Skill>> skills();

  /// `POST /thekedar/saved-labours/{id}/toggle`
  Future<bool> toggleSaved(int labourId);

  // ── Bookings ──────────────────────────────────────────────────────────────

  /// `GET /thekedar/bookings?tab=`
  Future<List<Booking>> bookings({String tab = 'all'});

  /// `GET /thekedar/bookings/{id}` — one booking read back as a history: every
  /// step that happened and when, the worker's full record, the money, and the
  /// points on the map.
  ///
  /// Not a richer [bookings] row: the list answers "what have I got on", this
  /// answers "what happened on this one", and the second question needs the
  /// nine scattered timestamps walked in order. See `App\Support\BookingStory`.
  Future<BookingDetail> bookingDetail(int bookingId);

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
  ///
  /// This is the *Offline* side of the payment sheet — cash, hand to hand. The
  /// server records it as `cash` and refuses it when the worker asked to be
  /// paid online.
  Future<Booking> markPaymentDone(int bookingId);

  /// `POST /thekedar/bookings/{id}/payment/order` — opens a Razorpay order for
  /// the booking's amount, landing on the worker's [mode] (their UPI id, QR or
  /// bank account). Refused unless that destination is Razorpay-verified.
  Future<PaymentOrder> createPaymentOrder(
    int bookingId, {
    required OnlinePayMode mode,
  });

  /// `POST /thekedar/bookings/{id}/payment/verify` — hands Checkout's receipt
  /// to the server, whose signature check is what actually marks it paid.
  Future<void> verifyPayment(
    int bookingId, {
    required PaymentReceipt receipt,
    required OnlinePayMode mode,
  });

  /// `POST /thekedar/bookings/{id}/labour-payout/verify` — a fresh Razorpay
  /// check of the worker's payout details, right before paying. Returns the
  /// name Razorpay has on the account; throws [ApiException] when it fails.
  Future<String?> verifyLabourPayout(int bookingId);

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
    String? fcmToken,
  });

  /// `GET /thekedar/addresses`
  Future<List<SavedAddress>> addresses();

  // ── Rewards ───────────────────────────────────────────────────────────────

  /// `GET /rewards` — every campaign running for a Thekedar (Share & Earn,
  /// Successful Match) with progress, levels, steps and tips, plus the reward
  /// wallet. The path is shared with the Labour app; the server picks the
  /// campaigns from the user's role.
  Future<RewardsData> rewards();

  /// `GET /rewards/history` → the rewards this user has earned, keyed by id.
  ///
  /// Only garnish for the screen — the reject reason and the courier tracking
  /// number live here, not in [rewards] — so callers treat a failure as "no
  /// extra detail", never as an error.
  Future<Map<int, UserReward>> earnedRewards();

  /// `POST /rewards/{id}/claim` — delivery details for a physical reward.
  /// Throws [ApiException]: 422 when it was already claimed or a field is
  /// refused, 403 when the reward is not this user's.
  Future<void> claimReward(int userRewardId, ClaimDetails details);
}
