/// The old colour names, kept only until every screen reads the theme
/// (022-light-and-dark-themes, bolt 067 deletes this file).
///
/// Each name forwards to its role in [AppPalette.light] and holds no value
/// of its own: colours are changed in `app_palette.dart`. Where a name
/// differs from its role, this file is the old-to-new map.
library;

import 'package:flutter/painting.dart';

import 'app_palette.dart';

abstract final class AppColors {
  static const AppPalette _p = AppPalette.light;

  // Core surfaces
  static Color get surface => _p.surface;
  static Color get surfaceDim => _p.surfaceDim;
  static Color get surfaceContainerLowest => _p.surfaceContainerLowest;
  static Color get surfaceContainerLow => _p.surfaceContainerLow;
  static Color get surfaceContainer => _p.surfaceContainer;
  static Color get surfaceContainerHigh => _p.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _p.surfaceContainerHighest;

  // Text / on-colors
  static Color get onSurface => _p.onSurface;
  static Color get onSurfaceVariant => _p.onSurfaceVariant;
  static Color get inverseSurface => _p.inverseSurface;
  static Color get inverseOnSurface => _p.inverseOnSurface;

  // Outline
  static Color get outline => _p.outline;
  static Color get outlineVariant => _p.outlineVariant;

  // Primary
  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get primaryContainer => _p.primaryContainer;
  static Color get onPrimaryContainer => _p.onPrimaryContainer;
  static Color get primaryFixed => _p.primaryFixed;
  static Color get primaryFixedDim => _p.primaryFixedDim;
  static Color get primaryBevel => _p.primaryShelf;

  // Secondary
  static Color get secondary => _p.secondary;
  static Color get onSecondary => _p.onSecondary;
  static Color get secondaryContainer => _p.secondaryContainer;
  static Color get onSecondaryContainer => _p.onSecondaryContainer;
  static Color get secondaryFixed => _p.secondaryFixed;
  static Color get secondaryBrand => _p.secondaryBrand;
  static Color get secondaryBevel => _p.secondaryShelf;

  // Tertiary
  static Color get tertiary => _p.tertiary;
  static Color get onTertiary => _p.onTertiary;
  static Color get tertiaryContainer => _p.tertiaryContainer;
  static Color get onTertiaryContainer => _p.onTertiaryContainer;
  static Color get tertiaryFixed => _p.tertiaryFixed;
  static Color get tertiaryBrand => _p.tertiaryBrand;
  static Color get tertiaryBevel => _p.tertiaryShelf;

  // Error
  static Color get error => _p.error;
  static Color get onError => _p.onError;
  static Color get errorContainer => _p.errorContainer;
  static Color get onErrorContainer => _p.onErrorContainer;

  // Background: merged into `surface`.
  static Color get background => _p.surface;

  // Cards
  static Color get cardBorderDefault => _p.cardBorder;
  static Color get cardBevelDefault => _p.cardShelf;

  // Answers and choices
  static Color get answerSelected => _p.answerSelectedFace;
  static Color get answerCorrect => _p.answerCorrectFace;
  static Color get answerIncorrect => _p.answerIncorrectFace;
  static Color get optionChosen => _p.chosenFace;
  static Color get tileBorder => _p.tileBorder;
  static Color get tileShelf => _p.tileShelf;

  // Learning-map nodes
  static Color get lockedNode => _p.lockedNodeFace;
  static Color get lockedNodeIcon => _p.lockedNodeIcon;
  static Color get activeNodeShelf => _p.activeNodeShelf;

  // Gamification accents
  static Color get streak => _p.streak;
  static Color get streakRim => _p.streakRim;
  static Color get gem => _p.gem;
  static Color get xp => _p.xp;

  static Color get textMuted => _p.textMuted;
  static Color get track => _p.track;

  // Tones
  static Color get primaryToneBorder => _p.primaryToneBorder;
  static Color get primaryToneShelf => _p.primaryToneShelf;
  static Color get primaryToneSurface => _p.primaryToneSurface;
  static Color get secondaryToneBorder => _p.secondaryToneBorder;
  static Color get secondaryToneShelf => _p.secondaryToneShelf;
  static Color get tertiaryToneBorder => _p.tertiaryToneBorder;
  static Color get tertiaryToneShelf => _p.tertiaryToneShelf;
  static Color get tertiaryToneSurface => _p.tertiaryToneSurface;

  // Overlays and shadows
  static Color get dialogShelf => _p.dialogShelf;
  static Color get scrim => _p.scrim;
  static Color get shadowInk => _p.shadowInk;
}
