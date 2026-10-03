/// The few colours the whole app is painted from.
///
/// **To change the app's colours, edit this file only.** Every role in
/// [AppPalette] (buttons, shelves, tints, answer faces, the dark theme) is
/// worked out from a [PaletteSeed] in `app_palette.dart`, so changing a
/// seed colour here changes every screen in both themes.
///
/// - To try another palette, point [PaletteSeed.active] at another preset.
/// - To make a new one, copy a preset, give it a name and change its
///   colours. `test/shared/theme/palette_contrast_test.dart` checks every
///   preset stays readable, and says which pair falls short if one doesn't.
///
/// Fills that carry white text are deepened automatically, just enough to
/// read at 4.5:1, so a seed can be the colour as designed.
///
/// The presets come from the palette study (2026-10-03): Adey Abeba's green
/// and bonfire, Addis Neon's page and game icons, and a choice of secondary.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The page, text and line colours of one theme.
@immutable
class NeutralSeed {
  const NeutralSeed({
    required this.page,
    required this.card,
    required this.border,
    required this.ink,
    required this.muted,
    required this.track,
    required this.locked,
  });

  /// Behind everything.
  final Color page;

  /// Cards, tiles and the white button.
  final Color card;

  /// Card and tile borders.
  final Color border;

  /// Body text and titles.
  final Color ink;

  /// Subheads, timestamps and pronunciation lines.
  final Color muted;

  /// Progress-track lanes and path connectors.
  final Color track;

  /// A locked path node's face.
  final Color locked;
}

/// One palette, as the handful of colours it is designed from.
@immutable
class PaletteSeed {
  const PaletteSeed({
    required this.name,
    required this.primary,
    required this.primaryOnDark,
    required this.secondary,
    required this.secondaryOnDark,
    required this.tertiary,
    required this.tertiaryOnDark,
    required this.correct,
    required this.wrong,
    required this.light,
    required this.dark,
    required this.streak,
    required this.gem,
    required this.xp,
  });

  /// Shown in the gallery's Colours page.
  final String name;

  /// Main buttons, finished lessons, progress.
  final Color primary;

  /// Primary text and icons on the dark page.
  final Color primaryOnDark;

  /// The current lesson, a selected answer, XP and rewards.
  final Color secondary;

  /// Secondary text and icons on the dark page.
  final Color secondaryOnDark;

  /// Hearts, "new word" badges, streak and warning cards.
  final Color tertiary;

  /// Tertiary text and icons on the dark page.
  final Color tertiaryOnDark;

  /// A right answer.
  final Color correct;

  /// A wrong answer.
  final Color wrong;

  /// The light theme's page, text and lines.
  final NeutralSeed light;

  /// The dark theme's page, text and lines.
  final NeutralSeed dark;

  /// The streak flame, the gem and the XP bolt, the same in both themes.
  final Color streak;
  final Color gem;
  final Color xp;

  /// The palette the app draws. Change this to switch the whole app.
  static const PaletteSeed active = adeyOcean;

  /// Every preset, so the contrast test can check each one.
  static const List<PaletteSeed> presets = [adeyOcean, adeyAmber, adeyIndigo];

  /// Meadow green, ocean blue and bonfire on Addis Neon's cool page
  /// (`P2 · S7 · T2 · N10 · C3`): what the app uses.
  static const PaletteSeed adeyOcean = PaletteSeed(
    name: 'Adey Abeba, ocean blue',
    primary: Color(0xFF2E9E48),
    primaryOnDark: Color(0xFF6FD38A),
    secondary: Color(0xFF2F80ED),
    secondaryOnDark: Color(0xFF6AA8F7),
    tertiary: Color(0xFFE4572E),
    tertiaryOnDark: Color(0xFFFF8A66),
    correct: Color(0xFF2E9E48),
    wrong: Color(0xFFE4572E),
    light: _addisNeonLight,
    dark: _addisNeonDark,
    streak: Color(0xFFFF7A1A),
    gem: Color(0xFF14B8A6),
    xp: Color(0xFF38BDF8),
  );

  /// The same with Simien Night's campfire amber (`P2 · S7 · T2 · N10`).
  static const PaletteSeed adeyAmber = PaletteSeed(
    name: 'Adey Abeba, campfire amber',
    primary: Color(0xFF2E9E48),
    primaryOnDark: Color(0xFF6FD38A),
    secondary: Color(0xFFFFB547),
    secondaryOnDark: Color(0xFFFFC66E),
    tertiary: Color(0xFFE4572E),
    tertiaryOnDark: Color(0xFFFF8A66),
    correct: Color(0xFF2E9E48),
    wrong: Color(0xFFE4572E),
    light: _addisNeonLight,
    dark: _addisNeonDark,
    streak: Color(0xFFFF7A1A),
    gem: Color(0xFF14B8A6),
    xp: Color(0xFF38BDF8),
  );

  /// The same with an indigo secondary (`P2 · S7 · T2 · N10 · C2`).
  static const PaletteSeed adeyIndigo = PaletteSeed(
    name: 'Adey Abeba, indigo',
    primary: Color(0xFF2E9E48),
    primaryOnDark: Color(0xFF6FD38A),
    secondary: Color(0xFF4F5BD5),
    secondaryOnDark: Color(0xFF8C95F0),
    tertiary: Color(0xFFE4572E),
    tertiaryOnDark: Color(0xFFFF8A66),
    correct: Color(0xFF2E9E48),
    wrong: Color(0xFFE4572E),
    light: _addisNeonLight,
    dark: _addisNeonDark,
    streak: Color(0xFFFF7A1A),
    gem: Color(0xFF14B8A6),
    xp: Color(0xFF38BDF8),
  );

  /// Addis Neon's cool violet-grey page.
  static const NeutralSeed _addisNeonLight = NeutralSeed(
    page: Color(0xFFF8F7FC),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE6E3F2),
    ink: Color(0xFF18122B),
    muted: Color(0xFF67617C),
    track: Color(0xFFE4E1EF),
    locked: Color(0xFFECEAF4),
  );

  /// Addis Neon's night page.
  static const NeutralSeed _addisNeonDark = NeutralSeed(
    page: Color(0xFF0F0B1A),
    card: Color(0xFF181227),
    border: Color(0xFF2B2340),
    ink: Color(0xFFEFEAFB),
    muted: Color(0xFFA39BBB),
    track: Color(0xFF2B2340),
    locked: Color(0xFF221B35),
  );
}
