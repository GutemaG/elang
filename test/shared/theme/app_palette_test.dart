// One palette by role (022-light-and-dark-themes, bolt 066): the light
// palette keeps every colour it had, and the theme, the tones and the
// shadows are built from whichever palette they are given.

import 'package:elang/shared/theme/app_palette.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_theme_context.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A palette in which every role has its own colour, so a piece that reads
/// the wrong role, or the light palette, is caught.
AppPalette _distinct() {
  var n = 0;
  Color next() => Color(0xFF000000 + (++n) * 0x010203);
  return AppPalette(
    surface: next(),
    surfaceDim: next(),
    surfaceContainerLowest: next(),
    surfaceContainerLow: next(),
    surfaceContainer: next(),
    surfaceContainerHigh: next(),
    surfaceContainerHighest: next(),
    onSurface: next(),
    onSurfaceVariant: next(),
    inverseSurface: next(),
    inverseOnSurface: next(),
    outline: next(),
    outlineVariant: next(),
    primary: next(),
    onPrimary: next(),
    primaryContainer: next(),
    onPrimaryContainer: next(),
    primaryFixed: next(),
    primaryFixedDim: next(),
    primaryShelf: next(),
    secondary: next(),
    onSecondary: next(),
    secondaryContainer: next(),
    onSecondaryContainer: next(),
    secondaryFixed: next(),
    secondaryBrand: next(),
    secondaryShelf: next(),
    tertiary: next(),
    onTertiary: next(),
    tertiaryContainer: next(),
    onTertiaryContainer: next(),
    tertiaryFixed: next(),
    tertiaryBrand: next(),
    tertiaryShelf: next(),
    error: next(),
    onError: next(),
    errorContainer: next(),
    onErrorContainer: next(),
    cardBorder: next(),
    cardShelf: next(),
    answerSelectedFace: next(),
    answerCorrectFace: next(),
    answerIncorrectFace: next(),
    chosenFace: next(),
    tileBorder: next(),
    tileShelf: next(),
    lockedNodeFace: next(),
    lockedNodeIcon: next(),
    activeNodeShelf: next(),
    streak: next(),
    streakRim: next(),
    gem: next(),
    xp: next(),
    textMuted: next(),
    track: next(),
    primaryToneBorder: next(),
    primaryToneShelf: next(),
    primaryToneSurface: next(),
    secondaryToneBorder: next(),
    secondaryToneShelf: next(),
    tertiaryToneBorder: next(),
    tertiaryToneShelf: next(),
    tertiaryToneSurface: next(),
    dialogShelf: next(),
    scrim: next(),
    shadowInk: next(),
  );
}

void main() {
  test('the light palette keeps every colour it had before bolt 066', () {
    const p = AppPalette.light;
    final expected = <String, (Color, int)>{
      'surface': (p.surface, 0xFFFFF8F5),
      'surfaceDim': (p.surfaceDim, 0xFFE9D7C8),
      'surfaceContainerLowest': (p.surfaceContainerLowest, 0xFFFFFFFF),
      'surfaceContainerLow': (p.surfaceContainerLow, 0xFFFFF1E8),
      'surfaceContainer': (p.surfaceContainer, 0xFFFEEADC),
      'surfaceContainerHigh': (p.surfaceContainerHigh, 0xFFF8E5D6),
      'surfaceContainerHighest': (p.surfaceContainerHighest, 0xFFF2DFD1),
      'onSurface': (p.onSurface, 0xFF231A11),
      'onSurfaceVariant': (p.onSurfaceVariant, 0xFF404942),
      'inverseSurface': (p.inverseSurface, 0xFF392E25),
      'inverseOnSurface': (p.inverseOnSurface, 0xFFFFEEE1),
      'outline': (p.outline, 0xFF707971),
      'outlineVariant': (p.outlineVariant, 0xFFBFC9BF),
      'primary': (p.primary, 0xFF004527),
      'onPrimary': (p.onPrimary, 0xFFFFFFFF),
      'primaryContainer': (p.primaryContainer, 0xFF1B5E3B),
      'onPrimaryContainer': (p.onPrimaryContainer, 0xFF92D5A9),
      'primaryFixed': (p.primaryFixed, 0xFFAEF2C4),
      'primaryFixedDim': (p.primaryFixedDim, 0xFF92D5A9),
      'primaryShelf': (p.primaryShelf, 0xFF124027),
      'secondary': (p.secondary, 0xFF8D4F00),
      'onSecondary': (p.onSecondary, 0xFFFFFFFF),
      'secondaryContainer': (p.secondaryContainer, 0xFFFFA03B),
      'onSecondaryContainer': (p.onSecondaryContainer, 0xFF6C3B00),
      'secondaryFixed': (p.secondaryFixed, 0xFFFFDCC0),
      'secondaryBrand': (p.secondaryBrand, 0xFFE08722),
      'secondaryShelf': (p.secondaryShelf, 0xFFA85E0E),
      'tertiary': (p.tertiary, 0xFF7D0301),
      'onTertiary': (p.onTertiary, 0xFFFFFFFF),
      'tertiaryContainer': (p.tertiaryContainer, 0xFF9F2115),
      'onTertiaryContainer': (p.onTertiaryContainer, 0xFFFFB4A7),
      'tertiaryFixed': (p.tertiaryFixed, 0xFFFFDAD4),
      'tertiaryBrand': (p.tertiaryBrand, 0xFFD84A38),
      'tertiaryShelf': (p.tertiaryShelf, 0xFF9F2B1D),
      'error': (p.error, 0xFFBA1A1A),
      'onError': (p.onError, 0xFFFFFFFF),
      'errorContainer': (p.errorContainer, 0xFFFFDAD6),
      'onErrorContainer': (p.onErrorContainer, 0xFF93000A),
      'cardBorder': (p.cardBorder, 0xFFEDE5D8),
      'cardShelf': (p.cardShelf, 0xFFE2D7C5),
      'answerSelectedFace': (p.answerSelectedFace, 0xFFFFF7ED),
      'answerCorrectFace': (p.answerCorrectFace, 0xFFE8F8F0),
      'answerIncorrectFace': (p.answerIncorrectFace, 0xFFFDF0EE),
      'chosenFace': (p.chosenFace, 0xFFF0F7F2),
      'tileBorder': (p.tileBorder, 0xFFE5DDD0),
      'tileShelf': (p.tileShelf, 0xFFD5CCBD),
      'lockedNodeFace': (p.lockedNodeFace, 0xFFE8DFD3),
      'lockedNodeIcon': (p.lockedNodeIcon, 0xFFBAAFA1),
      'activeNodeShelf': (p.activeNodeShelf, 0xFFC47318),
      'streak': (p.streak, 0xFFFF5A1F),
      'streakRim': (p.streakRim, 0xFFFFA726),
      'gem': (p.gem, 0xFF10B981),
      'xp': (p.xp, 0xFF0EA5E9),
      'textMuted': (p.textMuted, 0xFF786A5E),
      'track': (p.track, 0xFFE2D9CC),
      'primaryToneBorder': (p.primaryToneBorder, 0xFFD1E8D9),
      'primaryToneShelf': (p.primaryToneShelf, 0xFFB9D6C3),
      'primaryToneSurface': (p.primaryToneSurface, 0xFFE5F5EC),
      'secondaryToneBorder': (p.secondaryToneBorder, 0xFFF3DFC7),
      'secondaryToneShelf': (p.secondaryToneShelf, 0xFFE3C6A3),
      'tertiaryToneBorder': (p.tertiaryToneBorder, 0xFFFBD6CF),
      'tertiaryToneShelf': (p.tertiaryToneShelf, 0xFFEDB9AF),
      'tertiaryToneSurface': (p.tertiaryToneSurface, 0xFFFEE9E6),
      'dialogShelf': (p.dialogShelf, 0xFFE5D8C3),
      'scrim': (p.scrim, 0x732B2118),
      'shadowInk': (p.shadowInk, 0xFF231A11),
    };
    expect(expected, hasLength(66));
    for (final MapEntry(key: name, value: (colour, argb)) in expected.entries) {
      expect(colour.toARGB32(), argb, reason: name);
    }
  });

  test('a theme change switches palettes halfway, never blending', () {
    final other = _distinct();
    expect(AppPalette.light.lerp(other, 0.49), same(AppPalette.light));
    expect(AppPalette.light.lerp(other, 0.5), same(other));
    expect(AppPalette.light.lerp(null, 1), same(AppPalette.light));
    expect(AppPalette.light.copyWith(), same(AppPalette.light));
  });

  group('context.colors', () {
    Future<BuildContext> pump(WidgetTester tester, ThemeData? theme) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('reads the palette the theme carries', (tester) async {
      final p = _distinct();
      final context = await pump(
        tester,
        AppTheme.fromPalette(p, brightness: Brightness.dark),
      );

      expect(context.colors, same(p));
      expect(context.tone(AppTone.primary), AppTone.primary.colorsIn(p));
      expect(context.shadows.card, AppShadows.of(p).card);
    });

    testWidgets('falls back to light with no palette in the theme', (
      tester,
    ) async {
      final context = await pump(tester, null);

      expect(context.colors, same(AppPalette.light));
    });
  });

  group('AppTheme.fromPalette', () {
    test('draws the Material theme in the given palette', () {
      final p = _distinct();
      final theme = AppTheme.fromPalette(p, brightness: Brightness.dark);
      const chosen = {WidgetState.selected};

      expect(theme.brightness, Brightness.dark);
      expect(theme.extension<AppPalette>(), same(p));
      expect(theme.colorScheme.primary, p.primary);
      expect(theme.colorScheme.surface, p.surface);
      expect(theme.colorScheme.onSurface, p.onSurface);
      expect(theme.colorScheme.inversePrimary, p.primaryFixedDim);
      expect(theme.scaffoldBackgroundColor, p.surface);
      expect(theme.appBarTheme.backgroundColor, p.surface);
      expect(theme.chipTheme.color!.resolve(chosen), p.chosenFace);
      expect(theme.chipTheme.color!.resolve({}), p.surfaceContainerLowest);
      expect(theme.switchTheme.trackColor!.resolve(chosen), p.primaryContainer);
      expect(theme.switchTheme.thumbColor!.resolve({}), p.outline);
      expect(theme.snackBarTheme.backgroundColor, p.inverseSurface);
      expect(theme.snackBarTheme.actionTextColor, p.primaryFixedDim);
    });

    test('light is the light palette', () {
      expect(AppTheme.light.extension<AppPalette>(), same(AppPalette.light));
      expect(AppTheme.light.brightness, Brightness.light);
    });
  });

  group('tones', () {
    test('each tone takes its colours from the given palette', () {
      final p = _distinct();
      final primary = AppTone.primary.colorsIn(p);
      expect(primary.border, p.primaryToneBorder);
      expect(primary.fillShelf, p.primaryShelf);
      expect(primary.selectedFace, p.chosenFace);
      expect(AppTone.neutral.colorsIn(p).border, p.cardBorder);
      expect(AppTone.secondary.colorsIn(p).icon, p.secondaryContainer);
      expect(AppTone.tertiary.colorsIn(p).fillShelf, p.tertiary);
    });

    test('in light, every tone keeps the colours it had', () {
      const expected = {
        AppTone.neutral: [
          0xFFEDE5D8, 0xFFE2D7C5, 0xFFFEEADC, 0xFF404942, 0xFF231A11, //
          0xFF392E25, 0xFFFFEEE1, 0xFF231A11, 0xFFFFF1E8,
        ],
        AppTone.primary: [
          0xFFD1E8D9, 0xFFB9D6C3, 0xFFE5F5EC, 0xFF1B5E3B, 0xFF004527, //
          0xFF1B5E3B, 0xFFFFFFFF, 0xFF124027, 0xFFF0F7F2,
        ],
        AppTone.secondary: [
          0xFFF3DFC7, 0xFFE3C6A3, 0xFFFEEADC, 0xFFFFA03B, 0xFF8D4F00, //
          0xFFFFA03B, 0xFF6C3B00, 0xFFA85E0E, 0xFFFFF7ED,
        ],
        AppTone.tertiary: [
          0xFFFBD6CF, 0xFFEDB9AF, 0xFFFEE9E6, 0xFF9F2115, 0xFF9F2115, //
          0xFF9F2115, 0xFFFFFFFF, 0xFF7D0301, 0xFFFDF0EE,
        ],
      };
      for (final MapEntry(key: tone, value: argbs) in expected.entries) {
        final c = tone.colorsIn(AppPalette.light);
        final actual = [
          c.border, c.shelf, c.surface, c.icon, c.ink, //
          c.fill, c.onFill, c.fillShelf, c.selectedFace,
        ].map((colour) => colour.toARGB32()).toList();
        expect(actual, argbs, reason: tone.name);
      }
    });
  });

  group('shadows', () {
    test('are built from the given palette', () {
      final p = _distinct();
      final s = AppShadows.of(p);

      expect(s.card.first.color, p.cardShelf);
      expect(s.soft.color, p.shadowInk.withValues(alpha: 0.08));
      expect(s.badge.single.color, p.cardBorder);
      expect(s.dialog.first.color, p.dialogShelf);
      expect(s.dialog.last.color, p.scrim.withValues(alpha: 0.28));
      expect(s.tile.first.color, p.tileShelf);
      expect(s.overlay.single.color, p.scrim.withValues(alpha: 0.16));
      expect(s.raised(p.primaryToneShelf).first.color, p.primaryToneShelf);
      expect(s.tileRaised(p.activeNodeShelf).last, s.tile.last);
    });

    test('in light, match the mockups as before', () {
      final s = AppShadows.of(AppPalette.light);

      expect(s.card, [
        const BoxShadow(color: Color(0xFFE2D7C5), offset: Offset(0, 4)),
        BoxShadow(
          color: const Color(0xFF231A11).withValues(alpha: 0.08),
          offset: const Offset(0, 4),
          blurRadius: 16,
        ),
      ]);
      expect(s.dialog.first.color.toARGB32(), 0xFFE5D8C3);
      expect(s.dialog.first.offset, const Offset(0, 8));
      expect(s.tile.first.offset, const Offset(0, AppShadows.tileShelfDepth));
    });
  });
}
