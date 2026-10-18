// The gallery's Colours page and light/dark switch
// (022-light-and-dark-themes, bolt 069, story 005, FR-6).

import 'dart:io';

import 'package:elang/shared/gallery/component_gallery.dart';
import 'package:elang/shared/gallery/gallery_colours.dart';
import 'package:elang/shared/theme/app_palette.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/distinct_palette.dart';

void main() {
  group('AppPalette.roles', () {
    test('names every role once', () {
      final source = File('lib/shared/theme/app_palette.dart')
          .readAsStringSync();
      final fields = RegExp(
        r'^    required this\.(\w+),',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!).toList();
      final listed = [
        for (final (_, roles) in AppPalette.roles)
          for (final (name, _) in roles) name,
      ];

      expect(fields, hasLength(74));
      expect(listed, fields, reason: 'in the order of the fields');
    });

    test("each entry reads its own role", () {
      final p = distinctPalette();
      final read = [
        for (final (_, roles) in AppPalette.roles)
          for (final (_, get) in roles) get(p),
      ];
      expect(read.toSet(), hasLength(read.length));
      expect(read.first, p.surface);
      expect(read.last, p.shadowInk);
    });

    test('all is both palettes by name', () {
      expect(AppPalette.all, {
        'Light': AppPalette.light,
        'Dark': AppPalette.dark,
      });
    });
  });

  testWidgets('the Colours page shows each role in light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(child: ColoursGallerySection()),
        ),
      ),
    );

    for (final (_, roles) in AppPalette.roles) {
      for (final (name, _) in roles) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    }
    // The page, light and dark.
    expect(find.text('#F8F7FC'), findsWidgets);
    expect(find.text('#0F0B1A'), findsWidgets);
    // A bolt 068 role, clear in light and a soft white in dark.
    expect(find.text('#FFFFFF @00'), findsOneWidget);
    expect(find.text('#F5F2FD'), findsOneWidget);
    // One light and one dark swatch per role.
    expect(find.text('Light'), findsNWidgets(74));
    expect(find.text('Dark'), findsNWidgets(74));
  });

  testWidgets('the switch redraws the gallery in the other theme and back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ComponentGalleryApp());
    await tester.pump();

    AppPalette current() =>
        Theme.of(tester.element(find.text('AppButton')))
            .extension<AppPalette>()!;

    expect(current(), same(AppPalette.light));
    expect(find.byTooltip('Dark theme'), findsOneWidget);

    await tester.tap(find.byKey(ComponentGallery.themeSwitchKey));
    // The gallery's spinners never settle; the theme change takes 200 ms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(current(), same(AppPalette.dark));
    expect(find.byTooltip('Light theme'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(ComponentGallery.themeSwitchKey));
    // The gallery's spinners never settle; the theme change takes 200 ms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(current(), same(AppPalette.light));
  });

  testWidgets('the whole gallery lays out in dark at 360×640 with 1.3x '
      'text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: const ComponentGallery(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('AppButton'), findsOneWidget);
  });
}
