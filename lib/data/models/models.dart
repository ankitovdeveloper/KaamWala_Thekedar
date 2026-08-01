import 'package:flutter/widgets.dart';

import '../api/api_client.dart';

/// Wire models for the Laravel API in `RoziRoti` (`routes/api.php`, prefix
/// `v1`). Field names mirror the PHP models so a payload maps across without
/// a translation table.

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

  String get label => switch (this) {
    JobStage.pending => 'Pending',
    JobStage.onTheWay => 'Raaste mein',
    JobStage.working => 'Kaam chal raha',
    JobStage.completed => 'Poora hua',
  };
}

/// `Booking.day_type`
enum DayType {
  full,
  half;

  static DayType parse(String? v) => v == 'half' ? DayType.half : DayType.full;

  String get label =>
      this == DayType.full ? 'Full day booking' : 'Half day booking';
}

/// Sort values accepted by `GET /thekedar/labour?sort=`.
enum LabourSort {
  distance('Sabse paas', 'distance'),
  rating('Rating zyada', 'rating'),
  priceLow('Rate kam', 'price_low'),
  priceHigh('Rate zyada', 'price_high');

  const LabourSort(this.label, this.wire);
  final String label;
  final String wire;
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
  };

  String get fullPhone => '$countryCode $phone';
  String get initials => initialsOf(name);

  /// `language` is stored as an ISO code; the settings row shows a label.
  String get languageLabel => switch (language) {
    'en' => 'English',
    'pa' => 'Punjabi',
    _ => 'Hindi',
  };

  AppUser copyWith({
    String? name,
    String? email,
    String? city,
    String? address,
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
    latitude: latitude,
    longitude: longitude,
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

  String get primarySkill => skills.isEmpty ? 'Kaam wala' : skills.first.name;

  String? get distanceLabel => distanceKm == null
      ? null
      : distanceKm! < 1
      ? '${(distanceKm! * 1000).round()} m door'
      : '${distanceKm!.toStringAsFixed(1)} km door';

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
  String get whenLabel {
    if (workDate == null) return startTime ?? '';
    final d = workDate!;
    final base = '${d.day} ${_months[d.month - 1]} ${d.year}';
    if (isDone || startTime == null) return base;
    return '$base · ${_amPm(startTime!)}';
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _amPm(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first);
    if (h == null) return hhmm;
    final minute = parts.length > 1 ? parts[1] : '00';
    final suffix = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$minute $suffix';
  }

  Booking copyWith({BookingStatus? status, bool? hasReview}) => Booking(
    id: id,
    labour: labour,
    status: status ?? this.status,
    jobStage: jobStage,
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

  String get languageLabel => switch (language) {
    'en' => 'English',
    'pa' => 'Punjabi',
    _ => 'Hindi',
  };

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
