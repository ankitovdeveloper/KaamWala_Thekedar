import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type ramp mirroring the mockups. Segoe UI is the design font; on non-Windows
/// targets the fallback chain lands on the platform's own UI face, which keeps
/// the same humanist-sans feel without shipping a font binary.
abstract final class AppType {
  static const family = 'Segoe UI';
  static const fallback = <String>[
    'Segoe UI',
    'Roboto',
    '.SF UI Text',
    'San Francisco',
    'Helvetica Neue',
    'Arial',
    // Hindi and Bhojpuri render in Devanagari, which none of the Latin faces
    // above cover. Named explicitly so the shaper picks a real Devanagari font
    // instead of falling through to tofu boxes on desktop targets.
    'Noto Sans Devanagari',
    'Nirmala UI',
    'Mangal',
    'sans-serif',
  ];

  static TextStyle _base(
    double size,
    FontWeight weight, {
    Color color = AppColors.black,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // Display / headings
  static TextStyle get h1 => _base(26, FontWeight.w600);
  static TextStyle get h2 => _base(20, FontWeight.w700);
  static TextStyle get h3 => _base(18, FontWeight.w600);
  static TextStyle get h4 => _base(16, FontWeight.w600);

  // Body
  static TextStyle get body => _base(14, FontWeight.w400, height: 1.45);
  static TextStyle get bodyStrong => _base(14, FontWeight.w600);
  static TextStyle get bodyMuted =>
      _base(14, FontWeight.w400, color: AppColors.muted, height: 1.45);

  // Supporting
  static TextStyle get label =>
      _base(12, FontWeight.w500, color: AppColors.muted);
  static TextStyle get caption =>
      _base(12, FontWeight.w400, color: AppColors.muted);
  static TextStyle get micro =>
      _base(11, FontWeight.w400, color: AppColors.muted);
  static TextStyle get nano => _base(10, FontWeight.w500);

  // Numerals — tabular so counters and prices don't jitter while animating.
  static TextStyle get statNumber => _base(
    20,
    FontWeight.w700,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle get price => _base(
    14,
    FontWeight.w700,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle get otpDigit => _base(22, FontWeight.w600);

  // Interactive
  static TextStyle get button => _base(15, FontWeight.w600);
  static TextStyle get buttonLarge => _base(16, FontWeight.w700);
  static TextStyle get buttonSmall => _base(13, FontWeight.w600);

  static TextStyle get sectionTitle => _base(
    12,
    FontWeight.w600,
    color: AppColors.muted,
  ).copyWith(letterSpacing: 0.72);
}
