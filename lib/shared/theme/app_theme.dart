import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the app-wide [ThemeData] from the Highland Pulse tokens in
/// [AppColors] / [AppTypography] / `app_spacing.dart`, so screens read
/// `Theme.of(context)` or the token classes directly instead of hardcoding
/// hex values or font sizes.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      inversePrimary: AppColors.primaryFixedDim,
      surfaceTint: AppColors.primaryContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
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
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      chipTheme: chipTheme,
      switchTheme: switchTheme,
      snackBarTheme: snackBarTheme,
    );
  }

  /// Choice chips ("I speak"): white stadiums with a 2 px border; a chosen
  /// one takes the chosen-option face, a green border and a check, like a
  /// selected option card.
  static ChipThemeData get chipTheme {
    return ChipThemeData(
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.optionChosen
            : AppColors.surfaceContainerLowest,
      ),
      checkmarkColor: AppColors.primaryContainer,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryContainer
              : AppColors.cardBorderDefault,
          width: 2,
        ),
      ),
      shape: const StadiumBorder(),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => AppTypography.labelMd.copyWith(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.onSurface,
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
  static SwitchThemeData get switchTheme {
    Color faded(Set<WidgetState> states, Color color) =>
        states.contains(WidgetState.disabled)
        ? color.withValues(alpha: 0.4)
        : color;
    bool on(Set<WidgetState> states) => states.contains(WidgetState.selected);
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            faded(states, on(states) ? AppColors.onPrimary : AppColors.outline),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => faded(
          states,
          on(states)
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerHighest,
        ),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => faded(
          states,
          on(states) ? AppColors.primaryContainer : AppColors.outline,
        ),
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
    );
  }

  /// Short messages ("Couldn't switch course"): a floating dark card with
  /// the base radius, clear of the page's docked buttons.
  static SnackBarThemeData get snackBarTheme {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.inverseSurface,
      contentTextStyle: AppTypography.bodyMd.copyWith(
        color: AppColors.inverseOnSurface,
      ),
      actionTextColor: AppColors.primaryFixedDim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.base),
      ),
      elevation: 0,
    );
  }
}
