import 'package:flutter/widgets.dart';

/// 4pt spacing scale. Names match usage intent, not pixel values, so the
/// rhythm can be retuned in one place.
abstract final class Gap {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 10.0;
  static const xl = 12.0;
  static const xxl = 14.0;
  static const x3l = 16.0;
  static const x4l = 20.0;
  static const x5l = 24.0;
  static const x6l = 28.0;
  static const x7l = 32.0;
  static const x8l = 40.0;

  // Vertical gaps, ready to drop into a Column.
  static const vXs = SizedBox(height: xs);
  static const vSm = SizedBox(height: sm);
  static const vMd = SizedBox(height: md);
  static const vLg = SizedBox(height: lg);
  static const vXl = SizedBox(height: xl);
  static const vXxl = SizedBox(height: xxl);
  static const v16 = SizedBox(height: x3l);
  static const v20 = SizedBox(height: x4l);
  static const v24 = SizedBox(height: x5l);
  static const v28 = SizedBox(height: x6l);
  static const v32 = SizedBox(height: x7l);

  // Horizontal gaps.
  static const hXs = SizedBox(width: xs);
  static const hSm = SizedBox(width: sm);
  static const hMd = SizedBox(width: md);
  static const hLg = SizedBox(width: lg);
  static const hXl = SizedBox(width: xl);
  static const hXxl = SizedBox(width: xxl);
  static const h16 = SizedBox(width: x3l);
}

/// Corner radii from the mockups: `--radius:14px` / `--radius-sm:8px`.
abstract final class Radii {
  static const sm = 8.0;
  static const md = 14.0;
  static const pill = 20.0;
  static const phone = 34.0;

  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rPill = BorderRadius.all(Radius.circular(pill));
}
