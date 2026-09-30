import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the app-wide [ThemeData] from a Highland Pulse palette
/// ([AppPalette]) with [AppTypography] and `app_spacing.dart`, so screens
/// read `Theme.of(context)` or `context.colors` instead of hardcoding hex
/// values or font sizes. The palette rides along as a theme extension.
abstract final class AppTheme {
  static ThemeData get light =>
      fromPalette(AppPalette.light, brightness: Brightness.light);

  /// The whole theme drawn in [p].
  static ThemeData fromPalette(AppPalette p, {required Brightness brightness}) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.secondary,
      onSecondary: p.onSecondary,
      secondaryContainer: p.secondaryContainer,
      onSecondaryContainer: p.onSecondaryContainer,
      tertiary: p.tertiary,
      onTertiary: p.onTertiary,
      tertiaryContainer: p.tertiaryContainer,
      onTertiaryContainer: p.onTertiaryContainer,
      error: p.error,
      onError: p.onError,
      errorContainer: p.errorContainer,
      onErrorContainer: p.onErrorContainer,
      surface: p.surface,
      onSurface: p.onSurface,
      surfaceContainerLowest: p.surfaceContainerLowest,
      surfaceContainerLow: p.surfaceContainerLow,
      surfaceContainer: p.surfaceContainer,
      surfaceContainerHigh: p.surfaceContainerHigh,
      surfaceContainerHighest: p.surfaceContainerHighest,
      onSurfaceVariant: p.onSurfaceVariant,
      outline: p.outline,
      outlineVariant: p.outlineVariant,
      inverseSurface: p.inverseSurface,
      onInverseSurface: p.inverseOnSurface,
      inversePrimary: p.primaryFixedDim,
      surfaceTint: p.primaryContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.surface,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLg,
        headlineLarge: AppTypography.headlineLg,
        headlineMedium: AppTypography.headlineMd,
        headlineSmall: AppTypography.headlineSm,
        bodyLarge: AppTypography.bodyLg,
        bodyMedium: AppTypography.bodyMd,
        bodySmall: AppTypography.bodySm,
        labelLarge: AppTypography.labelLg,
        labelMedium: AppTypography.labelMd,
        labelSmall: AppTypography.labelSm,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.onSurface,
        elevation: 0,
      ),
      chipTheme: chipThemeFor(p),
      switchTheme: switchThemeFor(p),
      snackBarTheme: snackBarThemeFor(p),
      extensions: [p],
    );
  }

  /// [chipThemeFor] in the light palette.
  static ChipThemeData get chipTheme => chipThemeFor(AppPalette.light);

  /// Choice chips ("I speak"): white stadiums with a 2 px border; a chosen
  /// one takes the chosen-option face, a green border and a check, like a
  /// selected option card.
  static ChipThemeData chipThemeFor(AppPalette p) {
    return ChipThemeData(
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? p.chosenFace
            : p.surfaceContainerLowest,
      ),
      checkmarkColor: p.primaryContainer,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? p.primaryContainer
              : p.cardBorder,
          width: 2,
        ),
      ),
      shape: const StadiumBorder(),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => AppTypography.labelMd.copyWith(
          color: states.contains(WidgetState.selected)
              ? p.primary
              : p.onSurface,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceXs,
        vertical: AppSpacing.space2xs,
      ),
      elevation: 0,
      pressElevation: 0,
      showCheckmark: true,
    );
  }

  /// Settings switches (Notifications, Sound): on is a green track with a
  /// white thumb, as in Duolingo's settings; off is a grey outlined track.
  /// Disabled keeps the same colours, faded.
  static SwitchThemeData switchThemeFor(AppPalette p) {
    Color faded(Set<WidgetState> states, Color color) =>
        states.contains(WidgetState.disabled)
        ? color.withValues(alpha: 0.4)
        : color;
    bool on(Set<WidgetState> states) => states.contains(WidgetState.selected);
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => faded(states, on(states) ? p.onPrimary : p.outline),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => faded(
          states,
          on(states) ? p.primaryContainer : p.surfaceContainerHighest,
        ),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => faded(states, on(states) ? p.primaryContainer : p.outline),
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
    );
  }

  /// Short messages ("Couldn't switch course"): a floating dark card with
  /// the base radius, clear of the page's docked buttons.
  static SnackBarThemeData snackBarThemeFor(AppPalette p) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.inverseSurface,
      contentTextStyle: AppTypography.bodyMd.copyWith(
        color: p.inverseOnSurface,
      ),
      actionTextColor: p.primaryFixedDim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.base),
      ),
      elevation: 0,
    );
  }
}
