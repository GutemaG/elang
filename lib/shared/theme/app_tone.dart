/// Highland Pulse tones: the one table every toned piece reads its colours
/// from (cards, stat cards, banners, badges, icon badges, sheet titles), so
/// "the green card" and "the green badge" are the same green everywhere.
///
/// A tone is a name; its colours come from a palette ([AppTone.colorsIn]),
/// so each theme has its own greens (022-light-and-dark-themes, FR-2).
/// Screens use `context.tone(AppTone.primary)`.
///
/// Values come from the lesson-complete mockup's three stat cards; neutral
/// is DESIGN.md "Tactile Level 1".
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'app_palette.dart';

enum AppTone {
  neutral,

  /// Highland Acacia: progress, success, the learner's own choices.
  primary,

  /// Simien Gold: rewards, XP, the daily goal.
  secondary,

  /// Rift Terracotta: streaks, beans, warnings and endings.
  tertiary;

  /// This tone's colours in [p].
  ToneColors colorsIn(AppPalette p) => switch (this) {
    AppTone.neutral => ToneColors(
      border: p.cardBorder,
      shelf: p.cardShelf,
      surface: p.surfaceContainer,
      icon: p.onSurfaceVariant,
      ink: p.onSurface,
      fill: p.inverseSurface,
      onFill: p.inverseOnSurface,
      fillShelf: p.shadowInk,
      selectedFace: p.surfaceContainerLow,
    ),
    AppTone.primary => ToneColors(
      border: p.primaryToneBorder,
      shelf: p.primaryToneShelf,
      surface: p.primaryToneSurface,
      icon: p.primaryContainer,
      ink: p.primary,
      fill: p.primaryContainer,
      onFill: p.onPrimary,
      fillShelf: p.primaryShelf,
      selectedFace: p.chosenFace,
    ),
    AppTone.secondary => ToneColors(
      border: p.secondaryToneBorder,
      shelf: p.secondaryToneShelf,
      surface: p.surfaceContainer,
      icon: p.secondaryContainer,
      ink: p.secondary,
      fill: p.secondaryContainer,
      onFill: p.onSecondaryContainer,
      fillShelf: p.secondaryShelf,
      selectedFace: p.answerSelectedFace,
    ),
    AppTone.tertiary => ToneColors(
      border: p.tertiaryToneBorder,
      shelf: p.tertiaryToneShelf,
      surface: p.tertiaryToneSurface,
      icon: p.tertiaryContainer,
      ink: p.tertiaryContainer,
      fill: p.tertiaryContainer,
      onFill: p.onTertiary,
      fillShelf: p.tertiary,
      selectedFace: p.answerIncorrectFace,
    ),
  };

  // The light colours under the old names, until every screen reads
  // `context.tone(...)` (bolt 067 removes these).
  ToneColors get _light => colorsIn(AppPalette.light);
  Color get border => _light.border;
  Color get shelf => _light.shelf;
  Color get surface => _light.surface;
  Color get icon => _light.icon;
  Color get ink => _light.ink;
  Color get fill => _light.fill;
  Color get onFill => _light.onFill;
  Color get fillShelf => _light.fillShelf;
  Color get selectedFace => _light.selectedFace;
}

/// One tone's colours in one palette.
@immutable
class ToneColors {
  const ToneColors({
    required this.border,
    required this.shelf,
    required this.surface,
    required this.icon,
    required this.ink,
    required this.fill,
    required this.onFill,
    required this.fillShelf,
    required this.selectedFace,
  });

  /// A card's 2 px border.
  final Color border;

  /// A card's shelf, under the border.
  final Color shelf;

  /// The circle behind an icon (`IconBadge`), and a banner's face.
  final Color surface;

  /// Icons, and a selected card's border.
  final Color icon;

  /// Values and titles.
  final Color ink;

  /// A filled badge (the "+1 TODAY" ribbon) and a progress fill.
  final Color fill;

  /// Text on [fill].
  final Color onFill;

  /// The shelf under a card filled with [fill]: the tone's darker bevel
  /// (the dashboard's section header, 020-dashboard-section-header).
  final Color fillShelf;

  /// A selected card's face.
  final Color selectedFace;

  @override
  bool operator ==(Object other) =>
      other is ToneColors &&
      other.border == border &&
      other.shelf == shelf &&
      other.surface == surface &&
      other.icon == icon &&
      other.ink == ink &&
      other.fill == fill &&
      other.onFill == onFill &&
      other.fillShelf == fillShelf &&
      other.selectedFace == selectedFace;

  @override
  int get hashCode => Object.hash(
    border,
    shelf,
    surface,
    icon,
    ink,
    fill,
    onFill,
    fillShelf,
    selectedFace,
  );
}
