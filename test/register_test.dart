import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/data/api/api_exception.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';
import 'package:kaamwala_thekedar/data/repositories/mock_repository.dart';
import 'package:kaamwala_thekedar/data/session.dart';
import 'package:kaamwala_thekedar/features/auth/login_screen.dart';
import 'package:kaamwala_thekedar/features/auth/register_screen.dart';
import 'package:kaamwala_thekedar/widgets/kw_bottom_nav.dart';
import 'package:kaamwala_thekedar/widgets/kw_terms.dart';

import 'widget_test.dart' show host, hostApp;

/// Records what the Register screen sent, and lets a test choose the outcome.
class _RecordingRepository extends MockRepository {
  _RecordingRepository({this.rejectPhone = false})
    : super(latency: Duration.zero);

  /// Mimics the server's "this number already has an account" 422.
  final bool rejectPhone;

  SignupDraft? registered;
  SignupDraft? verifiedWith;

  /// The Terms version the screen ticked the box against, as sent on to
  /// `verify-otp`.
  String? verifiedTermsVersion;

  @override
  Future<OtpChallenge> register({
    required SignupDraft draft,
    String countryCode = '+91',
  }) async {
    registered = draft;
    if (rejectPhone) {
      throw const ApiException(
        'Already registered.',
        statusCode: 422,
        fieldErrors: {
          'phone': ['Phone number already registered.'],
        },
      );
    }
    return OtpChallenge(
      phone: draft.phone,
      countryCode: countryCode,
      debugCode: '123456',
    );
  }

  @override
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    String countryCode = '+91',
    SignupDraft? draft,
    String? termsVersion,
  }) {
    verifiedWith = draft;
    verifiedTermsVersion = termsVersion;
    return super.verifyOtp(
      phone: phone,
      otp: otp,
      countryCode: countryCode,
      draft: draft,
      termsVersion: termsVersion,
    );
  }
}

/// Fills the form. Every field is addressed by its position, which is stable:
/// name, phone, address, email, in that order down the screen.
Future<void> fillForm(
  WidgetTester tester, {
  String name = 'Amit Khurana',
  String phone = '9812345678',
  String address = 'Sector 45, Gurgaon',
  String email = '',
  bool acceptTerms = true,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), phone);
  await tester.enterText(fields.at(2), address);
  if (email.isNotEmpty) await tester.enterText(fields.at(3), email);
  await tester.pumpAndSettle();
  if (acceptTerms) await tickTerms(tester);
}

/// Ticks the Terms box. Its own helper because the box is a gate, not a
/// field: a test that wants to prove the gate holds fills the form *without*
/// it (`fillForm(acceptTerms: false)`).
Future<void> tickTerms(WidgetTester tester) async {
  final box = find.byType(KwTermsCheck);
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
}

Future<void> tapSubmit(WidgetTester tester) async {
  final button = find.text('Aage badhein');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('Register form', () {
    testWidgets('asks for exactly the four sign-up details', (tester) async {
      await tester.pumpWidget(host(const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Poora naam'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      // Optional, and the label has to say so — the server does not require it.
      expect(find.text('Email (optional)'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('an empty form flags every required field at once', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      await tester.pumpWidget(host(const RegisterScreen(), repository: repo));
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      // All three, not just the first: making the user submit once per field
      // is the behaviour this guards against.
      expect(find.text('Naam daalein'), findsOneWidget);
      expect(find.text('Poora 10-digit number daalein'), findsOneWidget);
      expect(find.text('Apna address daalein'), findsOneWidget);
      // The Terms box is flagged in the same pass, not on a later submit.
      expect(
        find.text('Aage badhne ke liye shartein accept karna zaroori hai'),
        findsOneWidget,
      );
      // Nothing left the device.
      expect(repo.registered, isNull);
    });

    testWidgets('a filled form still will not submit until Terms are ticked', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      await tester.pumpWidget(host(const RegisterScreen(), repository: repo));
      await tester.pumpAndSettle();

      await fillForm(tester, acceptTerms: false);
      await tapSubmit(tester);

      expect(
        find.text('Aage badhne ke liye shartein accept karna zaroori hai'),
        findsOneWidget,
      );
      expect(repo.registered, isNull);

      // Ticking it is the only thing that was missing.
      await tickTerms(tester);
      await tapSubmit(tester);

      expect(repo.registered, isNotNull);
    });

    testWidgets('a blank email is accepted, a malformed one is not', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      await tester.pumpWidget(host(const RegisterScreen(), repository: repo));
      await tester.pumpAndSettle();

      await fillForm(tester, email: 'not-an-email');
      await tapSubmit(tester);

      expect(find.text('Sahi email daalein'), findsOneWidget);
      expect(repo.registered, isNull);

      // Clearing it is enough to get through — the field is optional.
      await tester.enterText(find.byType(TextField).at(3), '');
      await tester.pumpAndSettle();
      await tapSubmit(tester);

      expect(repo.registered, isNotNull);
      expect(repo.registered!.email, isEmpty);
    });

    testWidgets('sends the typed details to /auth/register', (tester) async {
      final repo = _RecordingRepository();
      await tester.pumpWidget(host(const RegisterScreen(), repository: repo));
      await tester.pumpAndSettle();

      await fillForm(tester, email: 'amit@example.com');
      await tapSubmit(tester);

      final sent = repo.registered;
      expect(sent, isNotNull);
      expect(sent!.name, 'Amit Khurana');
      // Bare digits: the field displays `98123 45678` but the API wants neither
      // the space nor the country code.
      expect(sent.phone, '9812345678');
      expect(sent.address, 'Sector 45, Gurgaon');
      expect(sent.email, 'amit@example.com');
    });

    testWidgets('the payload omits an email that was left blank', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      await tester.pumpWidget(host(const RegisterScreen(), repository: repo));
      await tester.pumpAndSettle();

      await fillForm(tester);
      await tapSubmit(tester);

      // A `nullable` validator must see an absent key, not an empty string.
      expect(repo.registered!.toJson().containsKey('email'), isFalse);
      expect(repo.registered!.toJson()['address'], 'Sector 45, Gurgaon');
    });

    testWidgets('a number that already has an account says so on the field', (
      tester,
    ) async {
      final repo = _RecordingRepository(rejectPhone: true);
      await tester.pumpWidget(host(const RegisterScreen(), repository: repo));
      await tester.pumpAndSettle();

      await fillForm(tester);
      await tapSubmit(tester);

      // The message points at the fix, which is to log in instead.
      expect(
        find.text('Ye number pehle se registered hai. Login karein.'),
        findsOneWidget,
      );
    });
  });

  group('Register navigation', () {
    testWidgets('Login offers the way in to Register, and back out again', (
      tester,
    ) async {
      await tester.pumpWidget(hostApp());
      await tester.pumpAndSettle();

      // Starts signed out on Login.
      expect(find.text('OTP Bhejo'), findsOneWidget);

      await tester.tap(find.text('Register karein'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      // "Pehle se account hai? Login karein" pops rather than pushing a second
      // Login route on top of the first. It sits under the four fields, so it
      // has to be scrolled to before it can be tapped.
      final loginLink = find.text('Login karein');
      await tester.ensureVisible(loginLink);
      await tester.pumpAndSettle();
      await tester.tap(loginLink);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a completed sign-up carries the draft into verify-otp', (
      tester,
    ) async {
      final repo = _RecordingRepository();
      final session = Session(repository: repo);
      addTearDown(session.dispose);

      await tester.pumpWidget(
        SessionScope(
          session: session,
          child: MaterialApp(
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: RegisterScreen(),
            ),
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => const SizedBox.shrink(),
              settings: settings,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await fillForm(tester);
      await tapSubmit(tester);

      // The route table above is a stub, so this asserts the call, not the
      // screen: `/auth/register` succeeded and the flow moved on with the
      // draft still in hand.
      expect(repo.registered, isNotNull);
    });
  });

  group('Sign-up OTP', () {
    testWidgets('finishes the account and lands in the app', (tester) async {
      // The whole app, so this exercises the real route table end to end:
      // Login → Register → OTP → the shell.
      await tester.pumpWidget(hostApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register karein'));
      await tester.pumpAndSettle();

      await fillForm(tester);
      await tapSubmit(tester);

      // The mock echoes the code back, so the boxes arrive prefilled and the
      // button reads as a sign-up rather than a login.
      expect(find.text('Verify & Account banayein'), findsOneWidget);

      await tester.tap(find.text('Verify & Account banayein'));
      await tester.pumpAndSettle();

      expect(find.byType(KwBottomNav), findsOneWidget);
    });
  });
}
