/// Highland Pulse color tokens.
///
/// Mirrors the token set defined in
/// `stich-screens/extracted/stitch_ethiopian_language_learning_app/highland_pulse/DESIGN.md`
/// verbatim so every screen pulls from a single source of truth instead of
/// re-deriving hex values. Field names follow the DESIGN.md token names
/// (kebab-case converted to lowerCamelCase).
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // Core surfaces
  static const Color surface = Color(0xFFFFF8F5);
  static const Color surfaceDim = Color(0xFFE9D7C8);
  static const Color surfaceBright = Color(0xFFFFF8F5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFFF1E8);
  static const Color surfaceContainer = Color(0xFFFEEADC);
  static const Color surfaceContainerHigh = Color(0xFFF8E5D6);
  static const Color surfaceContainerHighest = Color(0xFFF2DFD1);
  static const Color surfaceVariant = Color(0xFFF2DFD1);

  // Text / on-colors
  static const Color onSurface = Color(0xFF231A11);
  static const Color onSurfaceVariant = Color(0xFF404942);
  static const Color inverseSurface = Color(0xFF392E25);
  static const Color inverseOnSurface = Color(0xFFFFEEE1);

  // Outline
  static const Color outline = Color(0xFF707971);
  static const Color outlineVariant = Color(0xFFBFC9BF);

  // Brand: Primary — Highland Acacia
  static const Color primary = Color(0xFF004527);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1B5E3B);
  static const Color onPrimaryContainer = Color(0xFF92D5A9);
  static const Color primaryFixed = Color(0xFFAEF2C4);
  static const Color primaryFixedDim = Color(0xFF92D5A9);
  static const Color onPrimaryFixed = Color(0xFF002110);
  static const Color onPrimaryFixedVariant = Color(0xFF085230);
  static const Color primaryBevel = Color(0xFF124027);

  // Brand: Secondary — Simien Gold
  static const Color secondary = Color(0xFF8D4F00);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFFA03B);
  static const Color onSecondaryContainer = Color(0xFF6C3B00);
  static const Color secondaryFixed = Color(0xFFFFDCC0);
  static const Color secondaryFixedDim = Color(0xFFFFB875);
  static const Color onSecondaryFixed = Color(0xFF2D1600);
  static const Color onSecondaryFixedVariant = Color(0xFF6B3B00);
  static const Color secondaryBrand = Color(0xFFE08722);
  static const Color secondaryBevel = Color(0xFFA85E0E);

  // Brand: Tertiary — Rift Terracotta
  static const Color tertiary = Color(0xFF7D0301);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF9F2115);
  static const Color onTertiaryContainer = Color(0xFFFFB4A7);
  static const Color tertiaryFixed = Color(0xFFFFDAD4);
  static const Color tertiaryFixedDim = Color(0xFFFFB4A8);
  static const Color onTertiaryFixed = Color(0xFF410000);
  static const Color onTertiaryFixedVariant = Color(0xFF8E1309);
  static const Color tertiaryBrand = Color(0xFFD84A38);
  static const Color tertiaryBevel = Color(0xFF9F2B1D);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Background
  static const Color background = Color(0xFFFFF8F5);
  static const Color onBackground = Color(0xFF231A11);

  // Neutral border used by "default" tactile cards in the exported markup.
  static const Color cardBorderDefault = Color(0xFFEDE5D8);
  static const Color cardBevelDefault = Color(0xFFE2D7C5);
}
