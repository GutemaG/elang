/// Highland Pulse colours: every colour the app draws, by role, in one place
/// (022-light-and-dark-themes, FR-1).
///
/// **To change a colour**, edit its value in [AppPalette.light] (and in the
/// dark palette, once it exists); every screen, tone, shadow and the
/// Material theme follow.
///
/// **To add a role**, add the field, its constructor parameter and a value
/// in each palette. Every parameter is required, so a palette missing a role
/// does not compile.
///
/// No other file in `lib/` holds a colour value
/// (`test/design/design_rules_test.dart`). Screens read the current theme's
/// palette with `context.colors` (`app_theme_context.dart`).
///
/// Light values come from
/// `stich-screens/extracted/stitch_ethiopian_language_learning_app/highland_pulse/DESIGN.md`
/// and the Stitch mockups.
library;

import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.surface,
    required this.surfaceDim,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.primaryShelf,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryFixed,
    required this.secondaryBrand,
    required this.secondaryShelf,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryFixed,
    required this.tertiaryBrand,
    required this.tertiaryShelf,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.cardBorder,
    required this.cardShelf,
    required this.answerSelectedFace,
    required this.answerCorrectFace,
    required this.answerIncorrectFace,
    required this.chosenFace,
    required this.tileBorder,
    required this.tileShelf,
    required this.lockedNodeFace,
    required this.lockedNodeIcon,
    required this.activeNodeShelf,
    required this.streak,
    required this.streakRim,
    required this.gem,
    required this.xp,
    required this.textMuted,
    required this.track,
    required this.primaryToneBorder,
    required this.primaryToneShelf,
    required this.primaryToneSurface,
    required this.secondaryToneBorder,
    required this.secondaryToneShelf,
    required this.tertiaryToneBorder,
    required this.tertiaryToneShelf,
    required this.tertiaryToneSurface,
    required this.dialogShelf,
    required this.scrim,
    required this.shadowInk,
  });

  /// The light palette: Highland Pulse as designed.
  static const AppPalette light = AppPalette(
    // Surfaces
    surface: Color(0xFFFFF8F5),
    surfaceDim: Color(0xFFE9D7C8),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFF1E8),
    surfaceContainer: Color(0xFFFEEADC),
    surfaceContainerHigh: Color(0xFFF8E5D6),
    surfaceContainerHighest: Color(0xFFF2DFD1),
    // Text on surfaces
    onSurface: Color(0xFF231A11),
    onSurfaceVariant: Color(0xFF404942),
    inverseSurface: Color(0xFF392E25),
    inverseOnSurface: Color(0xFFFFEEE1),
    // Lines
    outline: Color(0xFF707971),
    outlineVariant: Color(0xFFBFC9BF),
    // Primary: Highland Acacia
    primary: Color(0xFF004527),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF1B5E3B),
    onPrimaryContainer: Color(0xFF92D5A9),
    primaryFixed: Color(0xFFAEF2C4),
    primaryFixedDim: Color(0xFF92D5A9),
    primaryShelf: Color(0xFF124027),
    // Secondary: Simien Gold
    secondary: Color(0xFF8D4F00),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFA03B),
    onSecondaryContainer: Color(0xFF6C3B00),
    secondaryFixed: Color(0xFFFFDCC0),
    secondaryBrand: Color(0xFFE08722),
    secondaryShelf: Color(0xFFA85E0E),
    // Tertiary: Rift Terracotta
    tertiary: Color(0xFF7D0301),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF9F2115),
    onTertiaryContainer: Color(0xFFFFB4A7),
    tertiaryFixed: Color(0xFFFFDAD4),
    tertiaryBrand: Color(0xFFD84A38),
    tertiaryShelf: Color(0xFF9F2B1D),
    // Error
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    // Cards
    cardBorder: Color(0xFFEDE5D8),
    cardShelf: Color(0xFFE2D7C5),
    // Answers and choices
    answerSelectedFace: Color(0xFFFFF7ED),
    answerCorrectFace: Color(0xFFE8F8F0),
    answerIncorrectFace: Color(0xFFFDF0EE),
    chosenFace: Color(0xFFF0F7F2),
    tileBorder: Color(0xFFE5DDD0),
    tileShelf: Color(0xFFD5CCBD),
    // Learning-map nodes
    lockedNodeFace: Color(0xFFE8DFD3),
    lockedNodeIcon: Color(0xFFBAAFA1),
    activeNodeShelf: Color(0xFFC47318),
    // Gamification accents
    streak: Color(0xFFFF5A1F),
    streakRim: Color(0xFFFFA726),
    gem: Color(0xFF10B981),
    xp: Color(0xFF0EA5E9),
    // Muted text and tracks
    textMuted: Color(0xFF786A5E),
    track: Color(0xFFE2D9CC),
    // Tones (see `app_tone.dart`)
    primaryToneBorder: Color(0xFFD1E8D9),
    primaryToneShelf: Color(0xFFB9D6C3),
    primaryToneSurface: Color(0xFFE5F5EC),
    secondaryToneBorder: Color(0xFFF3DFC7),
    secondaryToneShelf: Color(0xFFE3C6A3),
    tertiaryToneBorder: Color(0xFFFBD6CF),
    tertiaryToneShelf: Color(0xFFEDB9AF),
    tertiaryToneSurface: Color(0xFFFEE9E6),
    // Overlays and shadows
    dialogShelf: Color(0xFFE5D8C3),
    scrim: Color(0x732B2118),
    shadowInk: Color(0xFF231A11),
  );

  // Surfaces ---------------------------------------------------------------

  /// The page behind everything.
  final Color surface;

  /// A locked path node's face.
  final Color surfaceDim;

  /// Cards, tiles and the white secondary button.
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  // Text on surfaces -------------------------------------------------------

  /// Body text and titles.
  final Color onSurface;

  /// Secondary text and neutral icons.
  final Color onSurfaceVariant;

  /// Snack bars and the neutral filled badge.
  final Color inverseSurface;
  final Color inverseOnSurface;

  // Lines ------------------------------------------------------------------

  final Color outline;
  final Color outlineVariant;

  // Primary: Highland Acacia ------------------------------------------------

  /// Green text.
  final Color primary;

  /// Text on a green fill.
  final Color onPrimary;

  /// The green of buttons, fills and selected borders.
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;

  /// The shelf under a green button (DESIGN.md's `#124027` bevel).
  final Color primaryShelf;

  // Secondary: Simien Gold --------------------------------------------------

  /// Gold text.
  final Color secondary;
  final Color onSecondary;

  /// The gold of buttons and fills.
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryFixed;
  final Color secondaryBrand;

  /// The shelf under a gold button.
  final Color secondaryShelf;

  // Tertiary: Rift Terracotta ----------------------------------------------

  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryBrand;

  /// The shelf under a terracotta button.
  final Color tertiaryShelf;

  // Error ------------------------------------------------------------------

  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  // Cards ------------------------------------------------------------------

  /// A neutral card's 2 px border ("Tactile Level 1").
  final Color cardBorder;

  /// The shelf under a neutral card.
  final Color cardShelf;

  // Answers and choices: DESIGN.md "Choice & Match Tiles" ------------------

  /// Selected, not yet graded: soft gold tint.
  final Color answerSelectedFace;

  /// Graded correct: soft mint.
  final Color answerCorrectFace;

  /// Graded incorrect: soft blush.
  final Color answerIncorrectFace;

  /// A chosen option card (language, daily goal): the daily-goal mockup's
  /// `bg-[#F0F7F2]`.
  final Color chosenFace;

  /// A choice tile at rest: "2px #E5DDD0 border, 3px #D5CCBD bottom rim".
  /// The rim is also the neutral shelf of the white secondary button.
  final Color tileBorder;
  final Color tileShelf;

  // Learning-map nodes: DESIGN.md component 2 ------------------------------

  final Color lockedNodeFace;
  final Color lockedNodeIcon;

  /// The active node's shelf, and the selected tile's rim.
  final Color activeNodeShelf;

  // Gamification accents: DESIGN.md "Gamification Electric Accents" --------

  final Color streak;
  final Color streakRim;
  final Color gem;
  final Color xp;

  // Muted text and tracks --------------------------------------------------

  /// Subheads, timestamps and pronunciation lines: DESIGN.md "Text Muted".
  final Color textMuted;

  /// Progress-track lanes and path connectors.
  final Color track;

  // Tones: the lesson-complete stat cards ----------------------------------
  //
  // Borders and icon surfaces are the mockup's (`#D1E8D9`, `#E5F5EC`,
  // `#F3DFC7`, `#FBD6CF`, `#FEE9E6`). No mockup draws a tinted shelf, so each
  // shelf is its border one step darker, as [cardShelf] is to [cardBorder].

  final Color primaryToneBorder;
  final Color primaryToneShelf;
  final Color primaryToneSurface;
  final Color secondaryToneBorder;
  final Color secondaryToneShelf;
  final Color tertiaryToneBorder;
  final Color tertiaryToneShelf;
  final Color tertiaryToneSurface;

  // Overlays and shadows ---------------------------------------------------

  /// The shelf under a dialog card: the level-up mockup's `0 8px 0 #e5d8c3`.
  final Color dialogShelf;

  /// Behind sheets and dialogs: DESIGN.md "Floating Overlays", a warm
  /// vignette `rgba(43, 33, 24, 0.45)`.
  final Color scrim;

  /// The ink every soft shadow is mixed from (the mockups'
  /// `rgba(35,26,17,…)`); only the shadows read it.
  final Color shadowInk;

  /// Palettes are edited here, never copied with changes, so this returns
  /// the palette unchanged; it exists because [ThemeExtension] requires it.
  @override
  AppPalette copyWith() => this;

  /// Switches at the halfway point of a theme change instead of blending
  /// each role, so a role never has to be listed here too.
  @override
  AppPalette lerp(covariant AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
