import 'models/models.dart';

/// Seeded design data. Used by `MockRepository` so the UI runs (and the widget
/// tests pass) with no server. Shapes match what the Laravel API returns.
abstract final class Mock {
  // ── Skills (`skills` table) ───────────────────────────────────────────────
  static const electrician = Skill(id: 1, name: 'Electrician', icon: '⚡');
  static const wiring = Skill(id: 2, name: 'Wiring', icon: '🔌');
  static const repairs = Skill(id: 3, name: 'Repairs', icon: '🔧');
  static const acFitting = Skill(id: 4, name: 'AC Fitting', icon: '💡');
  static const plumber = Skill(id: 5, name: 'Plumber', icon: '🔧');
  static const pipeline = Skill(id: 6, name: 'Pipeline', icon: '💧');
  static const carpenter = Skill(id: 7, name: 'Carpenter', icon: '🪚');
  static const furniture = Skill(id: 8, name: 'Furniture', icon: '🪑');
  static const painter = Skill(id: 9, name: 'Painter', icon: '🎨');
  static const mason = Skill(id: 10, name: 'Mason', icon: '🧱');
  static const welder = Skill(id: 11, name: 'Welder', icon: '🔥');

  static const allSkills = <Skill>[
    electrician,
    plumber,
    carpenter,
    painter,
    mason,
    welder,
  ];

  // ── Signed-in thekedar ────────────────────────────────────────────────────
  static const currentUser = AppUser(
    id: 1,
    name: 'Amit Khurana',
    phone: '9876543210',
    role: UserRole.thekedar,
    city: 'Gurgaon',
    address: 'Sector 14, Gurgaon',
    latitude: 28.4595,
    longitude: 77.0266,
    referralCode: 'AMIT250',
    isProfileComplete: true,
  );

  static const currentLocation = 'Sector 14, Gurgaon';

  // ── Labour pool ───────────────────────────────────────────────────────────
  static final labours = <Labour>[
    Labour(
      id: 11,
      name: 'Ramesh Kumar',
      dailyRate: 450,
      skills: const [electrician, wiring, repairs, acFitting],
      avgRating: 4.8,
      ratingsCount: 142,
      totalJobs: 320,
      experienceYears: 8,
      isOnDuty: true,
      city: 'Sector 14, Gurgaon',
      distanceKm: 1.2,
      bio:
          'Ghar aur office dono ka electrical kaam karta hoon. '
          'Wiring, MCB, AC fitting — sab kuch time pe aur safai se.',
      latitude: 28.4680,
      longitude: 77.0290,
      reviews: [
        Review(
          id: 1,
          reviewerName: 'Priya Sharma',
          rating: 5,
          comment:
              'Bahut achha kaam kiya. Time pe aaye aur kaam bhi '
              'saaf kiya. Recommended!',
          createdAt: DateTime(2026, 7, 24),
        ),
        Review(
          id: 2,
          reviewerName: 'Rohan Gupta',
          rating: 4,
          comment:
              'Professional hai, kaam mein expert hai. '
              'Dobara zaroor bulaunga.',
          createdAt: DateTime(2026, 7, 12),
        ),
        Review(
          id: 3,
          reviewerName: 'Sanjay Mehta',
          rating: 5,
          comment: 'Rate bhi theek liya aur kaam bhi jaldi khatam kiya.',
          createdAt: DateTime(2026, 6, 30),
        ),
      ],
    ),
    Labour(
      id: 12,
      name: 'Suresh Yadav',
      dailyRate: 380,
      skills: const [plumber, pipeline, repairs],
      avgRating: 4.5,
      ratingsCount: 87,
      totalJobs: 196,
      experienceYears: 6,
      isOnDuty: true,
      city: 'Sector 15, Gurgaon',
      distanceKm: 2.4,
      bio: 'Pipeline leakage, bathroom fitting aur tank cleaning ka kaam.',
      latitude: 28.4520,
      longitude: 77.0410,
      reviews: [
        Review(
          id: 4,
          reviewerName: 'Neha Verma',
          rating: 5,
          comment: 'Leakage turant theek kar diya. Bahut badhiya.',
          createdAt: DateTime(2026, 7, 18),
        ),
        Review(
          id: 5,
          reviewerName: 'Imran Ali',
          rating: 4,
          comment: 'Kaam achha, thoda late aaye the.',
          createdAt: DateTime(2026, 7, 2),
        ),
      ],
    ),
    Labour(
      id: 13,
      name: 'Mohd. Iqbal',
      dailyRate: 520,
      skills: const [carpenter, furniture],
      avgRating: 4.3,
      ratingsCount: 56,
      totalJobs: 118,
      experienceYears: 5,
      isOnDuty: true,
      city: 'Sector 12, Gurgaon',
      distanceKm: 3.1,
      bio:
          'Furniture banane aur repair ka kaam. Almirah, bed, modular kitchen.',
      latitude: 28.4450,
      longitude: 77.0180,
      reviews: [
        Review(
          id: 6,
          reviewerName: 'Kavita Rao',
          rating: 4,
          comment: 'Almirah ekdum sahi banayi. Finishing achhi thi.',
          createdAt: DateTime(2026, 6, 20),
        ),
      ],
    ),
    Labour(
      id: 14,
      name: 'Dinesh Prajapati',
      dailyRate: 400,
      skills: const [painter],
      avgRating: 4.6,
      ratingsCount: 73,
      totalJobs: 154,
      experienceYears: 7,
      isOnDuty: true,
      city: 'Sector 14, Gurgaon',
      distanceKm: 0.8,
      bio: 'Interior aur exterior painting, putty aur texture ka kaam.',
      latitude: 28.4630,
      longitude: 77.0230,
      reviews: [
        Review(
          id: 7,
          reviewerName: 'Arjun Nair',
          rating: 5,
          comment: 'Poora ghar 3 din mein paint kar diya. Zero mess.',
          createdAt: DateTime(2026, 7, 27),
        ),
      ],
    ),
    Labour(
      id: 15,
      name: 'Vijay Singh',
      dailyRate: 600,
      skills: const [mason, welder],
      avgRating: 4.1,
      ratingsCount: 39,
      totalJobs: 88,
      experienceYears: 10,
      isOnDuty: true,
      city: 'Sector 17, Gurgaon',
      distanceKm: 4.6,
      bio: 'Chinaai, plaster aur grill welding ka purana experience.',
      latitude: 28.4390,
      longitude: 77.0480,
    ),
  ];

  static Labour labourById(int id) =>
      labours.firstWhere((l) => l.id == id, orElse: () => labours.first);

  // ── Bookings ──────────────────────────────────────────────────────────────
  // Dated relative to "now" so the demo never looks stale.
  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static List<Booking> bookings() => [
    Booking(
      id: 101,
      labour: labours[0].ref,
      skillName: 'Electrician',
      workDate: _today.add(const Duration(days: 1)),
      startTime: '10:00',
      dayType: DayType.full,
      price: 450,
      address: 'Sector 14, Gurgaon',
      status: BookingStatus.accepted,
      jobStage: JobStage.onTheWay,
    ),
    Booking(
      id: 102,
      labour: labours[1].ref,
      skillName: 'Plumber',
      workDate: _today.add(const Duration(days: 2)),
      startTime: '09:00',
      dayType: DayType.half,
      price: 190,
      address: 'Sector 14, Gurgaon',
      status: BookingStatus.pending,
      jobStage: JobStage.pending,
    ),
    Booking(
      id: 103,
      labour: labours[2].ref,
      skillName: 'Carpenter',
      workDate: _today.subtract(const Duration(days: 22)),
      startTime: '11:00',
      dayType: DayType.full,
      price: 520,
      address: 'Sector 14, Gurgaon',
      status: BookingStatus.completed,
      jobStage: JobStage.completed,
    ),
    Booking(
      id: 104,
      labour: labours[3].ref,
      skillName: 'Painter',
      workDate: _today.subtract(const Duration(days: 40)),
      startTime: '08:30',
      dayType: DayType.full,
      price: 400,
      address: 'Udyog Vihar, Phase 4, Gurgaon',
      status: BookingStatus.completed,
      jobStage: JobStage.completed,
      hasReview: true,
    ),
  ];

  // ── Addresses ─────────────────────────────────────────────────────────────
  static const addresses = <SavedAddress>[
    SavedAddress(
      id: 1,
      label: 'Ghar',
      address: 'Sector 14, Gurgaon',
      city: 'Haryana',
      isDefault: true,
    ),
    SavedAddress(
      id: 2,
      label: 'Office',
      address: 'Udyog Vihar, Phase 4',
      city: 'Gurgaon',
    ),
  ];

  static const accountSettings = AccountSettings();

  static const appVersion = 'v1.0.2';
}
