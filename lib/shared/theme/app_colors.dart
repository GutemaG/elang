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

  // Answer states: DESIGN.md "Choice & Match Tiles" (component 4).
  /// Selected, not yet graded: soft gold tint.
  static const Color answerSelected = Color(0xFFFFF7ED);

  /// Graded correct: soft mint.
  static const Color answerCorrect = Color(0xFFE8F8F0);

  /// Graded incorrect: soft blush.
  static const Color answerIncorrect = Color(0xFFFDF0EE);

  /// A chosen option card (language, daily goal): the daily-goal mockup's
  /// `bg-[#F0F7F2]`.
  static const Color optionChosen = Color(0xFFF0F7F2);

  // Choice tiles at rest: DESIGN.md component 4, "2px #E5DDD0 border,
  // 3px #D5CCBD bottom rim". The rim is also the neutral shelf of the
  // white secondary button.
  static const Color tileBorder = Color(0xFFE5DDD0);
  static const Color tileShelf = Color(0xFFD5CCBD);

  // Learning-map nodes: DESIGN.md component 2.
  static const Color lockedNode = Color(0xFFE8DFD3);
  static const Color lockedNodeIcon = Color(0xFFBAAFA1);

  /// The active node's shelf, and the selected tile's rim in DESIGN.md.
  static const Color activeNodeShelf = Color(0xFFC47318);

  // Gamification accents: DESIGN.md "Gamification Electric Accents".
  static const Color streak = Color(0xFFFF5A1F);
  static const Color streakRim = Color(0xFFFFA726);
  static const Color gem = Color(0xFF10B981);
  static const Color xp = Color(0xFF0EA5E9);

  /// Subheads, timestamps and pronunciation lines: DESIGN.md "Text Muted".
  static const Color textMuted = Color(0xFF786A5E);

  /// Progress-track lanes and path connectors: DESIGN.md "Layout".
  static const Color track = Color(0xFFE2D9CC);

  // Tones (see `app_tone.dart`). Borders and icon surfaces are the
  // lesson-complete stat cards' (`#D1E8D9`, `#E5F5EC`, `#F3DFC7`, `#FBD6CF`,
  // `#FEE9E6`). No mockup draws a tinted shelf, so each shelf is its border
  // one step darker, as `cardBevelDefault` is to `cardBorderDefault`.
  static const Color primaryToneBorder = Color(0xFFD1E8D9);
  static const Color primaryToneShelf = Color(0xFFB9D6C3);
  static const Color primaryToneSurface = Color(0xFFE5F5EC);
  static const Color secondaryToneBorder = Color(0xFFF3DFC7);
  static const Color secondaryToneShelf = Color(0xFFE3C6A3);
  static const Color tertiaryToneBorder = Color(0xFFFBD6CF);
  static const Color tertiaryToneShelf = Color(0xFFEDB9AF);
  static const Color tertiaryToneSurface = Color(0xFFFEE9E6);

  /// The shelf under a dialog card: the level-up mockup's
  /// `0 8px 0 #e5d8c3`.
  static const Color dialogShelf = Color(0xFFE5D8C3);

  /// Behind sheets and dialogs: DESIGN.md "Floating Overlays", a warm
  /// vignette `rgba(43, 33, 24, 0.45)`.
  static const Color scrim = Color(0x732B2118);

  /// The ink every soft shadow is mixed from (the mockups'
  /// `rgba(35,26,17,…)`); only [AppShadows] reads it.
  static const Color shadowInk = Color(0xFF231A11);
}
