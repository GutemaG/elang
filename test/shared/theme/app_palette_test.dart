// One palette by role (022-light-and-dark-themes, bolt 066): the light
// palette keeps every colour it had, and the theme, the tones and the
// shadows are built from whichever palette they are given.

import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_theme_context.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/distinct_palette.dart';

void main() {
  test('the light palette is the chosen mix, P2 · S7 · T2 · N10 · C3', () {
    final p = AppPalette.light;
    final expected = <String, (Color, int)>{
      'surface': (p.surface, 0xFFF8F7FC),
      'surfaceDim': (p.surfaceDim, 0xFFE3E1EA),
      'surfaceContainerLowest': (p.surfaceContainerLowest, 0xFFFFFFFF),
      'surfaceContainerLow': (p.surfaceContainerLow, 0xFFF3F1F9),
      'surfaceContainer': (p.surfaceContainer, 0xFFEEECF7),
      'surfaceContainerHigh': (p.surfaceContainerHigh, 0xFFEAE7F4),
      'surfaceContainerHighest': (p.surfaceContainerHighest, 0xFFDCD9E9),
      'onSurface': (p.onSurface, 0xFF18122B),
      'onSurfaceVariant': (p.onSurfaceVariant, 0xFF3C364F),
      'inverseSurface': (p.inverseSurface, 0xFF332D44),
      'inverseOnSurface': (p.inverseOnSurface, 0xFFF3F1F9),
      'outline': (p.outline, 0xFF767089),
      'outlineVariant': (p.outlineVariant, 0xFFC6C3D5),
      'primary': (p.primary, 0xFF1D652E),
      'onPrimary': (p.onPrimary, 0xFFFFFFFF),
      'primaryContainer': (p.primaryContainer, 0xFF247B38),
      'onPrimaryContainer': (p.onPrimaryContainer, 0xFFB0DAB9),
      'primaryFixed': (p.primaryFixed, 0xFFB6DDBF),
      'primaryFixedDim': (p.primaryFixedDim, 0xFF8CCA9A),
      'primaryShelf': (p.primaryShelf, 0xFF195627),
      'secondary': (p.secondary, 0xFF225CAA),
      'onSecondary': (p.onSecondary, 0xFFFFFFFF),
      'secondaryContainer': (p.secondaryContainer, 0xFF2A73D5),
      'onSecondaryContainer': (p.onSecondaryContainer, 0xFFFFFFFF),
      'secondaryFixed': (p.secondaryFixed, 0xFFBFD5F2),
      'secondaryBrand': (p.secondaryBrand, 0xFF2565BB),
      'secondaryShelf': (p.secondaryShelf, 0xFF1D5195),
      'tertiary': (p.tertiary, 0xFF993A1F),
      'onTertiary': (p.onTertiary, 0xFFFFFFFF),
      'tertiaryContainer': (p.tertiaryContainer, 0xFFBD4826),
      'onTertiaryContainer': (p.onTertiaryContainer, 0xFFF5BFB0),
      'tertiaryFixed': (p.tertiaryFixed, 0xFFFADDD5),
      'tertiaryBrand': (p.tertiaryBrand, 0xFFE4572E),
      'tertiaryShelf': (p.tertiaryShelf, 0xFFA03D20),
      'error': (p.error, 0xFFBA1A1A),
      'onError': (p.onError, 0xFFFFFFFF),
      'errorContainer': (p.errorContainer, 0xFFFFDAD6),
      'onErrorContainer': (p.onErrorContainer, 0xFF93000A),
      'cardBorder': (p.cardBorder, 0xFFE6E3F2),
      'cardShelf': (p.cardShelf, 0xFFD4D1DF),
      'answerSelectedFace': (p.answerSelectedFace, 0xFFE5EEFA),
      'answerCorrectFace': (p.answerCorrectFace, 0xFFEAF5ED),
      'answerIncorrectFace': (p.answerIncorrectFace, 0xFFFDF2EE),
      'chosenFace': (p.chosenFace, 0xFFEEF7F0),
      'tileBorder': (p.tileBorder, 0xFFE6E3F2),
      'tileShelf': (p.tileShelf, 0xFFC6C3D0),
      'lockedNodeFace': (p.lockedNodeFace, 0xFFECEAF4),
      'lockedNodeIcon': (p.lockedNodeIcon, 0xFFB0ACBE),
      'activeNodeShelf': (p.activeNodeShelf, 0xFF2056A0),
      'streak': (p.streak, 0xFFFF7A1A),
      'streakRim': (p.streakRim, 0xFFFFA25F),
      'gem': (p.gem, 0xFF14B8A6),
      'xp': (p.xp, 0xFF38BDF8),
      'textMuted': (p.textMuted, 0xFF67617C),
      'track': (p.track, 0xFFE4E1EF),
      'primaryToneBorder': (p.primaryToneBorder, 0xFFD1EAD7),
      'primaryToneShelf': (p.primaryToneShelf, 0xFFB0DAB9),
      'primaryToneSurface': (p.primaryToneSurface, 0xFFE6F3E9),
      'secondaryToneBorder': (p.secondaryToneBorder, 0xFFBBD2F2),
      'secondaryToneShelf': (p.secondaryToneShelf, 0xFF8AB2E8),
      'tertiaryToneBorder': (p.tertiaryToneBorder, 0xFFF8D5CB),
      'tertiaryToneShelf': (p.tertiaryToneShelf, 0xFFF4BCAB),
      'tertiaryToneSurface': (p.tertiaryToneSurface, 0xFFFCEEEA),
      'dialogShelf': (p.dialogShelf, 0xFFCDC9DA),
      'scrim': (p.scrim, 0x7318122B),
      'shadowInk': (p.shadowInk, 0xFF18122B),
    };
    expect(expected, hasLength(66));
    for (final MapEntry(key: name, value: (colour, argb)) in expected.entries) {
      expect(colour.toARGB32(), argb, reason: name);
    }
  });

  test('a theme change switches palettes halfway, never blending', () {
    final other = distinctPalette();
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
      final p = distinctPalette();
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
      final p = distinctPalette();
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
      expect(theme.snackBarTheme.actionTextColor, p.inverseAction);
    });

    test('light is the light palette', () {
      expect(AppTheme.light.extension<AppPalette>(), same(AppPalette.light));
      expect(AppTheme.light.brightness, Brightness.light);
    });
  });

  group('tones', () {
    test('each tone takes its colours from the given palette', () {
      final p = distinctPalette();
      final primary = AppTone.primary.colorsIn(p);
      expect(primary.border, p.primaryToneBorder);
      expect(primary.fillShelf, p.primaryShelf);
      expect(primary.selectedFace, p.chosenFace);
      expect(AppTone.neutral.colorsIn(p).border, p.cardBorder);
      expect(AppTone.secondary.colorsIn(p).icon, p.secondaryContainer);
      expect(AppTone.tertiary.colorsIn(p).fillShelf, p.tertiaryFillShelf);
    });

    test('in light, every tone has the chosen colours', () {
      const expected = {
        AppTone.neutral: [
          0xFFE6E3F2, 0xFFD4D1DF, 0xFFEEECF7, 0xFF3C364F, 0xFF18122B, //
          0xFF332D44, 0xFFF3F1F9, 0xFF18122B, 0xFFF3F1F9,
        ],
        AppTone.primary: [
          0xFFD1EAD7, 0xFFB0DAB9, 0xFFE6F3E9, 0xFF247B38, 0xFF1D652E, //
          0xFF247B38, 0xFFFFFFFF, 0xFF195627, 0xFFEEF7F0,
        ],
        AppTone.secondary: [
          0xFFBBD2F2, 0xFF8AB2E8, 0xFFEEECF7, 0xFF2A73D5, 0xFF225CAA, //
          0xFF2A73D5, 0xFFFFFFFF, 0xFF1D5195, 0xFFE5EEFA,
        ],
        AppTone.tertiary: [
          0xFFF8D5CB, 0xFFF4BCAB, 0xFFFCEEEA, 0xFFBD4826, 0xFFBD4826, //
          0xFFBD4826, 0xFFFFFFFF, 0xFF993A1F, 0xFFFDF2EE,
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
      final p = distinctPalette();
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

    test('in light, are drawn from the light palette', () {
      final s = AppShadows.of(AppPalette.light);

      expect(s.card, [
        const BoxShadow(color: Color(0xFFD4D1DF), offset: Offset(0, 4)),
        BoxShadow(
          color: const Color(0xFF18122B).withValues(alpha: 0.08),
          offset: const Offset(0, 4),
          blurRadius: 16,
        ),
      ]);
      expect(s.dialog.first.color.toARGB32(), 0xFFCDC9DA);
      expect(s.dialog.first.offset, const Offset(0, 8));
      expect(s.tile.first.offset, const Offset(0, AppShadows.tileShelfDepth));
    });
  });
}
