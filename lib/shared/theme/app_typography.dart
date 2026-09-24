/// Highland Pulse type scale, mirroring `highland_pulse/DESIGN.md`'s
/// `typography` tokens. Every style is Plus Jakarta Sans, bundled in
/// `assets/fonts/` so each device shows the same typeface, with Noto Sans
/// Ethiopic (also bundled) as the fallback that renders Fidel.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

  /// Renders every character Plus Jakarta Sans lacks, i.e. Ethiopic script.
  static const String ethiopicFontFamily = 'NotoSansEthiopic';
  static const List<String> fontFamilyFallback = [ethiopicFontFamily];

  /// DESIGN.md: Ge'ez glyphs need 15-20% more line height than Latin so
  /// vowel marks above and below are never clipped.
  static const double ethiopicLineHeightFactor = 1.18;

  static const TextStyle displayLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 48 / 40,
    letterSpacing: -0.02 * 40,
  );

  static const TextStyle displayLgMobile = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 38 / 32,
    letterSpacing: -0.02 * 32,
  );

  static const TextStyle headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    letterSpacing: -0.01 * 28,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 24 / 18,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 26 / 18,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const TextStyle labelLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 20 / 16,
    letterSpacing: 0.02 * 16,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 16 / 13,
    letterSpacing: 0.04 * 13,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 14 / 11,
    letterSpacing: 0.05 * 11,
  );

  /// DESIGN.md "Phonetics & Pronunciation Guides": the Latin or IPA line
  /// under Fidel, in `body-sm` at weight 500 and the muted text colour.
  static const TextStyle phonetic = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    color: AppColors.textMuted,
  );

  /// Whether [text] contains any Ethiopic character (the Ethiopic,
  /// Ethiopic Supplement, Ethiopic Extended and Extended-A blocks).
  static bool hasEthiopic(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x1200 && rune <= 0x139F) ||
          (rune >= 0x2D80 && rune <= 0x2DDF) ||
          (rune >= 0xAB00 && rune <= 0xAB2F)) {
        return true;
      }
    }
    return false;
  }

  /// [style] as it should render [text]: with the extra Ge'ez line height
  /// when the text contains Fidel, unchanged otherwise.
  static TextStyle forText(TextStyle style, String text) {
    if (!hasEthiopic(text)) return style;
    final height = style.height ?? 1.2;
    return style.copyWith(height: height * ethiopicLineHeightFactor);
  }
}
