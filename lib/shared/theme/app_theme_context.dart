/// The short way for a widget to read the current theme's colours
/// (022-light-and-dark-themes, FR-3): `context.colors.onSurface`,
/// `context.tone(AppTone.primary).border`, `context.shadows.card`.
library;

import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_shadows.dart';
import 'app_tone.dart';

export 'app_palette.dart' show AppPalette;

extension AppThemeContext on BuildContext {
  /// The current theme's palette, or the light one when the theme carries
  /// none (a bare `MaterialApp` in a widget test).
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  /// [tone]'s colours in the current palette.
  ToneColors tone(AppTone tone) => tone.colorsIn(colors);

  /// The shadows built from the current palette.
  PaletteShadows get shadows => AppShadows.of(colors);
}
