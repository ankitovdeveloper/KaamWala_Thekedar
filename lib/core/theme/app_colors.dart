import 'package:flutter/material.dart';

/// Brand palette lifted from the HTML mockups (`screens/*.html` `:root` block).
/// Keep this the single source of truth — no raw hex anywhere else.
abstract final class AppColors {
  // Brand
  static const yellow = Color(0xFFFFD600);
  static const yellowDark = Color(0xFFF5C100);
  static const yellowLight = Color(0xFFFFF9C4);

  // Neutrals
  static const black = Color(0xFF111111);
  static const dark = Color(0xFF1A1A1A);
  static const muted = Color(0xFF555555);
  static const white = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF7F7F7);
  static const surfaceAlt = Color(0xFFF5F5F5);
  static const arrow = Color(0xFFCCCCCC);
  static const toggleOff = Color(0xFFDDDDDD);

  // Semantic
  static const success = Color(0xFF4CAF50);
  static const successDark = Color(0xFF2E7D32);
  static const successBg = Color(0xFFE8F5E9);
  static const danger = Color(0xFFD32F2F);
  static const pendingText = Color(0xFF7B5E00);
  static const doneBg = Color(0xFFF3F3F3);

  // Map mock
  static const mapWater = Color(0xFFC8DDD8);
  static const mapBlock = Color(0x99B4C8C3);
  static const mapRoad = Color(0xBFFFFFFF);

  // Lines & veils — opacity-derived tokens so call sites stay declarative.
  static const border = Color(0x1A000000); // rgba(0,0,0,.10)
  static const borderStrong = Color(0x24000000); // rgba(0,0,0,.14)
  static const veil06 = Color(0x0F000000); // rgba(0,0,0,.06)
  static const veil10 = Color(0x1A000000);
  static const onDarkIdle = Color(0x66FFFFFF); // rgba(255,255,255,.4)

  /// Subtle depth used by cards. The mockups lean on 1–2px soft shadows only.
  static const cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static const cardShadowHover = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const floatingShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 12, offset: Offset(0, 2)),
  ];

  /// Deterministic accent for avatars so the same person always looks the same.
  static (Color bg, Color fg) avatarPair(String seed) {
    final pairs = <(Color, Color)>[
      (yellow, black),
      (black, yellow),
      (Color(0xFF222222), yellow),
      (yellowDark, black),
      (Color(0xFF333333), yellow),
    ];
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return pairs[hash % pairs.length];
  }
}
