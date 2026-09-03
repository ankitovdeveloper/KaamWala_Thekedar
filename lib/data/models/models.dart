import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/i18n/app_strings.dart';
import '../api/api_client.dart';

/// Wire models for the Laravel API in `kaamwala_api` (`routes/api.php`, prefix
/// `v1`). Field names mirror the PHP models so a payload maps across without
/// a translation table.
///
/// Anything the user reads is produced by a `…In(AppStrings)` method rather
/// than a plain getter: these labels change with the chosen language, and the
/// data layer has no `BuildContext` to look one up from.

enum UserRole { labour, thekedar, superadmin }

/// `Booking::STATUS_*`
enum BookingStatus {
  pending,
  accepted,
  declined,
  completed,
  cancelled;

  static BookingStatus parse(String? v) => BookingStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => BookingStatus.pending,
  );
}

/// `Booking::STAGE_*` — forward-only progression.
enum JobStage {
  pending,
  onTheWay,
  working,
  completed;

  /// The wire value uses snake_case (`on_the_way`).
  String get wire => this == JobStage.onTheWay ? 'on_the_way' : name;

  static JobStage parse(String? v) => switch (v) {
    'on_the_way' => JobStage.onTheWay,
    'working' => JobStage.working,
    'completed' => JobStage.completed,
    _ => JobStage.pending,
  };

  String labelIn(AppStrings s) => switch (this) {
    JobStage.pending => s.stagePending,
    JobStage.onTheWay => s.stageOnTheWay,
    JobStage.working => s.stageWorking,
    JobStage.completed => s.stageCompleted,
  };
}

/// `Booking.day_type`
enum DayType {
  full,
  half;

  static DayType parse(String? v) => v == 'half' ? DayType.half : DayType.full;

  String labelIn(AppStrings s) =>
      this == DayType.full ? s.fullDayBooking : s.halfDayBooking;
}

/// Sort values accepted by `GET /thekedar/labour?sort=`.
enum LabourSort {
  distance('distance'),
  rating('rating'),
  priceLow('price_low'),
  priceHigh('price_high');

  const LabourSort(this.wire);
  final String wire;

  String labelIn(AppStrings s) => switch (this) {
    LabourSort.distance => s.sortDistance,
    LabourSort.rating => s.sortRating,
    LabourSort.priceLow => s.sortPriceLow,
    LabourSort.priceHigh => s.sortPriceHigh,
  };
}

/// Languages offered in Account Settings. `wire` is what `preferences.language`
/// stores — ISO codes where one exists; Hinglish has none, so it travels as the
/// `hi-en` pair.
enum AppLanguage {
  hindi('Hindi', 'hi'),
  english('English', 'en'),
  hinglish('Hinglish', 'hi-en'),
  bhojpuri('Bhojpuri', 'bho');

  const AppLanguage(this.label, this.wire);
  final String label;
  final String wire;

  static AppLanguage parse(String? v) => AppLanguage.values.firstWhere(
    (e) => e.wire == v,
    orElse: () => AppLanguage.hindi,
  );

  static String labelOf(String? v) => parse(v).label;
}

/// A latitude/longitude pair.
///
/// Deliberately free of any map SDK type: the data layer, the mock repository
/// and the widget tests all handle coordinates without pulling in
/// `google_maps_flutter`, which cannot render in a test harness.
@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  static GeoPoint? tryFrom(double? lat, double? lng) =>
      lat == null || lng == null ? null : GeoPoint(lat, lng);

  static GeoPoint? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : GeoPoint.tryFrom(
          json['latitude'] == null ? null : json.dbl('latitude'),
          json['longitude'] == null ? null : json.dbl('longitude'),
        );

  /// Great-circle distance in km — the same haversine the API sorts by.
  double distanceKmTo(GeoPoint other) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(other.lat - lat);
    final dLng = _radians(other.lng - lng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat)) *
            math.cos(_radians(other.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Straight-line interpolation. Over the few hundred metres one poll covers,
  /// the error against a great-circle path is not visible on screen.
  GeoPoint lerpTo(GeoPoint other, double t) =>
      GeoPoint(lat + (other.lat - lat) * t, lng + (other.lng - lng) * t);

  /// Compass bearing to [other] in degrees, used to rotate the moving marker.
  double bearingTo(GeoPoint other) {
    final dLng = _radians(other.lng - lng);
    final y = math.sin(dLng) * math.cos(_radians(other.lat));
    final x =
        math.cos(_radians(lat)) * math.sin(_radians(other.lat)) -
        math.sin(_radians(lat)) *
            math.cos(_radians(other.lat)) *
            math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() =>
      'GeoPoint(${lat.toStringAsFixed(5)}, '
      '${lng.toStringAsFixed(5)})';

  /// Bridges the SDK-free [GeoPoint] the data layer speaks to the plugin's type.
  LatLng toLatLng() => LatLng(lat, lng);
}

/// Turns a full name into the two-letter monogram every avatar uses.
String initialsOf(String name) {
  final parts = name.replaceAll('.', '').trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final single = parts.first;
    return (single.length == 1 ? single : single.substring(0, 2)).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

@immutable
class Skill {
  const Skill({required this.id, required this.name, this.icon});

  final int id;
  final String name;

  /// `skills.icon` in the DB. Usually an emoji; falls back to one derived from
  /// the name so the pills never render blank.
  final String? icon;

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json.intVal('id'),
    name: json.str('name'),
    icon: json.strOrNull('icon'),
  );

  String get emoji => icon ?? _emojiFor(name);

  String get label => '$emoji $name';

  static String _emojiFor(String name) => switch (name.toLowerCase()) {
    final n when n.contains('electric') => '⚡',
    final n when n.contains('wiring') => '🔌',
    final n when n.contains('plumb') => '🔧',
    final n when n.contains('pipe') => '💧',
    final n when n.contains('carpen') => '🪚',
    final n when n.contains('furnitur') => '🪑',
    final n when n.contains('paint') => '🎨',
    final n when n.contains('mason') || n.contains('chinai') => '🧱',
    final n when n.contains('weld') => '🔥',
    final n when n.contains('ac') => '💡',
    _ => '🛠️',
  };
}

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.countryCode = '+91',
    this.role = UserRole.thekedar,
    this.email,
    this.city,
    this.address,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.language = 'hi',
    this.notifyPush = true,
    this.notifyWhatsapp = true,
    this.notifySms = false,
    this.referralCode,
    this.isProfileComplete = false,
    this.profilePhotoUrl,
  });

  final int id;
  final String name;
  final String phone;
  final String countryCode;
  final UserRole role;
  final String? email;
  final String? city;
  final String? address;
  final double? latitude;
  final double? longitude;

  /// When [latitude]/[longitude] were last confirmed by the user
  /// (`users.location_updated_at`), which is what the app's periodic location
  /// prompt is timed off. Null on an older deploy that doesn't send the column —
  /// [Session] then falls back to its own locally stored stamp.
  final DateTime? locationUpdatedAt;
  final String language;
  final bool notifyPush;
  final bool notifyWhatsapp;
  final bool notifySms;
  final String? referralCode;
  final bool isProfileComplete;
  final String? profilePhotoUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json.intVal('id'),
    // A brand-new account has no name until the profile step is done.
    name: json.strOrNull('name') ?? 'Naya user',
    phone: json.str('phone'),
    countryCode: json.strOrNull('country_code') ?? '+91',
    role: switch (json.strOrNull('role')) {
      'labour' => UserRole.labour,
      'superadmin' => UserRole.superadmin,
      _ => UserRole.thekedar,
    },
    email: json.strOrNull('email'),
    city: json.strOrNull('city'),
    address: json.strOrNull('address'),
    latitude: json['latitude'] == null ? null : json.dbl('latitude'),
    longitude: json['longitude'] == null ? null : json.dbl('longitude'),
    locationUpdatedAt: json.date('location_updated_at'),
    language: json.strOrNull('language') ?? 'hi',
    notifyPush: json.flag('notify_push', true),
    notifyWhatsapp: json.flag('notify_whatsapp', true),
    notifySms: json.flag('notify_sms'),
    referralCode: json.strOrNull('referral_code'),
    isProfileComplete: json.flag('is_profile_complete'),
    profilePhotoUrl: json.strOrNull('profile_photo_url'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'country_code': countryCode,
    'role': role.name,
    'email': email,
    'city': city,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    // ISO so the cached copy reparses through the same path as the server's.
    'location_updated_at': locationUpdatedAt?.toIso8601String(),
    'language': language,
    'notify_push': notifyPush,
    'notify_whatsapp': notifyWhatsapp,
    'notify_sms': notifySms,
    'referral_code': referralCode,
    'is_profile_complete': isProfileComplete,
    // Included so the round trip through the session cache is lossless — a
    // cold start restored from prefs must not drop the avatar.
    'profile_photo_url': profilePhotoUrl,
  };

  String get fullPhone => '$countryCode $phone';
  String get initials => initialsOf(name);

  /// `language` is stored as a wire code; the settings row shows a label.
  String get languageLabel => AppLanguage.labelOf(language);

  AppUser copyWith({
    String? name,
    String? email,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? locationUpdatedAt,
    String? language,
    bool? notifyPush,
    bool? notifyWhatsapp,
    bool? notifySms,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    phone: phone,
    countryCode: countryCode,
    role: role,
    email: email ?? this.email,
    city: city ?? this.city,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
    language: language ?? this.language,
    notifyPush: notifyPush ?? this.notifyPush,
    notifyWhatsapp: notifyWhatsapp ?? this.notifyWhatsapp,
    notifySms: notifySms ?? this.notifySms,
    referralCode: referralCode,
    isProfileComplete: isProfileComplete,
    profilePhotoUrl: profilePhotoUrl,
  );
}

/// The trimmed labour shape embedded in a booking
/// (`labour:id,name,profile_photo`) — not enough for the detail screen, so it
/// stays a separate type rather than a half-populated [Labour].
@immutable
class LabourRef {
  const LabourRef({required this.id, required this.name, this.photoUrl});

  final int id;
  final String name;
  final String? photoUrl;

  factory LabourRef.fromJson(Map<String, dynamic> json) => LabourRef(
    id: json.intVal('id'),
    name: json.strOrNull('name') ?? 'Kaam wala',
    photoUrl:
        json.strOrNull('profile_photo_url') ?? json.strOrNull('profile_photo'),
  );

  String get initials => initialsOf(name);
}

/// `LabourProfile` joined with its `user` — the shape returned by
/// `GET /thekedar/labour` (list) and `/thekedar/labour/{id}` (detail).
@immutable
class Labour {
  const Labour({
    required this.id,
    required this.name,
    required this.dailyRate,
    required this.skills,
    required this.avgRating,
    required this.ratingsCount,
    required this.isOnDuty,
    this.totalJobs = 0,
    this.experienceYears = 0,
    this.city,
    this.address,
    this.distanceKm,
    this.bio,
    this.timing,
    this.reviews = const [],
    this.isSaved = false,
    this.contactUnlocked = false,
    this.phone,
    this.latitude,
    this.longitude,
    this.photoUrl,
  });

  final int id;
  final String name;
  final int dailyRate;
  final List<Skill> skills;
  final double avgRating;
  final int ratingsCount;
  final bool isOnDuty;
  final int totalJobs;
  final int experienceYears;
  final String? city;
  final String? address;

  /// Haversine distance from the search origin, in km. Null on the detail
  /// endpoint, which has no reference point.
  final double? distanceKm;
  final String? bio;

  /// Not exposed by the API yet — rendered only when present.
  final String? timing;
  final List<Review> reviews;
  final bool isSaved;

  /// The API hides the labour's phone until a booking exists.
  final bool contactUnlocked;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;

  factory Labour.fromJson(Map<String, dynamic> json) => Labour(
    id: json.intVal('id'),
    name: json.strOrNull('name') ?? 'Kaam wala',
    dailyRate: json.intVal('daily_rate'),
    skills: json.listOfMaps('skills').map(Skill.fromJson).toList(),
    avgRating: json.dbl('avg_rating'),
    ratingsCount: json.intVal('ratings_count'),
    isOnDuty: json.flag('is_on_duty'),
    totalJobs: json.intVal('total_jobs'),
    experienceYears: json.intVal('experience_years'),
    city: json.strOrNull('city'),
    address: json.strOrNull('address'),
    distanceKm: json['distance_km'] == null ? null : json.dbl('distance_km'),
    bio: json.strOrNull('bio'),
    reviews: json.listOfMaps('reviews').map(Review.fromJson).toList(),
    isSaved: json.flag('is_saved'),
    contactUnlocked: json.flag('contact_unlocked'),
    phone: json.strOrNull('phone'),
    latitude: json['latitude'] == null ? null : json.dbl('latitude'),
    longitude: json['longitude'] == null ? null : json.dbl('longitude'),
    photoUrl:
        json.strOrNull('profile_photo_url') ?? json.strOrNull('profile_photo'),
  );

  LabourRef get ref => LabourRef(id: id, name: name, photoUrl: photoUrl);

  String get initials => initialsOf(name);

  /// Null for a worker the API has no coordinates for — the map skips them.
  GeoPoint? get latLng => GeoPoint.tryFrom(latitude, longitude);

  String primarySkillIn(AppStrings s) =>
      skills.isEmpty ? s.labourGeneric : skills.first.name;

  String? distanceLabelIn(AppStrings s) => distanceKm == null
      ? null
      : distanceKm! < 1
      ? s.metresAway((distanceKm! * 1000).round())
      : s.kmAway(distanceKm!.toStringAsFixed(1));

  Labour copyWith({
    bool? isSaved,
    double? distanceKm,
  }) => Labour(
    id: id,
    name: name,
    dailyRate: dailyRate,
    skills: skills,
    avgRating: avgRating,
    ratingsCount: ratingsCount,
    isOnDuty: isOnDuty,
    totalJobs: totalJobs,
    experienceYears: experienceYears,
    city: city,
    address: address,
    distanceKm: distanceKm ?? this.distanceKm,
    bio: bio,
    timing: timing,
    reviews: reviews,
    isSaved: isSaved ?? this.isSaved,
    contactUnlocked: contactUnlocked,
    phone: phone,
    latitude: latitude,
    longitude: longitude,
    photoUrl: photoUrl,
  );
}

@immutable
class Review {
  const Review({
    required this.id,
    required this.reviewerName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  final int id;
  final String reviewerName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json.intVal('id'),
    // `with('thekedar:id,name')` nests the reviewer.
    reviewerName: json.mapOrNull('thekedar')?.strOrNull('name') ?? 'Thekedar',
    rating: json.intVal('rating'),
    comment: json.strOrNull('comment'),
    createdAt: json.date('created_at'),
  );
}

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.labour,
    required this.status,
    required this.jobStage,
    required this.price,
    this.skillName,
    this.workDate,
    this.startTime,
    this.dayType = DayType.full,
    this.address,
    this.city,
    this.notes,
    this.hasReview = false,
    this.labourPhone,
    this.site,
    this.completedBy,
    this.completionConfirmedAt,
    this.paymentStatus = 'pending',
    this.paymentMarkedAt,
    this.paymentConfirmedAt,
    this.completionResponse,
    this.completionRemark,
  });

  final int id;
  final LabourRef labour;
  final BookingStatus status;
  final JobStage jobStage;

  /// `agreed_price` once negotiated, else `offered_amount` — matching
  /// `Booking::finalAmount()`.
  final int price;
  final String? skillName;
  final DateTime? workDate;
  final String? startTime;
  final DayType dayType;
  final String? address;
  final String? city;
  final String? notes;
  final bool hasReview;
  final String? labourPhone;

  /// Where the job is. Tracking draws the worker moving towards this; null on
  /// bookings created before coordinates were captured.
  final GeoPoint? site;

  /// Who called the kaam finished — 'thekedar' or 'labour'. Null while it is
  /// still running.
  final String? completedBy;

  /// When the worker agreed that it really was finished. Null means this
  /// Thekedar's word is still the only one on the record.
  final DateTime? completionConfirmedAt;

  /// `pending` | `completed` | `refunded`, straight off the row.
  final String paymentStatus;

  /// When this Thekedar marked the money paid, and when the worker confirmed it
  /// arrived. Two facts, not one — which is the whole point of keeping both.
  final DateTime? paymentMarkedAt;
  final DateTime? paymentConfirmedAt;

  /// What the worker answered when asked to sign the job off: 'agreed',
  /// 'disputed', or null while they have not answered.
  ///
  /// A refusal is the answer this Thekedar most needs to see. Nothing else on
  /// the row says it — status and payment_status both still read as finished,
  /// because they record what *was declared*, not what was agreed.
  final String? completionResponse;

  /// The worker's own words alongside that answer. Always there on a refusal.
  final String? completionRemark;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final labourJson = json.mapOrNull('labour');
    final agreed = json['agreed_price'];

    return Booking(
      id: json.intVal('id'),
      labour: labourJson == null
          ? LabourRef(id: json.intVal('labour_id'), name: 'Kaam wala')
          : LabourRef.fromJson(labourJson),
      status: BookingStatus.parse(json.strOrNull('status')),
      jobStage: JobStage.parse(json.strOrNull('job_stage')),
      price: agreed == null || '$agreed'.isEmpty
          ? json.intVal('offered_amount')
          : json.intVal('agreed_price'),
      skillName: json.mapOrNull('skill')?.strOrNull('name'),
      // `work_date` has a `date` cast, so it serialises as a full ISO
      // timestamp; DateTime.tryParse handles both that and a bare 'Y-m-d'.
      workDate: json.date('work_date'),
      // MySQL TIME arrives as "09:00:00"; every screen shows "09:00".
      startTime: _clockTime(json.strOrNull('start_time')),
      dayType: DayType.parse(json.strOrNull('day_type')),
      address: json.strOrNull('address'),
      city: json.strOrNull('city'),
      notes: json.strOrNull('notes'),
      hasReview: json['review'] != null,
      labourPhone: labourJson?.strOrNull('phone'),
      site: GeoPoint.fromJson(json),
      completedBy: json.strOrNull('completed_by'),
      completionConfirmedAt: json.date('completion_confirmed_at'),
      paymentStatus: json.strOrNull('payment_status') ?? 'pending',
      paymentMarkedAt: json.date('payment_marked_at'),
      paymentConfirmedAt: json.date('payment_confirmed_at'),
      completionResponse: json.strOrNull('completion_response'),
      completionRemark: json.strOrNull('completion_remark'),
    );
  }

  static String? _clockTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  bool get isActive =>
      status == BookingStatus.accepted || status == BookingStatus.pending;
  bool get isDone => status == BookingStatus.completed;
  bool get isCancelled =>
      status == BookingStatus.cancelled || status == BookingStatus.declined;

  /// "19 June 2026 · 10:00 AM" — time is dropped once the job is history.
  String whenLabelIn(AppStrings s) {
    if (workDate == null) return startTime ?? '';
    final d = workDate!;
    final base = '${d.day} ${s.monthsLong[d.month - 1]} ${d.year}';
    if (isDone || startTime == null) return base;
    return '$base · ${_amPm(startTime!)}';
  }

  static String _amPm(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first);
    if (h == null) return hhmm;
    final minute = parts.length > 1 ? parts[1] : '00';
    final suffix = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$minute $suffix';
  }

  /// True once the worker has accepted and the job has not wrapped up — the
  /// window in which live tracking is worth polling for.
  bool get isTrackable =>
      status == BookingStatus.accepted && jobStage != JobStage.completed;

  /// True while this Thekedar could still call the kaam finished.
  bool get canComplete => status == BookingStatus.accepted;

  /// True once the money has been marked paid.
  bool get paymentDone => paymentStatus == 'completed';

  /// True while the payment is still owed on a job that is otherwise done —
  /// which is when the "Payment done" button belongs on the card.
  bool get canMarkPayment =>
      status == BookingStatus.completed && !paymentDone;

  /// True while the worker has not answered this Thekedar's "kaam poora hua aur
  /// payment bhi ho gaya". Worth saying on the card: it is the difference
  /// between one side having declared it and both sides agreeing.
  bool get awaitingLabourConfirm =>
      status == BookingStatus.completed &&
      completedBy == 'thekedar' &&
      completionResponse == null;

  /// The worker said no — the kaam or the money is contested. The loudest thing
  /// this card can say, and nothing else on the row says it.
  bool get completionDisputed => completionResponse == 'disputed';

  /// True once both sides say the kaam is finished — either because the worker
  /// agreed, or because they were the one who called it done.
  ///
  /// Neither is true of a booking closed before this handshake existed, which is
  /// why it is not simply `!awaitingLabourConfirm`: an old row should claim
  /// nothing rather than claim agreement nobody gave.
  bool get completionSettled =>
      completionResponse == 'agreed' || completedBy == 'labour';

  Booking copyWith({
    BookingStatus? status,
    JobStage? jobStage,
    bool? hasReview,
    String? completedBy,
    DateTime? completionConfirmedAt,
    String? paymentStatus,
    DateTime? paymentMarkedAt,
    DateTime? paymentConfirmedAt,
    String? completionResponse,
    String? completionRemark,
  }) => Booking(
    id: id,
    labour: labour,
    status: status ?? this.status,
    jobStage: jobStage ?? this.jobStage,
    price: price,
    skillName: skillName,
    workDate: workDate,
    startTime: startTime,
    dayType: dayType,
    address: address,
    city: city,
    notes: notes,
    hasReview: hasReview ?? this.hasReview,
    labourPhone: labourPhone,
    site: site,
    completedBy: completedBy ?? this.completedBy,
    completionConfirmedAt: completionConfirmedAt ?? this.completionConfirmedAt,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    paymentMarkedAt: paymentMarkedAt ?? this.paymentMarkedAt,
    paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
    completionResponse: completionResponse ?? this.completionResponse,
    completionRemark: completionRemark ?? this.completionRemark,
  );
}

/// Where one step of a booking's history stands — `App\Support\BookingStory`.
enum BookingStepState {
  /// It happened, and there is a time behind it.
  done,

  /// The one thing the booking is waiting on right now.
  current,

  /// Still ahead. The server only sends these on a booking that can still get
  /// there — a stopped job drops the steps it never reached rather than leaving
  /// them looking due.
  pending,

  /// A refusal, a dispute, a stop.
  failed;

  static BookingStepState parse(String? v) => switch (v) {
    'done' => done,
    'current' => current,
    'failed' => failed,
    _ => pending,
  };
}

/// Which step of the booking this is.
///
/// Parsed from the server's `code` rather than read off its `title`, because the
/// app renders these in four languages and the API speaks only Hinglish. An
/// unrecognised code — a step added to the backend after this build shipped —
/// falls back to [BookingStep.title], so a newer server can add steps without
/// the app dropping them on the floor.
enum BookingStepCode {
  requested,
  accepted,
  declined,
  onTheWay,
  arrived,
  workStarted,
  workDone,
  payment,
  labourConfirm,
  review,
  cancelled,
  terminated,
  unknown;

  static BookingStepCode parse(String? v) => switch (v) {
    'requested' => requested,
    'accepted' => accepted,
    'declined' => declined,
    'on_the_way' => onTheWay,
    'arrived' => arrived,
    'work_started' => workStarted,
    'work_done' => workDone,
    'payment' => payment,
    'labour_confirm' => labourConfirm,
    'review' => review,
    'cancelled' => cancelled,
    'terminated' => terminated,
    _ => unknown,
  };
}

/// One line of "is booking par kya kya hua".
@immutable
class BookingStep {
  const BookingStep({
    required this.code,
    required this.state,
    required this.title,
    this.note,
    this.at,
    this.actor,
  });

  final BookingStepCode code;
  final BookingStepState state;

  /// The server's own Hinglish wording. Only rendered for a [code] this build
  /// does not know — everything else is localised from the code.
  final String title;

  /// The detail under the step: an amount, a dispute remark, the reason a job
  /// was stopped. Free text the server owns, so it is shown as it arrives.
  final String? note;

  final DateTime? at;

  /// `thekedar` or `labour` — which side did it. Null on a step nobody has
  /// taken yet.
  final String? actor;

  factory BookingStep.fromJson(Map<String, dynamic> json) => BookingStep(
    code: BookingStepCode.parse(json.strOrNull('code')),
    state: BookingStepState.parse(json.strOrNull('state')),
    title: json.str('title'),
    note: json.strOrNull('note'),
    at: json.date('at'),
    actor: json.strOrNull('actor'),
  );

  bool get isDone => state == BookingStepState.done;
  bool get isCurrent => state == BookingStepState.current;
  bool get hasFailed => state == BookingStepState.failed;

  /// True once this step is behind the booking rather than ahead of it — what
  /// decides whether the timeline's connecting line is drawn filled.
  bool get isReached => isDone || hasFailed;

  bool get byLabour => actor == 'labour';

  /// The step's headline in the session's language.
  ///
  /// Several steps read differently depending on where they stand — "payment ho
  /// gaya" and "payment baaki hai" are the same step — so the state picks the
  /// wording, not just the icon. An unrecognised code falls back to the
  /// server's own [title], which is how a step added to the backend after this
  /// build shipped still says something.
  String titleIn(AppStrings s) => switch ((code, state)) {
    (BookingStepCode.requested, _) => s.storyRequested,
    (BookingStepCode.accepted, BookingStepState.done) => s.storyAccepted,
    (BookingStepCode.accepted, _) => s.storyWaitingAccept,
    (BookingStepCode.declined, _) => s.storyDeclined,
    (BookingStepCode.onTheWay, BookingStepState.done) => s.storyDeparted,
    (BookingStepCode.onTheWay, _) => s.storyWaitingDepart,
    (BookingStepCode.arrived, BookingStepState.done) => s.storyArrived,
    (BookingStepCode.arrived, _) => s.storyWaitingArrive,
    (BookingStepCode.workStarted, BookingStepState.done) => s.storyWorkStarted,
    // The only step that is an instruction rather than a report: nothing moves
    // until this Thekedar types the code the worker reads out.
    (BookingStepCode.workStarted, BookingStepState.current) =>
      s.storyWaitingCode,
    (BookingStepCode.workStarted, _) => s.storyWaitingStart,
    (BookingStepCode.workDone, BookingStepState.done) => s.storyWorkDone,
    (BookingStepCode.workDone, _) => s.storyWaitingDone,
    (BookingStepCode.payment, BookingStepState.done) => s.storyPaid,
    (BookingStepCode.payment, _) => s.storyWaitingPayment,
    (BookingStepCode.labourConfirm, BookingStepState.done) =>
      s.storyLabourAgreed,
    (BookingStepCode.labourConfirm, BookingStepState.failed) =>
      s.storyLabourDisputed,
    (BookingStepCode.labourConfirm, _) => s.storyWaitingLabourConfirm,
    (BookingStepCode.review, BookingStepState.done) => s.storyReviewed,
    (BookingStepCode.review, _) => s.storyWaitingReview,
    (BookingStepCode.cancelled, _) => s.storyCancelled,
    (BookingStepCode.terminated, _) => s.storyTerminated,
    (BookingStepCode.unknown, _) => title,
  };
}

/// One of the points a booking has on the map.
///
/// The same shape serves all three — the job site, where the worker was standing
/// when they accepted, and where they are now — because each is a coordinate
/// plus some subset of "when", "how far from the kaam" and "is this current".
@immutable
class BookingPlace {
  const BookingPlace({
    required this.point,
    this.at,
    this.distanceKm,
    this.isLive = true,
    this.address,
  });

  final GeoPoint point;

  /// When the worker was here. Null on the site (which does not move) and on a
  /// fallback position, where the honest answer is "not recently".
  final DateTime? at;

  /// Distance to the job site — the number that makes a point worth showing.
  final double? distanceKm;

  /// False when this is the worker's registered address standing in for a phone
  /// that has stopped reporting. A last known spot, not a live one.
  final bool isLive;

  final String? address;

  static BookingPlace? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final point = GeoPoint.fromJson(json);
    if (point == null) return null;

    return BookingPlace(
      point: point,
      at: json.date('at'),
      distanceKm: json['distance_km'] == null ? null : json.dbl('distance_km'),
      isLive: json['is_live'] == null || json.flag('is_live'),
      address: json.strOrNull('address'),
    );
  }

  /// '450 m door' / '2.4 km door' — null when there is nothing to measure to.
  String? distanceLabelIn(AppStrings s) => distanceKm == null
      ? null
      : distanceKm! < 1
      ? s.metresAway((distanceKm! * 1000).round())
      : s.kmAway(distanceKm!.toStringAsFixed(1));
}

/// The three points, together.
@immutable
class BookingLocations {
  const BookingLocations({this.site, this.acceptedFrom, this.live});

  /// Where the kaam is.
  final BookingPlace? site;

  /// Where the worker was when they took the job. Kept on a finished booking:
  /// it is a fact about the job, not a live position.
  final BookingPlace? acceptedFrom;

  /// Where they are now — served only while the job is still in flight. A
  /// booking from last month is not a licence to keep watching somebody.
  final BookingPlace? live;

  factory BookingLocations.fromJson(Map<String, dynamic> json) =>
      BookingLocations(
        site: BookingPlace.fromJson(json.mapOrNull('site')),
        acceptedFrom: BookingPlace.fromJson(json.mapOrNull('accepted_from')),
        live: BookingPlace.fromJson(json.mapOrNull('live')),
      );

  bool get hasAny => site != null || acceptedFrom != null || live != null;
}

/// The money on a booking, with both halves of the record kept apart: what this
/// Thekedar declared, and what the worker agreed to.
@immutable
class BookingPayment {
  const BookingPayment({
    required this.amount,
    this.status = 'pending',
    this.done = false,
    this.offeredAmount = 0,
    this.agreedPrice,
    this.markedAt,
    this.confirmedAt,
    this.awaitingLabourConfirm = false,
  });

  /// What is actually owed — the negotiated price where there is one.
  final int amount;
  final String status;
  final bool done;
  final int offeredAmount;
  final int? agreedPrice;

  /// When this Thekedar said the money was paid, and when the worker agreed it
  /// arrived. Two facts, which is the whole point of keeping both.
  final DateTime? markedAt;
  final DateTime? confirmedAt;

  final bool awaitingLabourConfirm;

  /// True when the price on the booking is not the price that was first offered
  /// — worth showing, because it is the number an argument starts from.
  bool get wasNegotiated => agreedPrice != null && agreedPrice != offeredAmount;

  factory BookingPayment.fromJson(Map<String, dynamic> json) => BookingPayment(
    amount: json.intVal('amount'),
    status: json.strOrNull('status') ?? 'pending',
    done: json.flag('done'),
    offeredAmount: json.intVal('offered_amount'),
    agreedPrice: json['agreed_price'] == null
        ? null
        : json.intVal('agreed_price'),
    markedAt: json.date('marked_at'),
    confirmedAt: json.date('confirmed_at'),
    awaitingLabourConfirm: json.flag('awaiting_labour_confirm'),
  );
}

/// How a booking stands, in one word.
enum BookingOutcomeKind {
  /// Still with the worker.
  waiting,

  /// Accepted and under way.
  running,

  /// Finished, and nobody is contesting it.
  completed,

  /// Finished, and the worker said no to it. `status` and `payment_status` both
  /// still read as done, because they record what was *declared*.
  disputed,

  /// Dropped before anybody set off.
  cancelled,

  /// Stopped part-way, with a reason.
  terminated,

  /// The worker turned it down.
  declined;

  static BookingOutcomeKind parse(String? v) => switch (v) {
    'running' => running,
    'completed' => completed,
    'disputed' => disputed,
    'cancelled' => cancelled,
    'terminated' => terminated,
    'declined' => declined,
    _ => waiting,
  };

  /// True for the outcomes that need saying loudly rather than filed away.
  bool get isBad =>
      this == disputed ||
      this == cancelled ||
      this == terminated ||
      this == declined;
}

/// What closed the booking, and what either side said about it.
@immutable
class BookingOutcome {
  const BookingOutcome({
    this.kind = BookingOutcomeKind.waiting,
    this.termination,
    this.cancelledBy,
    this.cancelledAt,
    this.cancellationReason,
    this.declinedAt,
    this.completedBy,
    this.completedAt,
    this.completionResponse,
    this.completionRemark,
    this.completionRespondedAt,
    this.workedMinutes,
  });

  final BookingOutcomeKind kind;

  /// Set only where somebody stopped the job part-way with a reason the other
  /// side is meant to read. A plain cancel has none.
  final JobTermination? termination;

  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? declinedAt;

  final String? completedBy;
  final DateTime? completedAt;

  /// `agreed` | `disputed` | null while the worker has not answered.
  final String? completionResponse;

  /// Their own words alongside that answer. Always there on a refusal.
  final String? completionRemark;
  final DateTime? completionRespondedAt;

  /// Minutes actually worked. Null when the work never began.
  final int? workedMinutes;

  factory BookingOutcome.fromJson(Map<String, dynamic> json) => BookingOutcome(
    kind: BookingOutcomeKind.parse(json.strOrNull('kind')),
    termination: switch (json.mapOrNull('termination')) {
      final t? => JobTermination.fromJson(t),
      _ => null,
    },
    cancelledBy: json.strOrNull('cancelled_by'),
    cancelledAt: json.date('cancelled_at'),
    cancellationReason: json.strOrNull('cancellation_reason'),
    declinedAt: json.date('declined_at'),
    completedBy: json.strOrNull('completed_by'),
    completedAt: json.date('completed_at'),
    completionResponse: json.strOrNull('completion_response'),
    completionRemark: json.strOrNull('completion_remark'),
    completionRespondedAt: json.date('completion_responded_at'),
    workedMinutes: json['worked_minutes'] == null
        ? null
        : json.intVal('worked_minutes'),
  );

  bool get cancelledByLabour => cancelledBy == 'labour';

  /// When this booking stopped being open, whichever way it ended.
  DateTime? get closedAt => cancelledAt ?? declinedAt ?? completedAt;
}

/// Which actions the detail screen may offer.
///
/// Decided by the server rather than re-derived here, so a button can never
/// appear on a booking the endpoint behind it would refuse — the two used to
/// drift, and the app found out by showing an error after the tap.
@immutable
class BookingActions {
  const BookingActions({
    this.cancel = false,
    this.track = false,
    this.confirmArrival = false,
    this.complete = false,
    this.markPayment = false,
    this.terminate = false,
    this.review = false,
  });

  final bool cancel;
  final bool track;
  final bool confirmArrival;
  final bool complete;
  final bool markPayment;
  final bool terminate;
  final bool review;

  factory BookingActions.fromJson(Map<String, dynamic> json) => BookingActions(
    cancel: json.flag('cancel'),
    track: json.flag('track'),
    confirmArrival: json.flag('confirm_arrival'),
    complete: json.flag('complete'),
    markPayment: json.flag('mark_payment'),
    terminate: json.flag('terminate'),
    review: json.flag('review'),
  );
}

/// `GET /thekedar/bookings/{id}` — one booking, whole.
///
/// The row's own fields sit at the top level of the payload, so [booking] is
/// parsed by the same code that reads "Meri Bookings"; everything else hangs off
/// it. `labour` is a superset of the trimmed [LabourRef] the list carries, which
/// is why the full [Labour] parses from the same key.
@immutable
class BookingDetail {
  const BookingDetail({
    required this.booking,
    required this.labour,
    required this.timeline,
    required this.locations,
    required this.payment,
    required this.outcome,
    required this.can,
  });

  final Booking booking;

  /// The worker's full record — rating, skills, jobs done, and the phone once
  /// the booking has unlocked it.
  final Labour labour;

  /// Oldest first.
  final List<BookingStep> timeline;

  final BookingLocations locations;
  final BookingPayment payment;
  final BookingOutcome outcome;
  final BookingActions can;

  factory BookingDetail.fromJson(Map<String, dynamic> json) => BookingDetail(
    booking: Booking.fromJson(json),
    labour: Labour.fromJson(json.mapOrNull('labour') ?? const {}),
    timeline: json
        .listOfMaps('timeline')
        .map(BookingStep.fromJson)
        .toList(growable: false),
    locations: BookingLocations.fromJson(
      json.mapOrNull('locations') ?? const {},
    ),
    payment: BookingPayment.fromJson(json.mapOrNull('payment') ?? const {}),
    outcome: BookingOutcome.fromJson(json.mapOrNull('outcome') ?? const {}),
    can: BookingActions.fromJson(json.mapOrNull('can') ?? const {}),
  );

  /// The step the booking is sitting on — what to say at the top of the screen.
  BookingStep? get currentStep =>
      timeline.where((step) => step.isCurrent).firstOrNull;

  /// The last thing that actually happened.
  BookingStep? get lastReachedStep =>
      timeline.where((step) => step.isReached).lastOrNull;
}

/// `GET /thekedar/bookings/{id}/track` — one poll of where the worker is.
///
/// Polled rather than pushed: a GET every few seconds needs no socket
/// infrastructure on the Laravel side, and the marker interpolates between
/// polls so the movement still reads as continuous.
@immutable
class TrackingUpdate {
  const TrackingUpdate({
    required this.stage,
    this.position,
    this.destination,
    this.etaMinutes,
    this.distanceKm,
    this.accepted = true,
    this.isLive = true,
    this.stageSource,
    this.arrivedAt,
    this.needsArrivalCode = false,
    this.arrivalConfirmedAt,
    this.canTerminate = false,
    this.termination,
    this.declined = false,
    this.declinedAt,
  });

  /// False while the request is still with the worker.
  final bool accepted;

  /// True once the worker has turned the request down. The other half of
  /// [accepted] being false: without it the screen cannot tell "still deciding"
  /// from "said no", and settles on waiting for ever.
  final bool declined;

  /// When they refused, so the card can say when rather than only that.
  final DateTime? declinedAt;

  final JobStage stage;

  /// Where the worker is right now, or null before they have accepted — the
  /// request is still out and there is no one to follow yet.
  final GeoPoint? position;

  /// The job site. Repeated on every poll so the map can draw the target
  /// without also holding the booking.
  final GeoPoint? destination;
  final int? etaMinutes;
  final double? distanceKm;

  /// False when the backend is serving the worker's registered address because
  /// their phone has stopped reporting. The marker is then a last known spot,
  /// not a live one, and saying so beats a dot that looks parked.
  final bool isLive;

  /// 'auto' when the stage was moved by the worker's GPS crossing a threshold,
  /// 'manual' when they tapped it, null when nothing has moved it yet.
  final String? stageSource;

  /// When the worker entered the site geofence, if they have.
  final DateTime? arrivedAt;

  /// True while the work is waiting on this Thekedar: mark the arrival and type
  /// the worker's four-digit code. Nothing else moves the job to Working.
  final bool needsArrivalCode;

  /// When that handshake happened.
  final DateTime? arrivalConfirmedAt;

  /// Whether the "stop this kaam" button belongs on the card.
  final bool canTerminate;

  /// Set once either side stopped the job part-way. Non-null is the signal to
  /// stop polling and show what happened — including when the *worker* ended it,
  /// which is otherwise just a dot that went still.
  final JobTermination? termination;

  bool get wasTerminated => termination != null;

  /// True when the timeline above was advanced by the tracker rather than by the
  /// worker — worth showing, because it means nobody had to remember to tap.
  bool get stageWasAutomatic => stageSource == 'auto';

  factory TrackingUpdate.fromJson(Map<String, dynamic> json) => TrackingUpdate(
    stage: JobStage.parse(json.strOrNull('job_stage')),
    position: GeoPoint.fromJson(json.mapOrNull('position')),
    destination: GeoPoint.fromJson(json.mapOrNull('destination')),
    etaMinutes: json['eta_minutes'] == null ? null : json.intVal('eta_minutes'),
    distanceKm: json['distance_km'] == null ? null : json.dbl('distance_km'),
    accepted: json.strOrNull('status') == 'accepted',
    // Absent on a pending booking (and on an older backend); assumed live so a
    // missing flag never puts a false warning on the card.
    isLive: json['is_live'] == null || json.flag('is_live'),
    stageSource: json.strOrNull('stage_source'),
    arrivedAt: json.date('arrived_at'),
    needsArrivalCode: json.flag('needs_arrival_code'),
    arrivalConfirmedAt: json.date('arrival_confirmed_at'),
    canTerminate: json.flag('can_terminate'),
    termination: switch (json.mapOrNull('termination')) {
      final t? => JobTermination.fromJson(t),
      _ => null,
    },
    declined: json.strOrNull('status') == 'declined',
    declinedAt: json.date('declined_at'),
  );

  /// "8 min door" / "Kaam shuru ho gaya" — the tracking card's headline.
  String etaLabelIn(AppStrings s) {
    if (declined) return s.requestRejected;
    if (!accepted) return s.waitingForAccept;
    if (stage == JobStage.working) return s.workStarted;
    if (stage == JobStage.completed) return s.workFinished;
    final eta = etaMinutes;
    if (eta == null) return s.onTheWay;
    return eta <= 1 ? s.almostThere : s.minutesAway(eta);
  }
}

/// One chip in the "stop this kaam" sheet
/// (`GET /thekedar/bookings/end-reasons`).
///
/// Served by the backend rather than hard-coded so a reworded reason needs no
/// release, and so the list cannot drift from what the API will accept.
@immutable
class EndReason {
  const EndReason({
    required this.code,
    required this.label,
    this.needsNote = false,
  });

  final String code;
  final String label;

  /// True for `other`: picking it and typing nothing would record nothing, so
  /// the sheet has to demand the note.
  final bool needsNote;

  factory EndReason.fromJson(Map<String, dynamic> json) => EndReason(
    code: json.str('code'),
    label: json.str('label'),
    needsNote: json.flag('needs_note'),
  );
}

/// Who stopped a job part-way.
enum EndedBy {
  labour,
  thekedar,
  unknown;

  static EndedBy parse(String? raw) => switch (raw) {
    'labour' => labour,
    'thekedar' => thekedar,
    _ => unknown,
  };
}

/// Why a job stopped part-way — shown to both sides.
///
/// A Thekedar whose worker walked off needs the worker's reason as much as the
/// worker needs theirs, so this rides on the tracking payload too.
@immutable
class JobTermination {
  const JobTermination({
    this.by = EndedBy.unknown,
    this.byLabel = '',
    this.reasonCode = '',
    this.reason = '',
    this.reasonLabel = '',
    this.at,
    this.stageWhenEnded = JobStage.pending,
    this.workedMinutes,
  });

  final EndedBy by;

  /// 'Kaam wale' / 'Thekedar' — the actor, phrased from nobody's point of view.
  /// Each screen puts "aapne" or "unhone" around it itself.
  final String byLabel;

  final String reasonCode;

  /// What is actually shown: the typed note when there was one, else the canned
  /// label for the code.
  final String reason;
  final String reasonLabel;

  final DateTime? at;

  /// Where the job had got to when it was stopped — the fact that decides
  /// whether anything is owed.
  final JobStage stageWhenEnded;

  /// Minutes actually worked before it stopped; null when work never began.
  final int? workedMinutes;

  bool get byLabour => by == EndedBy.labour;
  bool get byThekedar => by == EndedBy.thekedar;

  /// '2 ghante 15 min' — empty when nothing was worked.
  String get workedLabel {
    final mins = workedMinutes ?? 0;
    if (mins <= 0) return '';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h ghante';
    return '$h ghante $m min';
  }

  factory JobTermination.fromJson(Map<String, dynamic> json) => JobTermination(
    by: EndedBy.parse(json.strOrNull('by')),
    byLabel: json.str('by_label'),
    reasonCode: json.str('reason_code'),
    reason: json.str('reason'),
    reasonLabel: json.str('reason_label'),
    at: json.date('at'),
    stageWhenEnded: JobStage.parse(json.strOrNull('stage_when_ended')),
    workedMinutes: json['worked_minutes'] == null
        ? null
        : json.intVal('worked_minutes'),
  );
}

/// `GET|POST /thekedar/bookings/{id}/arrival` — the arrival handshake.
///
/// The worker carries a four-digit code for the booking. When they turn up, the
/// Thekedar types it here and that is what starts the kaam. Neither side can
/// declare the work started alone: GPS can put a phone at an address without the
/// worker being there, and a plain "Arrived" button could be tapped from
/// anywhere. The code is the proof that the two of them are standing together.
///
/// The code itself is never in this payload — the Thekedar has to be told it.
@immutable
class ArrivalState {
  const ArrivalState({
    required this.bookingId,
    required this.stage,
    this.needsCode = false,
    this.gpsArrived = false,
    this.locked = false,
    this.lockedForMinutes = 0,
    this.attemptsLeft = 0,
    this.arrivedAt,
    this.confirmedAt,
    this.startedAt,
  });

  final int bookingId;
  final JobStage stage;

  /// Whether there is still a code to type on this booking.
  final bool needsCode;

  /// Whether GPS has already put the worker on site. Advisory only — the code
  /// works either way, because GPS fails and the kaam cannot wait for it.
  final bool gpsArrived;

  /// True once wrong guesses have shut the entry for a while.
  final bool locked;
  final int lockedForMinutes;

  /// Guesses left before that happens.
  final int attemptsLeft;

  final DateTime? arrivedAt;
  final DateTime? confirmedAt;
  final DateTime? startedAt;

  bool get confirmed => confirmedAt != null || stage == JobStage.working;

  factory ArrivalState.fromJson(Map<String, dynamic> json) => ArrivalState(
    bookingId: json.intVal('booking_id'),
    stage: JobStage.parse(json.strOrNull('job_stage')),
    needsCode: json.flag('needs_code'),
    gpsArrived: json.flag('gps_arrived'),
    locked: json.flag('locked'),
    lockedForMinutes: json.intVal('locked_for_minutes'),
    attemptsLeft: json.intVal('attempts_left'),
    arrivedAt: json.date('arrived_at'),
    confirmedAt: json.date('arrival_confirmed_at'),
    startedAt: json.date('started_at'),
  );
}

/// `Address` — the labelled locations on the Profile screen.
@immutable
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.city,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String label;
  final String address;
  final String? city;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    id: json.intVal('id'),
    label: json.strOrNull('label') ?? 'Address',
    address: json.str('address'),
    city: json.strOrNull('city'),
    isDefault: json.flag('is_default'),
    latitude: json['latitude'] == null ? null : json.dbl('latitude'),
    longitude: json['longitude'] == null ? null : json.dbl('longitude'),
  );

  String get line =>
      city == null || city!.isEmpty ? address : '$address, $city';

  /// Picks a glyph from the label, since the API stores no icon.
  IconData get icon {
    final l = label.toLowerCase();
    if (l.contains('ghar') || l.contains('home')) return _home;
    if (l.contains('office') || l.contains('work')) return _office;
    return _pin;
  }

  static const _home = IconData(0xe318, fontFamily: 'MaterialIcons');
  static const _office = IconData(0xe7f0, fontFamily: 'MaterialIcons');
  static const _pin = IconData(0xe0c8, fontFamily: 'MaterialIcons');
}

/// `GET /thekedar/profile` → `stats`.
@immutable
class ThekedarStats {
  const ThekedarStats({
    this.totalBookings = 0,
    this.activeBookings = 0,
    this.totalSpend = 0,
    this.reviewsGiven = 0,
    this.savedLabours = 0,
  });

  final int totalBookings;
  final int activeBookings;
  final int totalSpend;
  final int reviewsGiven;
  final int savedLabours;

  factory ThekedarStats.fromJson(Map<String, dynamic> json) => ThekedarStats(
    totalBookings: json.intVal('total_bookings'),
    activeBookings: json.intVal('active_bookings'),
    totalSpend: json.intVal('total_spend'),
    reviewsGiven: json.intVal('reviews_given'),
    savedLabours: json.intVal('saved_labours'),
  );
}

/// `GET /thekedar/profile` — user + stats + addresses in one payload.
@immutable
class ProfileBundle {
  const ProfileBundle({
    required this.user,
    required this.stats,
    required this.addresses,
  });

  final AppUser user;
  final ThekedarStats stats;
  final List<SavedAddress> addresses;

  factory ProfileBundle.fromJson(Map<String, dynamic> json) => ProfileBundle(
    user: AppUser.fromJson(json.mapOrNull('user') ?? const {}),
    stats: ThekedarStats.fromJson(json.mapOrNull('stats') ?? const {}),
    addresses: json.listOfMaps('addresses').map(SavedAddress.fromJson).toList(),
  );
}

/// `GET /thekedar/account`.
@immutable
class AccountSettings {
  const AccountSettings({
    this.language = 'hi',
    this.notifyPush = true,
    this.notifyWhatsapp = true,
    this.notifySms = false,
    this.appVersion = '1.0.2',
  });

  final String language;
  final bool notifyPush;
  final bool notifyWhatsapp;
  final bool notifySms;
  final String appVersion;

  factory AccountSettings.fromJson(Map<String, dynamic> json) {
    final prefs = json.mapOrNull('preferences') ?? const <String, dynamic>{};
    return AccountSettings(
      language: prefs.strOrNull('language') ?? 'hi',
      notifyPush: prefs.flag('notify_push', true),
      notifyWhatsapp: prefs.flag('notify_whatsapp', true),
      notifySms: prefs.flag('notify_sms'),
      appVersion: json.strOrNull('app_version') ?? '1.0.2',
    );
  }

  String get languageLabel => AppLanguage.labelOf(language);

  AccountSettings copyWith({
    String? language,
    bool? notifyPush,
    bool? notifyWhatsapp,
    bool? notifySms,
  }) => AccountSettings(
    language: language ?? this.language,
    notifyPush: notifyPush ?? this.notifyPush,
    notifyWhatsapp: notifyWhatsapp ?? this.notifyWhatsapp,
    notifySms: notifySms ?? this.notifySms,
    appVersion: appVersion,
  );
}

/// `POST /auth/verify-otp`.
@immutable
class AuthResult {
  const AuthResult({
    required this.token,
    required this.user,
    this.isNewUser = false,
    this.isProfileComplete = false,
  });

  final String token;
  final AppUser user;
  final bool isNewUser;
  final bool isProfileComplete;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: json.str('token'),
    user: AppUser.fromJson(json.mapOrNull('user') ?? const {}),
    isNewUser: json.flag('is_new_user'),
    isProfileComplete: json.flag('is_profile_complete'),
  );
}

/// `POST /auth/send-otp` — the debug build echoes the code back.
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    this.countryCode = '+91',
    this.expiresIn = 300,
    this.resendIn = 30,
    this.debugCode,
  });

  final String phone;
  final String countryCode;
  final int expiresIn;
  final int resendIn;

  /// Present only when the server runs in debug / demo mode.
  final String? debugCode;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
    phone: json.str('phone'),
    countryCode: json.strOrNull('country_code') ?? '+91',
    expiresIn: json.intVal('expires_in', 300),
    resendIn: json.intVal('resend_in', 30),
    debugCode: json.strOrNull('otp'),
  );
}
