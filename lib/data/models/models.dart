import 'dart:math' as math;

import 'package:flutter/widgets.dart';

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

  Labour copyWith({bool? isSaved}) => Labour(
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
    distanceKm: distanceKm,
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

  Booking copyWith({
    BookingStatus? status,
    JobStage? jobStage,
    bool? hasReview,
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
  );
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
  });

  /// False while the request is still with the worker.
  final bool accepted;

  final JobStage stage;

  /// Where the worker is right now, or null before they have accepted — the
  /// request is still out and there is no one to follow yet.
  final GeoPoint? position;

  /// The job site. Repeated on every poll so the map can draw the target
  /// without also holding the booking.
  final GeoPoint? destination;
  final int? etaMinutes;
  final double? distanceKm;

  factory TrackingUpdate.fromJson(Map<String, dynamic> json) => TrackingUpdate(
    stage: JobStage.parse(json.strOrNull('job_stage')),
    position: GeoPoint.fromJson(json.mapOrNull('position')),
    destination: GeoPoint.fromJson(json.mapOrNull('destination')),
    etaMinutes: json['eta_minutes'] == null ? null : json.intVal('eta_minutes'),
    distanceKm: json['distance_km'] == null ? null : json.dbl('distance_km'),
    accepted: json.strOrNull('status') == 'accepted',
  );

  /// "8 min door" / "Kaam shuru ho gaya" — the tracking card's headline.
  String etaLabelIn(AppStrings s) {
    if (!accepted) return s.waitingForAccept;
    if (stage == JobStage.working) return s.workStarted;
    if (stage == JobStage.completed) return s.workFinished;
    final eta = etaMinutes;
    if (eta == null) return s.onTheWay;
    return eta <= 1 ? s.almostThere : s.minutesAway(eta);
  }
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
