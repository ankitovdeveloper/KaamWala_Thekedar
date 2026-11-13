import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaamwala_thekedar/core/referral/install_referrer.dart';
import 'package:kaamwala_thekedar/data/models/models.dart';

void main() {
  group('InstallReferrer.parseCode', () {
    test('reads ref= out of the query string the landing page builds', () {
      expect(
        InstallReferrer.parseCode('utm_source=referral&ref=KW7X2PQR'),
        'KW7X2PQR',
      );
      expect(InstallReferrer.parseCode('ref=KW7X2PQR'), 'KW7X2PQR');
    });

    test('decodes a referrer the store handed back still encoded', () {
      expect(
        InstallReferrer.parseCode('utm_source%3Dreferral%26ref%3DKW7X2PQR'),
        'KW7X2PQR',
      );
    });

    test('accepts a bare code and normalises case and spaces', () {
      expect(InstallReferrer.parseCode('KW7X2PQR'), 'KW7X2PQR');
      expect(InstallReferrer.parseCode('  kw7x2pqr '), 'KW7X2PQR');
      expect(InstallReferrer.parseCode('ref=kw7x2pqr'), 'KW7X2PQR');
    });

    test('anything that is not a code yields null', () {
      expect(InstallReferrer.parseCode(null), isNull);
      expect(InstallReferrer.parseCode(''), isNull);
      // The organic Play Store referrer: no ref, nobody to credit.
      expect(
        InstallReferrer.parseCode(
          'utm_source=google-play&utm_medium=organic',
        ),
        isNull,
      );
      expect(InstallReferrer.parseCode('ref=<b>x</b>'), isNull);
      expect(InstallReferrer.parseCode('ref=KW'), isNull); // too short
      expect(InstallReferrer.parseCode('ref=${'A' * 21}'), isNull); // too long
      expect(InstallReferrer.parseCode('%E0%A4'), isNull); // broken escape
    });

    test('a test override stands in for the platform call', () async {
      InstallReferrer.debugRawReferrer = () async => 'ref=kwtest22';
      addTearDown(() => InstallReferrer.debugRawReferrer = null);

      expect(await InstallReferrer.referralCode(), 'KWTEST22');
    });

    test('off Android there is no referrer, and no error', () async {
      expect(await InstallReferrer.referralCode(), isNull);
    });
  });

  group('ReferralCodeFormatter', () {
    TextEditingValue format(String typed) =>
        const ReferralCodeFormatter().formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: typed,
            selection: TextSelection.collapsed(offset: typed.length),
          ),
        );

    test('upper-cases and keeps only letters and digits', () {
      expect(format('kw 7x-2pqr!').text, 'KW7X2PQR');
    });

    test('stops at 20 characters', () {
      expect(format('A' * 25).text, 'A' * 20);
    });
  });

  group('SignupDraft.toJson', () {
    const base = SignupDraft(
      name: 'Amit Khurana',
      phone: '9812345678',
      address: 'Sector 45, Gurgaon',
    );

    test('omits the referral code when none was given', () {
      expect(base.toJson().containsKey('referral_code'), isFalse);
      expect(
        const SignupDraft(
          name: 'Amit Khurana',
          phone: '9812345678',
          address: 'Sector 45, Gurgaon',
          referralCode: '',
        ).toJson().containsKey('referral_code'),
        isFalse,
      );
    });

    test('sends it as referral_code when there is one', () {
      const draft = SignupDraft(
        name: 'Amit Khurana',
        phone: '9812345678',
        address: 'Sector 45, Gurgaon',
        referralCode: 'KW7X2PQR',
      );
      expect(draft.toJson()['referral_code'], 'KW7X2PQR');
    });
  });
}
