import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:kaamwala_thekedar/core/i18n/app_strings.dart';
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
    // Multipart bodies are a byte stream, not a `body` string. Decoded loosely
    // so a test can assert on the part headers without the image bytes — which
    // are not valid UTF-8 — throwing.
    if (request is http.MultipartRequest) {
      lastBody = utf8.decode(
        await request.finalize().toBytes(),
        allowMalformed: true,
      );
    }

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
      expect(l.distanceLabelIn(AppStrings.hinglish), '1.2 km door');
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
        expect(
          accepted.whenLabelIn(AppStrings.hinglish),
          contains('10:00 AM'),
        );

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

    /// The payload below is a real response from
    /// `GET /thekedar/bookings/{id}`, trimmed to the keys the app reads. Kept
    /// verbatim rather than hand-rolled: the row's own fields sit at the top
    /// level next to the extra blocks, and the whole point of that shape is
    /// that one parser reads both.
    test('bookingDetail parses the row, the story and the worker', () async {
      final (:repo, :client) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'id': 7,
            'status': 'accepted',
            'job_stage': 'on_the_way',
            'stage_source': 'auto',
            'offered_amount': 800,
            'agreed_price': null,
            'work_date': '2026-09-03',
            'start_time': '09:00',
            'day_type': 'full',
            'address': 'Probe site, Indira Nagar',
            'city': 'Lucknow',
            'latitude': '26.8467000',
            'longitude': '80.9462000',
            'payment_status': 'pending',
            // Superset of the trimmed `labour` the list carries, so the same
            // key feeds both LabourRef and the full record.
            'labour': {
              'id': 3,
              'name': 'Ankit Test App',
              'phone': '9100000001',
              'contact_unlocked': true,
              'city': 'lucknow',
              'daily_rate': 300,
              'experience_years': 6,
              'avg_rating': 4.6,
              'ratings_count': 34,
              'total_jobs': 41,
              'is_on_duty': true,
              'bio': '6 saal ka tajurba.',
              'skills': [
                {'id': 1, 'name': 'Electrician', 'icon': '⚡'},
              ],
              'is_saved': false,
            },
            'skill': {'id': 1, 'name': 'Electrician', 'icon': '⚡'},
            'review': null,
            'timeline': [
              {
                'code': 'requested',
                'title': 'Booking bheji',
                'note': '₹800 · Poora din',
                'at': '2026-09-03T18:50:06+00:00',
                'state': 'done',
                'actor': 'thekedar',
              },
              {
                'code': 'on_the_way',
                'title': 'Kaam wala site ke liye nikla',
                'note': 'GPS se apne aap update hua',
                'at': '2026-09-03T18:20:06+00:00',
                'state': 'done',
                'actor': 'labour',
              },
              {
                'code': 'arrived',
                'title': 'Pahunchne ka intezaar',
                'note': null,
                'at': null,
                'state': 'current',
                'actor': 'labour',
              },
              // A step this build has no code for — must survive rather than
              // being dropped, so a newer backend needs no app release.
              {
                'code': 'something_new',
                'title': 'Kuch naya hua',
                'note': null,
                'at': null,
                'state': 'pending',
                'actor': null,
              },
            ],
            'locations': {
              'site': {
                'latitude': 26.8467,
                'longitude': 80.9462,
                'address': 'Probe site, Indira Nagar',
                'city': 'Lucknow',
              },
              'accepted_from': {
                'latitude': 26.86,
                'longitude': 80.95,
                'at': '2026-09-03T18:10:06+00:00',
                'distance_km': 1.5,
              },
              'live': {
                'latitude': 26.79,
                'longitude': 80.92,
                'at': null,
                'is_live': false,
                'stale_after_minutes': 5,
                'distance_km': 6.8,
              },
            },
            'payment': {
              'status': 'pending',
              'done': false,
              'amount': 800,
              'offered_amount': 800,
              'agreed_price': null,
              'marked_at': null,
              'confirmed_at': null,
              'awaiting_labour_confirm': false,
            },
            'outcome': {
              'kind': 'running',
              'termination': null,
              'worked_minutes': null,
            },
            'can': {
              'cancel': true,
              'track': true,
              'confirm_arrival': true,
              'complete': true,
              'mark_payment': false,
              'terminate': true,
              'review': false,
            },
          }),
        ),
      );

      final detail = await repo.bookingDetail(7);
      expect(client.lastRequest!.url.path, endsWith('/thekedar/bookings/7'));

      // The row, read by the same parser the list uses.
      expect(detail.booking.id, 7);
      expect(detail.booking.price, 800);
      expect(detail.booking.jobStage, JobStage.onTheWay);
      expect(detail.booking.site, isNotNull);

      // The worker, at full depth — and the phone the list never carries.
      expect(detail.labour.name, 'Ankit Test App');
      expect(detail.labour.phone, '9100000001');
      expect(detail.labour.totalJobs, 41);
      expect(detail.labour.skills.single.name, 'Electrician');

      expect(detail.timeline, hasLength(4));
      expect(detail.timeline.first.code, BookingStepCode.requested);
      expect(detail.timeline.first.isDone, isTrue);
      expect(
        detail.currentStep?.code,
        BookingStepCode.arrived,
        reason: 'the one step the booking is waiting on',
      );
      // Unknown code keeps the server's wording instead of vanishing.
      final unknown = detail.timeline.last;
      expect(unknown.code, BookingStepCode.unknown);
      expect(unknown.titleIn(AppStrings.hinglish), 'Kuch naya hua');

      expect(detail.locations.acceptedFrom!.distanceKm, 1.5);
      expect(
        detail.locations.live!.isLive,
        isFalse,
        reason: 'a last known spot, not a live one',
      );

      expect(detail.payment.amount, 800);
      expect(detail.payment.done, isFalse);
      expect(detail.outcome.kind, BookingOutcomeKind.running);
      expect(detail.can.confirmArrival, isTrue);
      expect(detail.can.markPayment, isFalse);
    });

    test('bookingDetail reads a disputed booking as contested', () async {
      final (:repo, client: _) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'id': 9,
            'status': 'completed',
            'job_stage': 'completed',
            'offered_amount': 700,
            'payment_status': 'completed',
            'labour': {'id': 3, 'name': 'Ankit Test App'},
            'timeline': [
              {
                'code': 'labour_confirm',
                'title': 'Kaam wale ne aapatti darj ki',
                'note': 'Poora paisa nahi mila',
                'at': '2026-09-03T18:44:00+00:00',
                'state': 'failed',
                'actor': 'labour',
              },
            ],
            'payment': {'amount': 700, 'done': true, 'status': 'completed'},
            'outcome': {
              'kind': 'disputed',
              'completion_response': 'disputed',
              'completion_remark': 'Poora paisa nahi mila',
            },
            'can': {'review': true},
          }),
        ),
      );

      final detail = await repo.bookingDetail(9);

      // Everything else on the row still reads as finished and paid, because
      // those columns record what was *declared*. Only these say nobody agreed.
      expect(detail.booking.isDone, isTrue);
      expect(detail.payment.done, isTrue);
      expect(detail.outcome.kind, BookingOutcomeKind.disputed);
      expect(detail.outcome.kind.isBad, isTrue);
      expect(detail.outcome.completionRemark, 'Poora paisa nahi mila');
      expect(detail.timeline.single.hasFailed, isTrue);
    });

    /// A stopped job is served with the steps it never reached left out, so
    /// nothing on the screen reads as still due.
    test('bookingDetail keeps a terminated job to what happened', () async {
      final (:repo, client: _) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'id': 11,
            'status': 'cancelled',
            'job_stage': 'working',
            'offered_amount': 700,
            'labour': {'id': 3, 'name': 'Ankit Test App'},
            'timeline': [
              {
                'code': 'requested',
                'title': 'Booking bheji',
                'at': '2026-09-03T10:00:00+00:00',
                'state': 'done',
                'actor': 'thekedar',
              },
              {
                'code': 'terminated',
                'title': 'Kaam wale ne kaam beech mein band kiya',
                'note': 'Tabiyat theek nahi hai · Band hone tak kaam: 2 ghante',
                'at': '2026-09-03T13:00:00+00:00',
                'state': 'failed',
                'actor': 'labour',
              },
            ],
            'locations': {'live': null},
            'payment': {'amount': 700},
            'outcome': {
              'kind': 'terminated',
              'termination': {
                'by': 'labour',
                'by_label': 'Kaam wale',
                'reason_code': 'health',
                'reason': 'Tabiyat theek nahi hai',
                'at': '2026-09-03T13:00:00+00:00',
                'stage_when_ended': 'working',
                'worked_minutes': 120,
              },
            },
            'can': <String, Object?>{},
          }),
        ),
      );

      final detail = await repo.bookingDetail(11);

      expect(
        detail.timeline.map((step) => step.code),
        [BookingStepCode.requested, BookingStepCode.terminated],
        reason: 'no "payment baaki" under a job that was stopped',
      );
      expect(detail.outcome.termination!.byLabour, isTrue);
      expect(detail.outcome.termination!.workedLabel, '2 ghante');
      expect(
        detail.locations.live,
        isNull,
        reason: 'a closed booking is not a licence to keep watching somebody',
      );
      // Nothing on offer, so the screen shows no action it cannot perform.
      expect(detail.can.cancel, isFalse);
      expect(detail.can.track, isFalse);
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

    test('updateProfile round-trips the address', () async {
      // `POST /thekedar/profile` answers with the bare user, not the bundle,
      // and `address` has to survive both legs: the location picker saves it,
      // and every screen that edits it prefills from the reply.
      final (:repo, :client) = _build(
        (_) => (
          status: 200,
          body: _ok({
            'id': 1,
            'name': 'Amit Khurana',
            'phone': '9876543210',
            'city': 'Gurugram',
            'address': 'Sushant Lok Phase 1, Gurugram',
            'latitude': '28.4600000',
            'longitude': '77.0900000',
          }, 'Profile updated.'),
        ),
      );

      final user = await repo.updateProfile(
        name: 'Amit Khurana',
        address: 'Sushant Lok Phase 1, Gurugram',
        city: 'Gurugram',
        latitude: 28.46,
        longitude: 77.09,
      );

      final sent = jsonDecode(client.lastBody) as Map<String, dynamic>;
      expect(sent['address'], 'Sushant Lok Phase 1, Gurugram');
      expect(user.address, 'Sushant Lok Phase 1, Gurugram');
      expect(user.latitude, 28.46);
    });

    test(
      'updateProfile sends an emptied address instead of omitting it',
      () async {
        // An omitted key means "leave the column alone" server-side, so a
        // cleared field has to travel as '' or the old address comes straight
        // back the next time the screen is opened.
        final (:repo, :client) = _build(
          (_) => (
            status: 200,
            body: _ok({
              'id': 1,
              'name': 'Amit Khurana',
              'phone': '9876543210',
              'city': 'Gurugram',
              'address': null,
            }, 'Profile updated.'),
          ),
        );

        final user = await repo.updateProfile(
          name: 'Amit Khurana',
          address: '',
        );

        final sent = jsonDecode(client.lastBody) as Map<String, dynamic>;
        expect(sent.containsKey('address'), isTrue);
        expect(sent['address'], '');
        expect(user.address, isNull);
      },
    );

    test(
      'updateProfilePhoto posts multipart and reads the user back',
      () async {
        const url =
            'http://localhost/RoziRoti/public/storage/profile-photos/abc.png';
        final (:repo, :client) = _build(
          (_) => (
            status: 200,
            body: _ok({
              'id': 1,
              'name': 'Amit Khurana',
              'phone': '9876543210',
              'profile_photo': 'profile-photos/abc.png',
              'profile_photo_url': url,
            }, 'Photo updated.'),
          ),
        );

        final user = await repo.updateProfilePhoto(
          bytes: Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
          filename: 'avatar.png',
        );

        final request = client.lastRequest!;
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/thekedar/profile/photo'));
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        // Laravel validates `photo`; a renamed field 422s with no clue why.
        expect(client.lastBody, contains('name="photo"'));
        expect(client.lastBody, contains('filename="avatar.png"'));
        expect(user.profilePhotoUrl, url);
      },
    );

    test(
      'removeProfilePhoto deletes and reads the cleared user back',
      () async {
        final (:repo, :client) = _build(
          (_) => (
            status: 200,
            body: _ok({
              'id': 1,
              'name': 'Amit Khurana',
              'phone': '9876543210',
              'profile_photo': null,
              'profile_photo_url': null,
            }, 'Photo removed.'),
          ),
        );

        final user = await repo.removeProfilePhoto();

        expect(client.lastRequest!.method, 'DELETE');
        expect(
          client.lastRequest!.url.path,
          endsWith('/thekedar/profile/photo'),
        );
        expect(user.profilePhotoUrl, isNull);
      },
    );

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
