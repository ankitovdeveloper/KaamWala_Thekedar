import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Who sent this install, as far as the Play Store knows.
///
/// The landing page's Play Store button carries the sharer's code as
/// `&referrer=utm_source%3Dreferral%26ref%3DKW7X2PQR`; Google hands that string
/// back to the app through the Install Referrer API (`MainActivity.kt`), which
/// is the only way a code survives the trip through the store. Android only —
/// everywhere else the Register screen's field is typed by hand.
class InstallReferrer {
  InstallReferrer._();

  static const _channel = MethodChannel('kaamji/app');

  /// The shape of a Share & Earn code once normalised. Server codes are `KW`
  /// plus six characters; the server accepts up to 20.
  static final _shape = RegExp(r'^[A-Z0-9]{4,20}$');

  /// Swaps the platform call out in widget tests, which run on the host OS
  /// where the channel does not exist.
  @visibleForTesting
  static Future<String?> Function()? debugRawReferrer;

  /// The referral code this install came with, or null when there is none —
  /// not installed from the store, a link without a code, off Android, or the
  /// Play Store too old to answer. Never throws and never takes longer than a
  /// few seconds: it only pre-fills an optional field.
  static Future<String?> referralCode() async {
    try {
      final read = debugRawReferrer ?? _readPlatform;
      final raw = await read().timeout(const Duration(seconds: 5));
      return parseCode(raw);
    } catch (e) {
      debugPrint('InstallReferrer failed: $e');
      return null;
    }
  }

  static Future<String?> _readPlatform() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('getInstallReferrer');
  }

  /// Pulls the code out of a raw referrer string. Accepts the query form the
  /// landing page builds (`utm_source=referral&ref=KW7X2PQR`), the same string
  /// still percent-encoded, or a bare code; anything else yields null.
  static String? parseCode(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;

    try {
      // Some store paths hand the referrer back still encoded once.
      if (!text.contains('=') && text.contains('%')) {
        text = Uri.decodeQueryComponent(text);
      }
      final ref = text.contains('=')
          ? Uri.splitQueryString(text)['ref']
          : text;
      if (ref == null) return null;
      final code = normalize(ref);
      return isCode(code) ? code : null;
    } on FormatException {
      return null; // A malformed percent escape — nothing usable in it.
    } on ArgumentError {
      return null;
    }
  }

  /// Trimmed and upper-cased — the form the server stores codes in.
  static String normalize(String code) => code.trim().toUpperCase();

  /// Whether [code] (already normalised) is worth asking the server about.
  static bool isCode(String code) => _shape.hasMatch(code);
}

/// Keeps a referral-code field to what a code can contain: A-Z and 0-9,
/// upper-cased as it is typed, at most 20 characters.
class ReferralCodeFormatter extends TextInputFormatter {
  const ReferralCodeFormatter();

  static final _notAllowed = RegExp(r'[^A-Z0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll(_notAllowed, '');
    if (text.length > 20) text = text.substring(0, 20);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
