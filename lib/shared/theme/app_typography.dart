/// Highland Pulse type scale, mirroring `highland_pulse/DESIGN.md`'s
/// `typography` tokens. Font family is Plus Jakarta Sans for every style;
/// since the font asset isn't bundled with the app yet, this falls back to
/// the platform default sans-serif until the font files are added.
library;

import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  static const TextStyle displayLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 48 / 40,
    letterSpacing: -0.02 * 40,
  );

  static const TextStyle displayLgMobile = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 38 / 32,
    letterSpacing: -0.02 * 32,
  );

  static const TextStyle headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    letterSpacing: -0.01 * 28,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 24 / 18,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 26 / 18,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const TextStyle labelLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 20 / 16,
    letterSpacing: 0.02 * 16,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 16 / 13,
    letterSpacing: 0.04 * 13,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 14 / 11,
    letterSpacing: 0.05 * 11,
  );
}
