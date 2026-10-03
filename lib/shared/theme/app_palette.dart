/// Highland Pulse colours: every colour the app draws, by role, in one place
/// (022-light-and-dark-themes, FR-1).
///
/// **To change the colours**, edit `palette_seed.dart`: a handful of seed
/// colours (primary, secondary, tertiary, right and wrong, the page and
/// text of each theme, the game icons). [AppPalette.lightFrom] and
/// [AppPalette.darkFrom] work out every role below from them, and every
/// screen, tone, shadow and the Material theme follow. The gallery's
/// Colours page shows both themes side by side.
///
/// **To add a role**, add the field, its constructor parameter, how each
/// factory works it out and an entry in [AppPalette.roles]. Every
/// parameter is required, so a palette missing a role does not compile.
///
/// No other file in `lib/` holds a colour value
/// (`test/design/design_rules_test.dart`). Screens read the current theme's
/// palette with `context.colors` (`app_theme_context.dart`).
///
/// The roles and shapes follow
/// `stich-screens/extracted/stitch_ethiopian_language_learning_app/highland_pulse/DESIGN.md`.
library;

import 'package:flutter/material.dart';

import 'palette_maths.dart';
import 'palette_seed.dart';

export 'palette_seed.dart';

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
    required this.primaryAccent,
    required this.tertiaryAccent,
    required this.tertiaryToneInk,
    required this.secondaryButtonEdge,
    required this.answerLine,
    required this.inverseAction,
    required this.pictureMat,
    required this.tertiaryFillShelf,
    required this.dialogShelf,
    required this.scrim,
    required this.shadowInk,
  });

  /// The light palette, built from [PaletteSeed.active].
  static final AppPalette light = AppPalette.lightFrom(PaletteSeed.active);

  /// The dark palette, built from [PaletteSeed.active].
  static final AppPalette dark = AppPalette.darkFrom(PaletteSeed.active);

  /// Every light role worked out from [seed]. Fills that carry white text
  /// are the seed colour deepened just enough to read at 4.5:1; tints mix
  /// it toward white.
  factory AppPalette.lightFrom(PaletteSeed seed) {
    final n = seed.light;
    final p = seed.primary, t = seed.tertiary;
    final s = PaletteMaths.labelledFill(seed.secondary);
    final button = _toward(
      _toward(p, _black, n.page, 4.9),
      _black,
      _white,
      4.9,
    );
    final greenText = _toward(p, _black, n.page, 6.5);
    final secondaryText = _toward(_mix(s, _black, 0.2), _black, n.page, 5.0);
    final redFill = _toward(t, _black, _white, 5.0);
    final redText = _toward(t, _black, n.page, 6.5);
    final tileShelf = _mix(n.border, _black, 0.14);
    final inverse = _mix(n.ink, n.page, 0.12);
    final fixedDim = _toward(_mix(p, _white, 0.45), _white, inverse, 4.6);
    return AppPalette(
      surface: n.page,
      surfaceDim: _mix(n.locked, _black, 0.04),
      surfaceContainerLowest: n.card,
      surfaceContainerLow: _mix(n.page, n.border, 0.3),
      surfaceContainer: _mix(n.page, n.border, 0.55),
      surfaceContainerHigh: _mix(n.page, n.border, 0.8),
      surfaceContainerHighest: _mix(n.border, n.muted, 0.08),
      onSurface: n.ink,
      onSurfaceVariant: _mix(n.ink, n.muted, 0.45),
      inverseSurface: inverse,
      inverseOnSurface: _mix(n.page, n.border, 0.3),
      outline: _mix(n.muted, n.page, 0.1),
      outlineVariant: _mix(n.border, n.muted, 0.25),
      primary: greenText,
      onPrimary: _white,
      primaryContainer: button,
      onPrimaryContainer: _mix(p, _white, 0.62),
      primaryFixed: _mix(p, _white, 0.65),
      primaryFixedDim: fixedDim,
      primaryShelf: _mix(button, _black, 0.3),
      secondary: secondaryText,
      onSecondary: PaletteMaths.textOn(s),
      secondaryContainer: s,
      onSecondaryContainer: PaletteMaths.textOn(s),
      secondaryFixed: _mix(s, _white, 0.7),
      secondaryBrand: _mix(s, _black, 0.12),
      secondaryShelf: _mix(s, _black, 0.3),
      tertiary: redText,
      onTertiary: _white,
      tertiaryContainer: redFill,
      onTertiaryContainer: _mix(t, _white, 0.62),
      tertiaryFixed: _mix(t, _white, 0.8),
      tertiaryBrand: t,
      tertiaryShelf: _mix(t, _black, 0.3),
      error: const Color(0xFFBA1A1A),
      onError: _white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF93000A),
      cardBorder: n.border,
      cardShelf: _mix(n.border, _black, 0.08),
      answerSelectedFace: _mix(s, _white, 0.88),
      answerCorrectFace: _mix(seed.correct, _white, 0.9),
      answerIncorrectFace: _mix(seed.wrong, _white, 0.92),
      chosenFace: _mix(p, _white, 0.92),
      tileBorder: n.border,
      tileShelf: tileShelf,
      lockedNodeFace: n.locked,
      lockedNodeIcon: _mix(n.locked, n.muted, 0.45),
      activeNodeShelf: _mix(s, _black, 0.25),
      streak: seed.streak,
      streakRim: _mix(seed.streak, _white, 0.3),
      gem: seed.gem,
      xp: seed.xp,
      textMuted: n.muted,
      track: n.track,
      primaryToneBorder: _mix(p, _white, 0.78),
      primaryToneShelf: _mix(p, _white, 0.62),
      primaryToneSurface: _mix(p, _white, 0.88),
      secondaryToneBorder: _mix(s, _white, 0.68),
      secondaryToneShelf: _mix(s, _white, 0.45),
      tertiaryToneBorder: _mix(t, _white, 0.75),
      tertiaryToneShelf: _mix(t, _white, 0.6),
      tertiaryToneSurface: _mix(t, _white, 0.9),
      primaryAccent: button,
      tertiaryAccent: t,
      tertiaryToneInk: redFill,
      secondaryButtonEdge: secondaryText,
      answerLine: tileShelf,
      inverseAction: fixedDim,
      pictureMat: const Color(0x00FFFFFF),
      tertiaryFillShelf: redText,
      dialogShelf: _mix(n.border, n.muted, 0.2),
      scrim: n.ink.withAlpha(0x73),
      shadowInk: n.ink,
    );
  }

  /// Every dark role worked out from [seed]. Fills keep their light
  /// colours where white text still reads; texts, surfaces and shelves
  /// change. Every shelf is darker than the face above it, and the neutral
  /// ones than the page, since soft shadows barely show on it.
  factory AppPalette.darkFrom(PaletteSeed seed) {
    final n = seed.dark;
    final p = seed.primary, t = seed.tertiary;
    final s = PaletteMaths.labelledFill(seed.secondary);
    final button = _toward(
      _toward(p, _black, seed.light.page, 4.9),
      _black,
      _white,
      4.9,
    );
    final redFill = _toward(t, _black, _white, 4.6);
    final pageShelf = _mix(n.page, _black, 0.45);
    return AppPalette(
      surface: n.page,
      surfaceDim: n.locked,
      surfaceContainerLowest: n.card,
      surfaceContainerLow: _mix(n.card, n.border, 0.25),
      surfaceContainer: _mix(n.card, n.border, 0.45),
      surfaceContainerHigh: _mix(n.card, n.border, 0.7),
      surfaceContainerHighest: _mix(n.border, n.muted, 0.1),
      onSurface: n.ink,
      onSurfaceVariant: _mix(n.ink, n.muted, 0.5),
      inverseSurface: n.ink,
      inverseOnSurface: _mix(n.card, n.border, 0.6),
      outline: _mix(n.muted, n.page, 0.1),
      outlineVariant: _mix(n.border, n.muted, 0.3),
      primary: seed.primaryOnDark,
      onPrimary: _white,
      primaryContainer: button,
      onPrimaryContainer: _mix(p, _white, 0.7),
      primaryFixed: _mix(p, _white, 0.65),
      primaryFixedDim: _mix(p, _white, 0.45),
      primaryShelf: _mix(button, _black, 0.5),
      secondary: seed.secondaryOnDark,
      onSecondary: PaletteMaths.textOn(s),
      secondaryContainer: s,
      onSecondaryContainer: PaletteMaths.textOn(s),
      secondaryFixed: _mix(s, n.card, 0.75),
      secondaryBrand: _mix(s, _black, 0.12),
      secondaryShelf: _mix(s, _black, 0.35),
      tertiary: seed.tertiaryOnDark,
      onTertiary: _white,
      tertiaryContainer: redFill,
      onTertiaryContainer: _mix(t, _white, 0.75),
      tertiaryFixed: _mix(t, n.card, 0.7),
      tertiaryBrand: redFill,
      tertiaryShelf: _mix(redFill, _black, 0.3),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      cardBorder: n.border,
      cardShelf: pageShelf,
      answerSelectedFace: _mix(s, n.card, 0.8),
      answerCorrectFace: _mix(seed.correct, n.card, 0.8),
      answerIncorrectFace: _mix(seed.wrong, n.card, 0.8),
      chosenFace: _mix(p, n.card, 0.84),
      tileBorder: _mix(n.border, n.muted, 0.08),
      tileShelf: pageShelf,
      lockedNodeFace: n.locked,
      lockedNodeIcon: _mix(n.page, _black, 0.3),
      activeNodeShelf: _mix(s, _black, 0.35),
      streak: seed.streak,
      streakRim: _mix(seed.streak, _white, 0.3),
      gem: seed.gem,
      xp: seed.xp,
      textMuted: n.muted,
      track: n.border,
      primaryToneBorder: _mix(p, n.card, 0.7),
      primaryToneShelf: _mix(p, _black, 0.95),
      primaryToneSurface: _mix(p, n.card, 0.78),
      secondaryToneBorder: _mix(s, n.card, 0.72),
      secondaryToneShelf: _mix(s, _black, 0.95),
      tertiaryToneBorder: _mix(t, n.card, 0.7),
      tertiaryToneShelf: _mix(t, _black, 0.95),
      tertiaryToneSurface: _mix(t, n.card, 0.8),
      primaryAccent: _mix(seed.primaryOnDark, p, 0.2),
      tertiaryAccent: seed.tertiaryOnDark,
      tertiaryToneInk: _mix(seed.tertiaryOnDark, _white, 0.35),
      secondaryButtonEdge: _mix(s, _black, 0.45),
      answerLine: _mix(n.border, n.muted, 0.35),
      inverseAction: _toward(p, _black, n.ink, 4.6),
      pictureMat: _mix(n.ink, _white, 0.4),
      tertiaryFillShelf: _mix(redFill, _black, 0.45),
      dialogShelf: _mix(n.page, _black, 0.6),
      scrim: const Color(0x99000000),
      shadowInk: _black,
    );
  }

  static const _white = PaletteMaths.white;
  static const _black = PaletteMaths.black;
  static const _mix = PaletteMaths.mix;
  static const _toward = PaletteMaths.toward;

  /// Every role by group, with its name, in the order of the fields:
  /// what the gallery's Colours page lists. A test checks it names every
  /// role once, so **a new role goes here too**.
  static final List<(String, List<(String, Color Function(AppPalette))>)>
  roles = [
    (
      'Surfaces',
      [
        ('surface', (p) => p.surface),
        ('surfaceDim', (p) => p.surfaceDim),
        ('surfaceContainerLowest', (p) => p.surfaceContainerLowest),
        ('surfaceContainerLow', (p) => p.surfaceContainerLow),
        ('surfaceContainer', (p) => p.surfaceContainer),
        ('surfaceContainerHigh', (p) => p.surfaceContainerHigh),
        ('surfaceContainerHighest', (p) => p.surfaceContainerHighest),
      ],
    ),
    (
      'Text on surfaces',
      [
        ('onSurface', (p) => p.onSurface),
        ('onSurfaceVariant', (p) => p.onSurfaceVariant),
        ('inverseSurface', (p) => p.inverseSurface),
        ('inverseOnSurface', (p) => p.inverseOnSurface),
      ],
    ),
    (
      'Lines',
      [
        ('outline', (p) => p.outline),
        ('outlineVariant', (p) => p.outlineVariant),
      ],
    ),
    (
      'Primary: Adey Abeba green',
      [
        ('primary', (p) => p.primary),
        ('onPrimary', (p) => p.onPrimary),
        ('primaryContainer', (p) => p.primaryContainer),
        ('onPrimaryContainer', (p) => p.onPrimaryContainer),
        ('primaryFixed', (p) => p.primaryFixed),
        ('primaryFixedDim', (p) => p.primaryFixedDim),
        ('primaryShelf', (p) => p.primaryShelf),
      ],
    ),
    (
      'Secondary: ocean blue',
      [
        ('secondary', (p) => p.secondary),
        ('onSecondary', (p) => p.onSecondary),
        ('secondaryContainer', (p) => p.secondaryContainer),
        ('onSecondaryContainer', (p) => p.onSecondaryContainer),
        ('secondaryFixed', (p) => p.secondaryFixed),
        ('secondaryBrand', (p) => p.secondaryBrand),
        ('secondaryShelf', (p) => p.secondaryShelf),
      ],
    ),
    (
      'Tertiary: Meskel bonfire',
      [
        ('tertiary', (p) => p.tertiary),
        ('onTertiary', (p) => p.onTertiary),
        ('tertiaryContainer', (p) => p.tertiaryContainer),
        ('onTertiaryContainer', (p) => p.onTertiaryContainer),
        ('tertiaryFixed', (p) => p.tertiaryFixed),
        ('tertiaryBrand', (p) => p.tertiaryBrand),
        ('tertiaryShelf', (p) => p.tertiaryShelf),
      ],
    ),
    (
      'Error',
      [
        ('error', (p) => p.error),
        ('onError', (p) => p.onError),
        ('errorContainer', (p) => p.errorContainer),
        ('onErrorContainer', (p) => p.onErrorContainer),
      ],
    ),
    (
      'Cards',
      [('cardBorder', (p) => p.cardBorder), ('cardShelf', (p) => p.cardShelf)],
    ),
    (
      'Answers and choices',
      [
        ('answerSelectedFace', (p) => p.answerSelectedFace),
        ('answerCorrectFace', (p) => p.answerCorrectFace),
        ('answerIncorrectFace', (p) => p.answerIncorrectFace),
        ('chosenFace', (p) => p.chosenFace),
        ('tileBorder', (p) => p.tileBorder),
        ('tileShelf', (p) => p.tileShelf),
      ],
    ),
    (
      'Path nodes',
      [
        ('lockedNodeFace', (p) => p.lockedNodeFace),
        ('lockedNodeIcon', (p) => p.lockedNodeIcon),
        ('activeNodeShelf', (p) => p.activeNodeShelf),
      ],
    ),
    (
      'Gamification',
      [
        ('streak', (p) => p.streak),
        ('streakRim', (p) => p.streakRim),
        ('gem', (p) => p.gem),
        ('xp', (p) => p.xp),
      ],
    ),
    (
      'Muted text and tracks',
      [('textMuted', (p) => p.textMuted), ('track', (p) => p.track)],
    ),
    (
      'Tones',
      [
        ('primaryToneBorder', (p) => p.primaryToneBorder),
        ('primaryToneShelf', (p) => p.primaryToneShelf),
        ('primaryToneSurface', (p) => p.primaryToneSurface),
        ('secondaryToneBorder', (p) => p.secondaryToneBorder),
        ('secondaryToneShelf', (p) => p.secondaryToneShelf),
        ('tertiaryToneBorder', (p) => p.tertiaryToneBorder),
        ('tertiaryToneShelf', (p) => p.tertiaryToneShelf),
        ('tertiaryToneSurface', (p) => p.tertiaryToneSurface),
      ],
    ),
    (
      'Accents on surfaces',
      [
        ('primaryAccent', (p) => p.primaryAccent),
        ('tertiaryAccent', (p) => p.tertiaryAccent),
        ('tertiaryToneInk', (p) => p.tertiaryToneInk),
        ('secondaryButtonEdge', (p) => p.secondaryButtonEdge),
        ('answerLine', (p) => p.answerLine),
        ('inverseAction', (p) => p.inverseAction),
        ('pictureMat', (p) => p.pictureMat),
        ('tertiaryFillShelf', (p) => p.tertiaryFillShelf),
      ],
    ),
    (
      'Overlays and shadows',
      [
        ('dialogShelf', (p) => p.dialogShelf),
        ('scrim', (p) => p.scrim),
        ('shadowInk', (p) => p.shadowInk),
      ],
    ),
  ];

  /// Both palettes by name, for the gallery's side-by-side Colours page.
  static final Map<String, AppPalette> all = {'Light': light, 'Dark': dark};

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

  // Primary: Adey Abeba green ------------------------------------------------

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

  // Secondary: ocean blue --------------------------------------------------

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

  // Tertiary: Meskel bonfire ----------------------------------------------

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

  // Accents on surfaces --------------------------------------------------
  //
  // Roles that share a value with a fill in light but need their own in
  // dark, where a fill's colour is too dark to read on the page.

  /// Green text and icons drawn on a surface: a completed title, a
  /// correct answer, the green tone's icons. In light it is the green of
  /// fills; in dark a lighter green, since a fill's green is too dark to
  /// read on a dark page.
  final Color primaryAccent;

  /// Red text and icons drawn on a surface: a wrong answer, the bean
  /// countdown. In light it is the red button's face.
  final Color tertiaryAccent;

  /// The terracotta tone's text and icons. In light it is the terracotta
  /// fill.
  final Color tertiaryToneInk;

  /// The gold button's border and shelf. In light it is the gold text
  /// colour; in dark gold text is light, and a shelf must stay dark.
  final Color secondaryButtonEdge;

  /// The line under an unanswered slot ("_____"). In light it is the
  /// choice tile's rim; in dark that rim is darker than the page, and the
  /// line must show on it.
  final Color answerLine;

  /// A snack bar's action, on [inverseSurface].
  final Color inverseAction;

  /// Behind a lesson picture, so pictures drawn on white don't glare in
  /// dark. Transparent in light: the tile's face shows through.
  final Color pictureMat;

  /// The shelf under a terracotta-filled card. In light it is the
  /// terracotta text colour; in dark that is light.
  final Color tertiaryFillShelf;

  // Overlays and shadows ---------------------------------------------------

  /// The shelf under a dialog card: the level-up mockup's `0 8px 0 #e5d8c3`.
  final Color dialogShelf;

  /// Behind sheets and dialogs: DESIGN.md "Floating Overlays", a warm
  /// vignette `rgba(43, 33, 24, 0.45)`.
  final Color scrim;

  /// The ink every soft shadow is mixed from (the mockups'
  /// `rgba(35,26,17,…)`); only the shadows read it.
  final Color shadowInk;

  /// A label in the secondary colour on a white button (the active path
  /// popover's): the fill itself when white text reads on it, so the fill
  /// is dark enough, else the dark text a light fill such as a yellow
  /// takes.
  Color get secondaryOnWhite => onSecondaryContainer == onPrimary
      ? secondaryContainer
      : onSecondaryContainer;

  /// Palettes are built from a seed, never copied with changes, so this
  /// returns the palette unchanged; it exists because [ThemeExtension]
  /// requires it.
  @override
  AppPalette copyWith() => this;

  /// Switches at the halfway point of a theme change instead of blending
  /// each role, so a role never has to be listed here too.
  @override
  AppPalette lerp(covariant AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
