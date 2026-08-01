import '../api/api_exception.dart';
import '../mock_data.dart';
import '../models/models.dart';
import 'kaamwala_repository.dart';

/// Serves the seeded design data with a small artificial latency, so the app
/// can be demoed and widget-tested without the Laravel server.
///
/// Mutations are held in memory for the life of the instance — enough for
/// cancel / review / save to feel real in a demo.
class MockRepository implements KaamWalaRepository {
  MockRepository({this.latency = const Duration(milliseconds: 350)});

  /// Set to [Duration.zero] in tests so `pumpAndSettle` stays quick.
  final Duration latency;

  late List<Booking> _bookings = Mock.bookings();
  final Set<int> _saved = {};

  Future<T> _delayed<T>(T value) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return value;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  @override
  Future<OtpChallenge> sendOtp({
    required String phone,
    String countryCode = '+91',
  }) => _delayed(
    OtpChallenge(phone: phone, countryCode: countryCode, debugCode: '123456'),
  );

  @override
  Future<OtpChallenge> resendOtp({
    required String phone,
    String countryCode = '+91',
  }) => sendOtp(phone: phone, countryCode: countryCode);

  @override
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    String countryCode = '+91',
  }) async {
    await _delayed(null);
    // Mirrors the server's rejection path so the error UI is reachable offline.
    if (otp == '000000') {
      throw const ApiException('OTP galat hai.', statusCode: 422);
    }
    return AuthResult(
      token: 'mock-token',
      user: Mock.currentUser,
      isProfileComplete: true,
    );
  }

  @override
  Future<void> logout() => _delayed(null);

  @override
  Future<AppUser> me() => _delayed(Mock.currentUser);

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
    final q = (query ?? '').trim().toLowerCase();

    final results = Mock.labours.where((l) {
      if (skillId != null && !l.skills.any((s) => s.id == skillId)) {
        return false;
      }
      if (radiusKm != null && (l.distanceKm ?? 0) > radiusKm) return false;
      if (q.isEmpty) return true;
      final haystack =
          '${l.name} ${l.city ?? ''} ${l.skills.map((s) => s.name).join(' ')}'
              .toLowerCase();
      return haystack.contains(q);
    }).toList();

    results.sort(switch (sort) {
      LabourSort.distance => (a, b) => (a.distanceKm ?? 0).compareTo(
        b.distanceKm ?? 0,
      ),
      LabourSort.rating => (a, b) => b.avgRating.compareTo(a.avgRating),
      LabourSort.priceLow => (a, b) => a.dailyRate.compareTo(b.dailyRate),
      LabourSort.priceHigh => (a, b) => b.dailyRate.compareTo(a.dailyRate),
    });

    return _delayed(results);
  }

  @override
  Future<Labour> labourDetail(int id) {
    final labour = Mock.labourById(id);
    return _delayed(labour.copyWith(isSaved: _saved.contains(id)));
  }

  @override
  Future<List<Skill>> skills() => _delayed(Mock.allSkills);

  @override
  Future<bool> toggleSaved(int labourId) {
    final saved = !_saved.remove(labourId);
    if (saved) _saved.add(labourId);
    return _delayed(saved);
  }

  // ── Bookings ──────────────────────────────────────────────────────────────

  @override
  Future<List<Booking>> bookings({String tab = 'all'}) =>
      _delayed(switch (tab) {
        'active' =>
          _bookings.where((b) => b.status == BookingStatus.accepted).toList(),
        'pending' =>
          _bookings.where((b) => b.status == BookingStatus.pending).toList(),
        'done' => _bookings.where((b) => b.isDone).toList(),
        _ => List.of(_bookings),
      });

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
    final labour = Mock.labourById(labourId);
    final booking = Booking(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      labour: labour.ref,
      skillName: labour.primarySkill,
      workDate: workDate,
      startTime: startTime,
      dayType: dayType,
      price: offeredAmount,
      address: address,
      city: city,
      notes: notes,
      status: BookingStatus.pending,
      jobStage: JobStage.pending,
    );
    _bookings = [booking, ..._bookings];
    return _delayed(booking);
  }

  @override
  Future<Booking> cancelBooking(int bookingId) async {
    final updated = _bookings
        .firstWhere((b) => b.id == bookingId)
        .copyWith(status: BookingStatus.cancelled);
    _bookings = [
      for (final b in _bookings)
        if (b.id == bookingId) updated else b,
    ];
    return _delayed(updated);
  }

  @override
  Future<void> reviewBooking({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    _bookings = [
      for (final b in _bookings)
        if (b.id == bookingId) b.copyWith(hasReview: true) else b,
    ];
    return _delayed(null);
  }

  // ── Profile & account ─────────────────────────────────────────────────────

  @override
  Future<ProfileBundle> profile() {
    final done = _bookings.where((b) => b.isDone);
    return _delayed(
      ProfileBundle(
        user: Mock.currentUser,
        stats: ThekedarStats(
          totalBookings: _bookings.length,
          activeBookings: _bookings.where((b) => b.isActive).length,
          totalSpend: done.fold(0, (sum, b) => sum + b.price),
          reviewsGiven: _bookings.where((b) => b.hasReview).length,
          savedLabours: _saved.length,
        ),
        addresses: Mock.addresses,
      ),
    );
  }

  AccountSettings _settings = Mock.accountSettings;

  @override
  Future<AccountSettings> account() => _delayed(_settings);

  @override
  Future<AccountSettings> updatePreferences({
    String? language,
    bool? notifyPush,
    bool? notifyWhatsapp,
    bool? notifySms,
  }) {
    _settings = _settings.copyWith(
      language: language,
      notifyPush: notifyPush,
      notifyWhatsapp: notifyWhatsapp,
      notifySms: notifySms,
    );
    return _delayed(_settings);
  }

  @override
  Future<List<SavedAddress>> addresses() => _delayed(Mock.addresses);
}
