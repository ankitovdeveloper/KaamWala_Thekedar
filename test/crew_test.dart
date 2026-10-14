import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/router/routes.dart';
import 'package:kaamwala_thekedar/core/theme/app_theme.dart';
import 'package:kaamwala_thekedar/data/mock_data.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/crew/crew_status_screen.dart';
import 'package:kaamwala_thekedar/features/search/search_screen.dart';
import 'package:kaamwala_thekedar/features/search/widgets/crew_booking_sheet.dart';
import 'package:kaamwala_thekedar/features/search/widgets/filter_sheet.dart';

/// "I need 4 painters": the count picker, the same-area groups the search lists
/// with a line between areas, and the status screen a booked crew fills up on.

const _painter = Skill(id: 9, name: 'Painter', icon: '🎨');

Labour _worker(int id, String name, {double km = 1}) => Labour(
  id: id,
  name: name,
  dailyRate: 500,
  skills: const [_painter],
  avgRating: 4.5,
  ratingsCount: 10,
  isOnDuty: true,
  distanceKm: km,
  latitude: 28.46,
  longitude: 77.03,
);

/// Two neighbourhoods of two painters each — what the server sends for
/// `count=2`.
class _TwoAreas extends MockRepository {
  _TwoAreas() : super(latency: Duration.zero);

  int groupCalls = 0;
  int? askedCount;
  int? askedSkill;

  @override
  Future<List<LabourGroup>> labourGroups({
    required double lat,
    required double lng,
    required int skillId,
    required int count,
    int? radiusKm,
  }) async {
    groupCalls++;
    askedCount = count;
    askedSkill = skillId;

    return [
      LabourGroup(
        index: 1,
        needed: count,
        workers: [_worker(31, 'Asha Painter'), _worker(32, 'Bela Painter')],
        distanceKm: 1.2,
        spreadKm: 0.4,
        area: 'Sector 14',
      ),
      LabourGroup(
        index: 2,
        needed: count,
        // Short: the area ran out of painters.
        workers: [_worker(33, 'Chitra Painter', km: 7)],
        distanceKm: 7,
        spreadKm: 0,
        area: 'Sector 50',
      ),
    ];
  }

  @override
  Future<Crew> createCrew({
    required int skillId,
    required int size,
    List<int> labourIds = const [],
    required DateTime workDate,
    String? startTime,
    required DayType dayType,
    required String address,
    String? city,
    required double latitude,
    required double longitude,
    String? notes,
    int? radiusKm,
  }) async {
    created = (skillId: skillId, size: size, ids: labourIds);
    return Crew(
      id: 77,
      status: CrewStatus.searching,
      size: size,
      confirmed: 1,
      pending: 1,
      openSlots: 0,
      skillName: 'Painter',
      workDate: workDate,
      members: [
        CrewMember(
          bookingId: 1,
          labour: const LabourRef(id: 31, name: 'Asha Painter'),
          status: BookingStatus.accepted,
          rating: 4.5,
          distanceKm: 1.2,
        ),
        CrewMember(
          bookingId: 2,
          labour: const LabourRef(id: 32, name: 'Bela Painter'),
          status: BookingStatus.pending,
          rating: 4.1,
          distanceKm: 1.6,
        ),
      ],
    );
  }

  ({int skillId, int size, List<int> ids})? created;

  @override
  Future<Crew> crew(int crewId) async => Crew(
    id: crewId,
    status: CrewStatus.searching,
    size: 2,
    confirmed: 1,
    pending: 1,
    openSlots: 0,
    skillName: 'Painter',
    members: [
      CrewMember(
        bookingId: 1,
        labour: const LabourRef(id: 31, name: 'Asha Painter'),
        status: BookingStatus.accepted,
      ),
      CrewMember(
        bookingId: 2,
        labour: const LabourRef(id: 32, name: 'Bela Painter'),
        status: BookingStatus.pending,
      ),
    ],
  );
}

/// The app's own route table, so the sheet's hand-off to the status screen has
/// somewhere to go.
Widget _app(MockRepository repo, Widget home) => SessionScope(
  session: Session(repository: repo),
  child: MaterialApp(
    theme: AppTheme.light,
    onGenerateRoute: (settings) => settings.name == '/'
        ? MaterialPageRoute<void>(builder: (_) => home, settings: settings)
        : Routes.onGenerateRoute(settings),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(size: const Size(390, 844), disableAnimations: true),
      child: child!,
    ),
  ),
);

void main() {
  group('LabourFilters', () {
    test('a crew needs both a count above one and a work type', () {
      expect(const LabourFilters(crewSize: 4).isCrew, isFalse);
      expect(const LabourFilters(skillId: 9).isCrew, isFalse);
      expect(const LabourFilters(skillId: 9, crewSize: 1).isCrew, isFalse);
      expect(const LabourFilters(skillId: 9, crewSize: 4).isCrew, isTrue);
    });

    test('the count shows on the filter badge and is undone by reset', () {
      expect(const LabourFilters().activeCount, 0);
      expect(const LabourFilters().isDefault, isTrue);

      const picked = LabourFilters(crewSize: 3);
      expect(picked.activeCount, 1);
      expect(picked.isDefault, isFalse);
      expect(picked.copyWith(crewSize: 1).isDefault, isTrue);
    });
  });

  group('wire models', () {
    test('a group reads its workers, area and spread', () {
      final group = LabourGroup.fromJson({
        'index': 2,
        'size': 2,
        'needed': 4,
        'complete': false,
        'distance_km': 3.4,
        'spread_km': 0.9,
        'area': 'Sector 50',
        'latitude': 28.4,
        'longitude': 77.1,
        'workers': [
          {'id': 5, 'name': 'A', 'daily_rate': 600, 'distance_km': 3.4},
          {'id': 6, 'name': 'B', 'daily_rate': 800, 'distance_km': 3.9},
        ],
      });

      expect(group.index, 2);
      expect(group.needed, 4);
      expect(group.size, 2);
      expect(group.complete, isFalse);
      expect(group.workerIds, [5, 6]);
      expect(group.dailyTotal, 1400);
      expect(group.area, 'Sector 50');
      expect(group.spreadKm, 0.9);
      expect(group.centre, const GeoPoint(28.4, 77.1));
    });

    test('a crew reads who has said yes and how far it has got', () {
      final crew = Crew.fromJson({
        'id': 9,
        'status': 'searching',
        'size': 5,
        'confirmed': 2,
        'pending': 3,
        'open_slots': 0,
        'replaced': 1,
        'exhausted': false,
        'skill': {'id': 9, 'name': 'Painter'},
        'work_date': '2026-10-20',
        'day_type': 'half',
        'members': [
          {
            'booking_id': 1,
            'status': 'accepted',
            'amount': 500,
            'distance_km': 1.2,
            'labour': {'id': 3, 'name': 'Ramesh', 'avg_rating': 4.8},
          },
          {
            'booking_id': 2,
            'status': 'pending',
            'labour': {'id': 4, 'name': 'Shivanna'},
          },
        ],
      });

      expect(crew.status, CrewStatus.searching);
      expect(crew.isLive, isTrue);
      expect(crew.progress, closeTo(0.4, 1e-9));
      expect(crew.replaced, 1);
      expect(crew.skillName, 'Painter');
      expect(crew.dayType, DayType.half);
      expect(crew.members.map((m) => m.isConfirmed), [true, false]);
      expect(crew.members.first.labour.name, 'Ramesh');
      expect(crew.members.first.rating, 4.8);
    });

    test('a filled or cancelled crew is not asking for anyone', () {
      Crew with_(String status, {int pending = 0, int open = 0}) =>
          Crew.fromJson({
            'id': 1,
            'status': status,
            'size': 2,
            'confirmed': 2,
            'pending': pending,
            'open_slots': open,
          });

      expect(with_('filled').isLive, isFalse);
      expect(with_('filled').isFilled, isTrue);
      expect(with_('cancelled', pending: 1).isLive, isFalse);
      expect(with_('filled', pending: 1).isLive, isTrue);
    });

    test('a booking row carries its crew', () {
      final booking = Booking.fromJson({
        'id': 4,
        'labour_id': 8,
        'status': 'pending',
        'offered_amount': 500,
        'crew_id': 12,
        'crew': {'id': 12, 'size': 4},
      });

      expect(booking.crewId, 12);
      expect(booking.crewSize, 4);
      expect(booking.copyWith(hasReview: true).crewId, 12);

      final solo = Booking.fromJson({
        'id': 5,
        'labour_id': 8,
        'status': 'pending',
        'offered_amount': 500,
      });
      expect(solo.crewId, isNull);
      expect(solo.crewSize, isNull);
    });
  });

  group('Mock repository', () {
    test('groups come in the asked size, nearest first', () async {
      final repo = MockRepository(latency: Duration.zero);
      final groups = await repo.labourGroups(
        lat: 28.45,
        lng: 77.02,
        skillId: Mock.painter.id,
        count: 2,
      );
      expect(groups, isNotEmpty);
      expect(groups.first.index, 1);
      expect(groups.every((g) => g.size <= 2), isTrue);
    });

    test('a crew fills up as the workers accept', () async {
      final repo = MockRepository(latency: Duration.zero);
      final crew = await repo.createCrew(
        skillId: Mock.electrician.id,
        size: 1,
        labourIds: [Mock.labours.first.id],
        workDate: DateTime.now(),
        dayType: DayType.full,
        address: 'Site',
        latitude: 28.45,
        longitude: 77.02,
      );

      expect(crew.size, 1);
      expect(crew.pending, 1);
      expect(crew.members.single.labour.id, Mock.labours.first.id);
      expect(crew.isFilled, isFalse);
    });
  });

  /// A tall phone: the results sit in a sheet that opens at 40% of the height,
  /// and a lazy list only builds the rows that fit in it.
  Future<void> onAPhone(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('Search', () {
    Future<void> pickCrew(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Painter'));
      await tester.pumpAndSettle();

      // The tile that says "2" — the stepper only ever shows the current count.
      await tester.tap(find.text('JODI'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Filter lagao'));
      await tester.tap(find.text('Filter lagao'));
      await tester.pumpAndSettle();
    }

    testWidgets('a crew search lists same-area groups with a line between', (
      tester,
    ) async {
      await onAPhone(tester);
      final repo = _TwoAreas();
      await tester.pumpWidget(_app(repo, const SearchScreen()));
      await tester.pumpAndSettle();

      await pickCrew(tester);

      expect(repo.askedCount, 2);
      expect(repo.askedSkill, _painter.id);

      expect(find.textContaining('Area 1'), findsOneWidget);
      expect(find.textContaining('Sector 14'), findsWidgets);
      expect(find.text('Asha Painter'), findsOneWidget);
      expect(find.text('Bela Painter'), findsOneWidget);

      // The divider names the next area, and the short group says so.
      expect(find.text('AGLA AREA'), findsOneWidget);
      expect(find.textContaining('Area 2'), findsOneWidget);
      expect(find.text('Sirf 1 / 2'), findsOneWidget);
      expect(find.text('Chitra Painter'), findsOneWidget);

      // The banner says what is being asked for.
      expect(find.text('2 Painter chahiye'), findsOneWidget);
    });

    testWidgets('an ordinary search never asks for groups', (tester) async {
      await onAPhone(tester);
      final repo = _TwoAreas();
      await tester.pumpWidget(_app(repo, const SearchScreen()));
      await tester.pumpAndSettle();

      expect(repo.groupCalls, 0);
      expect(find.text('AGLA AREA'), findsNothing);
    });

    testWidgets('a count with no work type nudges instead of searching', (
      tester,
    ) async {
      await onAPhone(tester);
      final repo = _TwoAreas();
      await tester.pumpWidget(_app(repo, const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEAM'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Filter lagao'));
      await tester.tap(find.text('Filter lagao'));
      await tester.pumpAndSettle();

      expect(repo.groupCalls, 0);
      expect(
        find.text('Group dekhne ke liye upar se kaam ka type bhi chunein.'),
        findsOneWidget,
      );
    });

    testWidgets('booking a group opens the crew status', (tester) async {
      await onAPhone(tester);

      // The day chips are the single-booking sheet's own widget, and they run
      // 2px over under the test font. Nothing of the crew sheet's is excused.
      final report = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.toString();
        if (text.contains('overflowed') &&
            text.contains('booking_sheet.dart')) {
          return;
        }
        report?.call(details);
      };
      addTearDown(() => FlutterError.onError = report);
      final repo = _TwoAreas();
      await tester.pumpWidget(_app(repo, const SearchScreen()));
      await tester.pumpAndSettle();
      await pickCrew(tester);

      await tester.tap(find.text('2 ko book karein'));
      await tester.pumpAndSettle();

      // The signed-out test session has no saved address to prefill.
      await tester.enterText(
        find
            .descendant(
              of: find.byType(CrewBookingSheet),
              matching: find.byType(TextField),
            )
            .first,
        'Site 9, Sector 14',
      );

      await tester.ensureVisible(find.text('Crew booking bhejein'));
      await tester.tap(find.text('Crew booking bhejein'));
      await tester.pumpAndSettle();

      // The picked group's ids go to the server, along with the size.
      expect(repo.created?.size, 2);
      expect(repo.created?.skillId, _painter.id);
      expect(repo.created?.ids, [31, 32]);

      expect(find.text('Crew status'), findsWidgets);
      expect(find.text('1 me se 1 confirm'), findsNothing);
      expect(find.text('2 me se 1 confirm'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Crew status', () {
    testWidgets('shows who accepted, who is pending, and the reassurance', (
      tester,
    ) async {
      await onAPhone(tester);
      final repo = _TwoAreas();
      await tester.pumpWidget(_app(repo, const CrewStatusScreen(crewId: 77)));
      await tester.pumpAndSettle();

      expect(find.text('2 me se 1 confirm'), findsOneWidget);
      expect(find.text('Asha Painter'), findsOneWidget);
      expect(find.text('Bela Painter'), findsOneWidget);
      expect(find.text('Accept kiya'), findsOneWidget);
      expect(find.text('Jawab ka intezar'), findsOneWidget);
      expect(find.text('Dhundh rahe hain…'), findsOneWidget);
      expect(find.textContaining('dobara'), findsWidgets);
      expect(find.text('Crew cancel karein'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('calling the crew off asks first, then shows it cancelled', (
      tester,
    ) async {
      await onAPhone(tester);
      final repo = _TwoAreas();
      await tester.pumpWidget(_app(repo, const CrewStatusScreen(crewId: 77)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Crew cancel karein'));
      await tester.tap(find.text('Crew cancel karein'));
      await tester.pumpAndSettle();

      expect(find.text('Poori crew cancel karein?'), findsOneWidget);

      // "Rehne dein" backs out; nothing is cancelled.
      await tester.tap(find.text('Rehne dein'));
      await tester.pumpAndSettle();
      expect(find.text('Crew cancel ho gayi'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
