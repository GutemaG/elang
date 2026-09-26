/// Highland Pulse tones: the one table every toned piece reads its colours
/// from (cards, stat cards, banners, badges, icon badges, sheet titles), so
/// "the green card" and "the green badge" are the same green everywhere.
///
/// Values come from the lesson-complete mockup's three stat cards; neutral
/// is DESIGN.md "Tactile Level 1".
library;

import 'package:flutter/painting.dart';

import 'app_colors.dart';

enum AppTone {
  neutral(
    border: AppColors.cardBorderDefault,
    shelf: AppColors.cardBevelDefault,
    surface: AppColors.surfaceContainer,
    icon: AppColors.onSurfaceVariant,
    ink: AppColors.onSurface,
    fill: AppColors.inverseSurface,
    onFill: AppColors.inverseOnSurface,
    fillShelf: AppColors.shadowInk,
    selectedFace: AppColors.surfaceContainerLow,
  ),

  /// Highland Acacia: progress, success, the learner's own choices.
  primary(
    border: AppColors.primaryToneBorder,
    shelf: AppColors.primaryToneShelf,
    surface: AppColors.primaryToneSurface,
    icon: AppColors.primaryContainer,
    ink: AppColors.primary,
    fill: AppColors.primaryContainer,
    onFill: AppColors.onPrimary,
    fillShelf: AppColors.primaryBevel,
    selectedFace: AppColors.optionChosen,
  ),

  /// Simien Gold: rewards, XP, the daily goal.
  secondary(
    border: AppColors.secondaryToneBorder,
    shelf: AppColors.secondaryToneShelf,
    surface: AppColors.surfaceContainer,
    icon: AppColors.secondaryContainer,
    ink: AppColors.secondary,
    fill: AppColors.secondaryContainer,
    onFill: AppColors.onSecondaryContainer,
    fillShelf: AppColors.secondaryBevel,
    selectedFace: AppColors.answerSelected,
  ),

  /// Rift Terracotta: streaks, beans, warnings and endings.
  tertiary(
    border: AppColors.tertiaryToneBorder,
    shelf: AppColors.tertiaryToneShelf,
    surface: AppColors.tertiaryToneSurface,
    icon: AppColors.tertiaryContainer,
    ink: AppColors.tertiaryContainer,
    fill: AppColors.tertiaryContainer,
    onFill: AppColors.onTertiary,
    fillShelf: AppColors.tertiary,
    selectedFace: AppColors.answerIncorrect,
  );

  const AppTone({
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
}
