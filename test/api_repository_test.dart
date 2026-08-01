import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:kaamwala_thekedar/data/api/api_client.dart';
import 'package:kaamwala_thekedar/data/api/api_exception.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/api_repository.dart';

/// Records the last request and replays a canned response, so these tests
/// assert against the exact envelope shapes in `RoziRoti/app/Traits/ApiResponse`
/// and the payloads its Thekedar controllers build.
class _FakeClient extends http.BaseClient {
  _FakeClient(this.respond);

  final ({int status, Object body}) Function(http.BaseRequest request) respond;

  http.BaseRequest? lastRequest;
  String lastBody = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request) lastBody = request.body;

    final result = respond(request);
    final encoded = utf8.encode(
      result.body is String ? result.body as String : jsonEncode(result.body),
    );

    return http.StreamedResponse(
      Stream.value(encoded),
      result.status,
      headers: {'content-type': 'application/json'},
    );
  }
}

({ApiRepository repo, _FakeClient client}) _build(
  ({int status, Object body}) Function(http.BaseRequest request) respond,
) {
  final client = _FakeClient(respond);
  final api = ApiClient(
    client: client,
    baseUrl: 'http://127.0.0.1:8000/api/v1',
  );
  return (repo: ApiRepository(api), client: client);
}

Map<String, Object?> _ok(Object? data, [String message = 'Success']) => {
  'success': true,
  'message': message,
  'data': data,
};

void main() {
  group('Envelope', () {
    test('unwraps data and attaches the bearer token', () async {
      final (:repo, :client) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'id': 1,
            'name': 'Amit Khurana',
            'phone': '9876543210',
            'country_code': '+91',
            'role': 'thekedar',
            'city': 'Gurgaon',
            'notify_push': true,
            'notify_whatsapp': false,
          }),
        ),
      );

      final auth = await repo.verifyOtp(phone: '9876543210', otp: '123456');
      expect(auth.user, isA<AppUser>());

      // verify-otp is unauthenticated; sign the client and re-check.
      final api = ApiClient(client: client, baseUrl: 'http://x/api/v1')
        ..setToken('secret-token');
      await ApiRepository(api).me();
      expect(
        client.lastRequest!.headers['Authorization'],
        'Bearer secret-token',
      );
    });

    test('surfaces Laravel 422 validation errors per field', () async {
      final (:repo, client: _) = _build(
        (_) => (
          status: 422,
          body: {
            'success': false,
            'message': 'This number is already registered as labour.',
            'errors': {
              'role': ['Role mismatch for this phone number.'],
            },
          },
        ),
      );

      await expectLater(
        repo.sendOtp(phone: '9876543210'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isValidation, 'isValidation', isTrue)
              .having(
                (e) => e.fieldError('role'),
                'role error',
                'Role mismatch for this phone number.',
              ),
        ),
      );
    });

    test('maps 401 to an unauthorized error and fires the callback', () async {
      var notified = false;
      final client = _FakeClient(
        (_) => (
          status: 401,
          body: {'success': false, 'message': 'Unauthenticated.'},
        ),
      );
      final api = ApiClient(client: client, baseUrl: 'http://x/api/v1')
        ..onUnauthorized = () => notified = true;

      await expectLater(
        ApiRepository(api).me(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(notified, isTrue);
    });

    test('treats a non-JSON body (PHP fatal, HTML 404) as a parse error', () {
      final (:repo, client: _) = _build(
        (_) => (status: 500, body: '<b>Fatal error</b>'),
      );

      expect(
        repo.me(),
        throwsA(
          isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.parse),
        ),
      );
    });
  });

  group('Labour search', () {
    test('reads rows out of the paginator and maps every field', () async {
      final (:repo, :client) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'current_page': 1,
            'last_page': 1,
            'data': [
              {
                'id': 11,
                'name': 'Ramesh Kumar',
                'city': 'Sector 14, Gurgaon',
                'latitude': '28.4680',
                'longitude': '77.0290',
                'distance_km': 1.2,
                // MySQL hands decimals back as strings often enough to matter.
                'daily_rate': '450',
                'avg_rating': '4.80',
                'ratings_count': 142,
                'is_on_duty': 1,
                'experience_years': 8,
                'skills': [
                  {'id': 1, 'name': 'Electrician', 'icon': '⚡'},
                  {'id': 2, 'name': 'Wiring', 'icon': null},
                ],
              },
            ],
          }),
        ),
      );

      final rows = await repo.searchLabours(
        lat: 28.4595,
        lng: 77.0266,
        skillId: 1,
        query: 'ramesh',
        radiusKm: 5,
        sort: LabourSort.rating,
      );

      expect(rows, hasLength(1));
      final l = rows.single;
      expect(l.id, 11);
      expect(l.dailyRate, 450);
      expect(l.avgRating, 4.8);
      expect(l.isOnDuty, isTrue, reason: 'MySQL tinyint 1 means true');
      expect(l.distanceLabel, '1.2 km door');
      expect(l.skills.map((s) => s.name), ['Electrician', 'Wiring']);
      // A null icon falls back to one derived from the skill name.
      expect(l.skills.last.emoji, isNotEmpty);

      final query = client.lastRequest!.url.queryParameters;
      expect(query['lat'], '28.4595');
      expect(query['radius'], '5');
      expect(query['sort'], 'rating');
      expect(query['skill_id'], '1');
      expect(query['q'], 'ramesh');
    });

    test(
      'detail payload carries reviews, saved and contact-lock flags',
      () async {
        final (:repo, client: _) = _build(
          (_) => (
            status: 200,
            body: _ok({
              'id': 11,
              'name': 'Ramesh Kumar',
              'daily_rate': 450,
              'experience_years': 8,
              'avg_rating': 4.8,
              'ratings_count': 142,
              'total_jobs': 320,
              'is_on_duty': true,
              'bio': 'Electrical ka kaam.',
              'skills': [
                {'id': 1, 'name': 'Electrician', 'icon': '⚡'},
              ],
              'reviews': [
                {
                  'id': 1,
                  'rating': 5,
                  'comment': 'Bahut achha kaam kiya.',
                  'created_at': '2026-07-24T10:00:00.000000Z',
                  'thekedar': {'id': 2, 'name': 'Priya Sharma'},
                },
              ],
              'is_saved': true,
              'contact_unlocked': false,
            }),
          ),
        );

        final l = await repo.labourDetail(11);
        expect(l.totalJobs, 320);
        expect(l.isSaved, isTrue);
        expect(l.contactUnlocked, isFalse);
        expect(l.reviews.single.reviewerName, 'Priya Sharma');
        expect(l.reviews.single.createdAt, isNotNull);
        // No distance on the detail endpoint — there's no origin to measure from.
        expect(l.distanceKm, isNull);
      },
    );
  });

  group('Bookings', () {
    test(
      'parses the Booking model, preferring agreed over offered price',
      () async {
        final (:repo, :client) = _build(
          (_) => (
            status: 200,
            body: _ok({
              'data': [
                {
                  'id': 101,
                  'status': 'accepted',
                  'job_stage': 'on_the_way',
                  'offered_amount': 450,
                  'agreed_price': 500,
                  // The `date` cast serialises as a full ISO timestamp.
                  'work_date': '2026-08-02T00:00:00.000000Z',
                  // MySQL TIME comes back with seconds.
                  'start_time': '10:00:00',
                  'day_type': 'full',
                  'address': 'Sector 14, Gurgaon',
                  'labour': {'id': 11, 'name': 'Ramesh Kumar'},
                  'skill': {'id': 1, 'name': 'Electrician'},
                },
                {
                  'id': 102,
                  'status': 'pending',
                  'job_stage': 'pending',
                  'offered_amount': 190,
                  'agreed_price': null,
                  'work_date': '2026-08-03',
                  'start_time': '09:00:00',
                  'day_type': 'half',
                  'labour': {'id': 12, 'name': 'Suresh Yadav'},
                },
              ],
            }),
          ),
        );

        final rows = await repo.bookings(tab: 'active');
        expect(client.lastRequest!.url.queryParameters['tab'], 'active');

        final accepted = rows.first;
        expect(accepted.price, 500, reason: 'agreed_price wins');
        expect(accepted.jobStage, JobStage.onTheWay);
        expect(accepted.startTime, '10:00');
        expect(accepted.labour.name, 'Ramesh Kumar');
        expect(accepted.skillName, 'Electrician');
        expect(accepted.whenLabel, contains('10:00 AM'));

        final pending = rows.last;
        expect(pending.price, 190, reason: 'falls back to offered_amount');
        expect(pending.dayType, DayType.half);
        expect(pending.status, BookingStatus.pending);
      },
    );

    test('createBooking sends a bare Y-m-d work_date', () async {
      final (:repo, :client) = _build(
        (_) => (status: 201, body: _ok({'id': 999, 'status': 'pending'})),
      );

      await repo.createBooking(
        labourId: 11,
        skillId: 1,
        // Late in the day, so a naive UTC conversion would roll the date back.
        workDate: DateTime(2026, 8, 2, 23, 30),
        startTime: '09:00',
        dayType: DayType.full,
        offeredAmount: 450,
        address: 'Sector 14, Gurgaon',
      );

      final sent = jsonDecode(client.lastBody) as Map<String, dynamic>;
      expect(sent['work_date'], '2026-08-02');
      expect(sent['day_type'], 'full');
      expect(sent['duration_hours'], 8);
      expect(sent['offered_amount'], 450);
      expect(sent.containsKey('notes'), isFalse, reason: 'empty notes omitted');
    });
  });

  group('Profile & account', () {
    test('profile bundle splits user, stats and addresses', () async {
      final (:repo, client: _) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'user': {
              'id': 1,
              'name': 'Amit Khurana',
              'phone': '9876543210',
              'country_code': '+91',
              'role': 'thekedar',
            },
            'stats': {
              'total_bookings': 4,
              'active_bookings': 2,
              'total_spend': 1350,
              'reviews_given': 1,
              'saved_labours': 5,
            },
            'addresses': [
              {
                'id': 1,
                'label': 'Ghar',
                'address': 'Sector 14',
                'city': 'Gurgaon',
                'is_default': 1,
              },
            ],
          }),
        ),
      );

      final bundle = await repo.profile();
      expect(bundle.user.fullPhone, '+91 9876543210');
      expect(bundle.user.initials, 'AK');
      expect(bundle.stats.totalSpend, 1350);
      expect(bundle.addresses.single.line, 'Sector 14, Gurgaon');
      expect(bundle.addresses.single.isDefault, isTrue);
    });

    test('account reads the preferences wrapper', () async {
      final (:repo, client: _) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'preferences': {
              'language': 'en',
              'notify_push': true,
              'notify_whatsapp': false,
              'notify_sms': true,
            },
            'app_version': '1.0.2',
          }),
        ),
      );

      final settings = await repo.account();
      expect(settings.languageLabel, 'English');
      expect(settings.notifyWhatsapp, isFalse);
      expect(settings.notifySms, isTrue);
      expect(settings.appVersion, '1.0.2');
    });

    test(
      'updatePreferences sends only what changed and re-wraps the reply',
      () async {
        // PUT returns the bare preference fields, not the `preferences` wrapper.
        final (:repo, :client) = _build(
          (_) => (
            status: 200,
            body: _ok({
              'language': 'hi',
              'notify_push': false,
              'notify_whatsapp': true,
              'notify_sms': false,
            }),
          ),
        );

        final settings = await repo.updatePreferences(notifyPush: false);

        final sent = jsonDecode(client.lastBody) as Map<String, dynamic>;
        expect(sent.keys, ['notify_push']);
        expect(sent['notify_push'], isFalse);
        expect(settings.notifyPush, isFalse);
        expect(settings.notifyWhatsapp, isTrue);
      },
    );
  });

  group('Saved labours', () {
    test('toggle returns the new saved state', () async {
      final (:repo, :client) = _build(
        (_) => (status: 200, body: _ok({'is_saved': true})),
      );

      expect(await repo.toggleSaved(11), isTrue);
      expect(
        client.lastRequest!.url.path,
        '/api/v1/thekedar/saved-labours/11/toggle',
      );
    });
  });
}
