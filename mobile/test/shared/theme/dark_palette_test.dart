// The dark palette and theme (022-light-and-dark-themes, bolt 068, story
// 003, FR-4): the dark values start from the intent's table, the roles
// split off for dark keep light as it was, and the phone's bars follow the
// theme.

import 'package:elang/shared/theme/app_palette.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the dark palette is the chosen mix on its night page', () {
    final p = AppPalette.dark;
    final expected = <String, (Color, int)>{
      'page': (p.surface, 0xFF0F0B1A),
      'card face': (p.surfaceContainerLowest, 0xFF181227),
      'card border': (p.cardBorder, 0xFF2B2340),
      'card shelf': (p.cardShelf, 0xFF08060E),
      'text': (p.onSurface, 0xFFEFEAFB),
      'muted text': (p.textMuted, 0xFFA39BBB),
      'green text': (p.primary, 0xFF6FD38A),
      'green button': (p.primaryContainer, 0xFF247B38),
      'green button shelf': (p.primaryShelf, 0xFF123E1C),
      'gold text': (p.secondary, 0xFF6AA8F7),
      'terracotta text': (p.tertiary, 0xFFFF8A66),
      'correct answer face': (p.answerCorrectFace, 0xFF1C2E2E),
      'wrong answer face': (p.answerIncorrectFace, 0xFF412028),
    };
    for (final MapEntry(key: name, value: (colour, argb)) in expected.entries) {
      expect(colour.toARGB32(), argb, reason: name);
    }
  });

  test('streak, gem and XP keep their bright accents in dark', () {
    final light = AppPalette.light, dark = AppPalette.dark;
    expect(dark.streak, light.streak);
    expect(dark.streakRim, light.streakRim);
    expect(dark.gem, light.gem);
    expect(dark.xp, light.xp);
  });

  test('the roles split off for dark keep the light colour of the role they '
      'replace', () {
    final p = AppPalette.light;
    expect(p.primaryAccent, p.primaryContainer);
    expect(p.tertiaryAccent, p.tertiaryBrand);
    expect(p.tertiaryToneInk, p.tertiaryContainer);
    expect(p.secondaryButtonEdge, p.secondary);
    expect(p.answerLine, p.tileShelf);
    expect(p.inverseAction, p.primaryFixedDim);
    expect(p.tertiaryFillShelf, p.tertiary);
  });

  test('in dark, the split roles are light enough to read on the page', () {
    final p = AppPalette.dark;
    for (final (name, colour) in [
      ('primaryAccent', p.primaryAccent),
      ('tertiaryAccent', p.tertiaryAccent),
      ('tertiaryToneInk', p.tertiaryToneInk),
    ]) {
      expect(
        colour.computeLuminance(),
        greaterThan(p.surface.computeLuminance() * 10),
        reason: name,
      );
    }
    final tertiary = AppTone.tertiary.colorsIn(p);
    expect(tertiary.ink, p.tertiaryToneInk);
    expect(tertiary.icon, p.tertiaryToneInk);
    expect(AppTone.primary.colorsIn(p).icon, p.primaryAccent);
  });

  test('AppTheme.dark is the dark palette, dark', () {
    final theme = AppTheme.dark;
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.extension<AppPalette>(), same(AppPalette.dark));
    expect(theme.scaffoldBackgroundColor, AppPalette.dark.surface);
  });

  group('system bars', () {
    test('light icons on the dark theme, dark icons on the light one', () {
      final dark = AppTheme.systemBarsFor(
        AppPalette.dark,
        brightness: Brightness.dark,
      );
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      expect(dark.systemNavigationBarColor, AppPalette.dark.surface);

      final light = AppTheme.systemBarsFor(
        AppPalette.light,
        brightness: Brightness.light,
      );
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(light.systemNavigationBarIconBrightness, Brightness.dark);
      expect(light.systemNavigationBarColor, AppPalette.light.surface);
    });

    test('an app bar sets them from its theme', () {
      expect(
        AppTheme.dark.appBarTheme.systemOverlayStyle,
        AppTheme.systemBarsFor(AppPalette.dark, brightness: Brightness.dark),
      );
      expect(
        AppTheme.light.appBarTheme.systemOverlayStyle,
        AppTheme.systemBarsFor(AppPalette.light, brightness: Brightness.light),
      );
    });

    testWidgets('a screen with no app bar still gets them from the app', (
      tester,
    ) async {
      // What main.dart's builder does for every screen.
      Widget app(ThemeMode mode) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemBarsFor(
            Theme.of(context).extension<AppPalette>()!,
            brightness: Theme.of(context).brightness,
          ),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.expand()),
      );

      SystemUiOverlayStyle annotated() => tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value;

      await tester.pumpWidget(app(ThemeMode.dark));
      expect(annotated().statusBarIconBrightness, Brightness.light);

      await tester.pumpWidget(app(ThemeMode.light));
      await tester.pumpAndSettle();
      expect(annotated().statusBarIconBrightness, Brightness.dark);
    });
  });
}
