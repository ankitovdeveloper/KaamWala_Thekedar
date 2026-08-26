import 'dart:typed_data';

import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  /// Live jobs, keyed by booking id. Everything about a tracked job is derived
  /// from its start time, so the simulation needs no timer of its own — each
  /// poll simply asks "how far along should this be by now?".
  final Map<int, _SimulatedJob> _jobs = {};

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
      user: _user,
      isProfileComplete: true,
    );
  }

  @override
  Future<void> logout() => _delayed(null);

  @override
  Future<AppUser> me() => _delayed(_user);

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
  Future<List<Labour>> allLaboursForSearch() => _delayed(Mock.labours);

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
  Future<List<Booking>> bookings({String tab = 'all'}) {
    _advanceSimulations();
    return _delayed(switch (tab) {
      'active' =>
        _bookings.where((b) => b.status == BookingStatus.accepted).toList(),
      'pending' =>
        _bookings.where((b) => b.status == BookingStatus.pending).toList(),
      'done' => _bookings.where((b) => b.isDone).toList(),
      _ => List.of(_bookings),
    });
  }

  /// Folds each simulated job's current state back onto its booking, so the
  /// list reflects an acceptance the moment it happens — the same way a real
  /// refetch would pick up the worker's response.
  void _advanceSimulations() {
    if (_jobs.isEmpty) return;
    _bookings = [
      for (final booking in _bookings)
        switch (_jobs[booking.id]) {
          final job? when job.hasAccepted => booking.copyWith(
            status: BookingStatus.accepted,
            jobStage: job.stage,
          ),
          _ => booking,
        },
    ];
  }

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
      // The API echoes back the skill's own name, so the mock reads it off the
      // record rather than through a language-dependent label.
      skillName: labour.skills.firstOrNull?.name,
      workDate: workDate,
      startTime: startTime,
      dayType: dayType,
      price: offeredAmount,
      address: address,
      city: city,
      notes: notes,
      status: BookingStatus.pending,
      jobStage: JobStage.pending,
      site: GeoPoint.tryFrom(latitude, longitude) ?? Mock.home,
    );
    _bookings = [booking, ..._bookings];

    // The request now sits with the worker. `_SimulatedJob` decides when they
    // accept it and walks them in from wherever they were on the map.
    _jobs[booking.id] = _SimulatedJob(
      origin: labour.latLng ?? Mock.home,
      destination: booking.site!,
    );
    return _delayed(booking);
  }

  @override
  Future<Booking> cancelBooking(int bookingId) async =>
      _patch(bookingId, (b) => b.copyWith(status: BookingStatus.cancelled));

  @override
  Future<Booking> completeBooking(int bookingId) async => _patch(
    bookingId,
    (b) => b.copyWith(
      status: BookingStatus.completed,
      jobStage: JobStage.completed,
      completedBy: 'thekedar',
    ),
  );

  @override
  Future<Booking> markPaymentDone(int bookingId) async => _patch(
    bookingId,
    (b) => b.copyWith(
      paymentStatus: 'completed',
      paymentMarkedAt: DateTime.now(),
    ),
  );

  /// Applies [change] to one row and hands back the updated copy — the mock's
  /// stand-in for the backend answering with the row it just wrote.
  Future<Booking> _patch(int bookingId, Booking Function(Booking) change) {
    final updated = change(_bookings.firstWhere((b) => b.id == bookingId));
    _bookings = [
      for (final b in _bookings)
        if (b.id == bookingId) updated else b,
    ];
    return _delayed(updated);
  }

  @override
  Future<TrackingUpdate> trackBooking(int bookingId) {
    final booking = _bookings.firstWhere(
      (b) => b.id == bookingId,
      orElse: () =>
          throw const ApiException('Ye booking nahi mili.', statusCode: 404),
    );

    // Bookings seeded as already-accepted have no simulation yet — start one
    // the first time they're tracked, so the demo works without booking afresh.
    final job = _jobs.putIfAbsent(
      bookingId,
      () => _SimulatedJob(
        origin: Mock.labourById(booking.labour.id).latLng ?? Mock.home,
        destination: booking.site ?? Mock.home,
        acceptAfter: Duration.zero,
      ),
    );

    _advanceSimulations();
    return _delayed(job.sample());
  }

  @override
  Future<ArrivalState> arrivalState(int bookingId) {
    final job = _jobs[bookingId];

    return _delayed(
      ArrivalState(
        bookingId: bookingId,
        stage: job?.stage ?? JobStage.pending,
        needsCode: job != null && job.hasAccepted && !job.arrivalConfirmed,
        gpsArrived: job?.gpsArrived ?? false,
        attemptsLeft: _SimulatedJob.maxAttempts - (job?.wrongAttempts ?? 0),
        arrivedAt: job?.arrivedAt,
        confirmedAt: job?.confirmedAt,
        startedAt: job?.confirmedAt,
      ),
    );
  }

  @override
  Future<ArrivalState> confirmArrival(int bookingId, String code) {
    final job = _jobs[bookingId];

    if (job == null) {
      throw const ApiException('Ye booking nahi mili.', statusCode: 404);
    }

    if (!job.arrivalConfirmed && !job.tryCode(code)) {
      final left = _SimulatedJob.maxAttempts - job.wrongAttempts;
      throw ApiException(
        left > 0
            ? 'Code galat hai. $left koshish bachi hai.'
            : 'Code galat hai. 10 minute ke liye band.',
        statusCode: 422,
      );
    }

    return arrivalState(bookingId);
  }

  @override
  Future<List<EndReason>> endReasons() => _delayed(const [
    EndReason(code: 'worker_absent', label: 'Kaam wala aaya hi nahi'),
    EndReason(code: 'worker_late', label: 'Bahut late ho gaya'),
    EndReason(code: 'work_quality', label: 'Kaam theek se nahi ho raha'),
    EndReason(code: 'not_needed', label: 'Ab is kaam ki zarurat nahi'),
    EndReason(code: 'rate_dispute', label: 'Rate par baat nahi bani'),
    EndReason(code: 'misbehaviour', label: 'Vyavhaar theek nahi tha'),
    EndReason(code: 'other', label: 'Koi aur wajah', needsNote: true),
  ]);

  @override
  Future<JobTermination?> terminateJob(
    int bookingId, {
    required String reasonCode,
    String note = '',
  }) {
    final job = _jobs[bookingId];

    if (job == null) {
      throw const ApiException('Ye booking nahi mili.', statusCode: 404);
    }

    job.terminate(reasonCode, note);

    _bookings = [
      for (final b in _bookings)
        if (b.id == bookingId)
          b.copyWith(status: BookingStatus.cancelled)
        else
          b,
    ];

    return _delayed(job.termination);
  }

  @override
  Future<List<LatLng>> getRoutePolyline(
    LatLng origin,
    LatLng destination,
  ) async {
    // The mock doesn't call Google; it just returns a straight line so the
    // polyline logic is exercised without needing an API key.
    return _delayed([origin, destination]);
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

  /// Mutable copy so edits made in a demo survive until the app restarts.
  AppUser _user = Mock.currentUser;

  @override
  Future<AppUser> updateProfile({
    String? name,
    String? email,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    _user = _user.copyWith(
      name: name,
      email: email,
      city: city,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    return _delayed(_user);
  }

  /// Both no-ops: there is no file store behind the mock, so a demo run has
  /// nowhere to put the bytes and no URL to serve them from. The avatar keeps
  /// showing its initials, which is what the seeded user has anyway.
  @override
  Future<AppUser> updateProfilePhoto({
    required Uint8List bytes,
    required String filename,
  }) => _delayed(_user);

  @override
  Future<AppUser> removeProfilePhoto() => _delayed(_user);

  @override
  Future<ProfileBundle> profile() {
    final done = _bookings.where((b) => b.isDone);
    return _delayed(
      ProfileBundle(
        user: _user,
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

/// One worker travelling to one job, played out against the wall clock.
///
/// Nothing here is scheduled: every value is a function of elapsed time, so
/// polling at any interval — or not polling for a while and coming back —
/// always yields a consistent state. The durations are demo-paced (a job that
/// would really take an hour plays out in about a minute) so the whole
/// request → accept → arrive → work flow can be watched end to end.
class _SimulatedJob {
  _SimulatedJob({
    required this.origin,
    required this.destination,
    this.acceptAfter = const Duration(seconds: 6),
  }) : _startedAt = DateTime.now();

  final GeoPoint origin;
  final GeoPoint destination;

  /// How long the worker "thinks about it" before accepting the request.
  final Duration acceptAfter;

  final DateTime _startedAt;

  static const _travel = Duration(seconds: 55);

  /// What the real trip would have taken — used to make the ETA count down
  /// through plausible minute values rather than the compressed demo seconds.
  static const _nominalTripMinutes = 14;

  Duration get _elapsed => DateTime.now().difference(_startedAt);

  bool get hasAccepted => _elapsed >= acceptAfter;

  /// 0 at the moment of acceptance, 1 on arrival.
  double get _progress {
    if (!hasAccepted) return 0;
    final travelled = _elapsed - acceptAfter;
    return (travelled.inMilliseconds / _travel.inMilliseconds).clamp(0.0, 1.0);
  }

  /// The code the demo accepts. The real backend mints a random one per booking
  /// and only ever shows it to the labour; in a Thekedar-only demo there is no
  /// labour app to read it off, so the mock uses a fixed one.
  static const demoCode = '1234';

  static const maxAttempts = 5;

  int wrongAttempts = 0;
  DateTime? confirmedAt;

  /// Set once the demo stops the job part-way.
  JobTermination? termination;

  void terminate(String reasonCode, String note) {
    termination = JobTermination(
      by: EndedBy.thekedar,
      byLabel: 'Thekedar',
      reasonCode: reasonCode,
      reason: note.trim().isEmpty ? reasonCode : note.trim(),
      reasonLabel: reasonCode,
      at: DateTime.now(),
      stageWhenEnded: stage,
      workedMinutes: confirmedAt == null
          ? null
          : DateTime.now().difference(confirmedAt!).inMinutes,
    );
  }

  /// GPS has put the worker on the site. Not the same as the work having
  /// started — that waits for [tryCode].
  bool get gpsArrived => _progress >= 1;

  DateTime? get arrivedAt =>
      gpsArrived ? _startedAt.add(acceptAfter + _travel) : null;

  bool get arrivalConfirmed => confirmedAt != null;

  /// Returns false on a wrong code, counting the attempt.
  bool tryCode(String code) {
    if (code.trim() != demoCode) {
      wrongAttempts++;
      return false;
    }
    confirmedAt = DateTime.now();
    return true;
  }

  JobStage get stage {
    if (!hasAccepted) return JobStage.pending;
    // Reaching the site is NOT what starts the kaam — the Thekedar typing the
    // worker's code is, which is why arrival parks the job on `onTheWay`.
    return arrivalConfirmed ? JobStage.working : JobStage.onTheWay;
  }

  TrackingUpdate sample() {
    // Before acceptance there is deliberately no position: the request is still
    // sitting with the worker, and showing a dot would imply they're moving.
    if (!hasAccepted) {
      return TrackingUpdate(
        stage: JobStage.pending,
        destination: destination,
        accepted: false,
      );
    }

    final position = origin.lerpTo(destination, _progress);

    return TrackingUpdate(
      stage: stage,
      position: position,
      destination: destination,
      distanceKm: position.distanceKmTo(destination),
      etaMinutes: stage == JobStage.onTheWay && !gpsArrived
          ? ((1 - _progress) * _nominalTripMinutes).ceil()
          : 0,
      arrivedAt: arrivedAt,
      arrivalConfirmedAt: confirmedAt,
      needsArrivalCode: termination == null && !arrivalConfirmed,
      stageSource: arrivalConfirmed ? 'code' : 'auto',
      canTerminate: termination == null,
      termination: termination,
    );
  }
}
