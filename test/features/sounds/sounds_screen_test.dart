// The Sounds tab's screen: the chart, a tap that plays and opens the
// letter's sheet, and what shows offline.

import 'package:elang/features/sounds/sound_chart_store.dart';
import 'package:elang/features/sounds/sound_charts.dart';
import 'package:elang/features/sounds/sounds_screen.dart';
import 'package:elang/shared/l10n/app_language.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sound_fixtures.dart';

class _Setup {
  final api = FakeSoundChartApi();
  final store = InMemorySoundChartStore();
  final player = FakeSoundPlayer();
  late final charts = SoundCharts(api: api, store: store);

  Widget app({Locale locale = const Locale('en')}) => MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLanguage.delegates,
    supportedLocales: AppLanguage.locales,
    home: SoundsScreen(charts: charts, language: 'am', player: player),
  );
}

Future<_Setup> _pump(
  WidgetTester tester, {
  _Setup? setup,
  Locale locale = const Locale('en'),
}) async {
  final s = setup ?? _Setup();
  await s.charts.load();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(s.app(locale: locale));
  await tester.pumpAndSettle();
  return s;
}

Finder _tile(String id) => find.byKey(SoundsScreen.tileKey(id));

void main() {
  testWidgets('shows the chart in rows under its vowel orders', (tester) async {
    await _pump(tester);

    expect(find.text('Sounds'), findsOneWidget);
    expect(find.text('Amharic · Fidel'), findsOneWidget);
    for (final order in ['e', 'u', 'i']) {
      expect(find.text(order), findsOneWidget);
    }
    expect(_tile('ha'), findsOneWidget);
    expect(find.bySemanticsLabel('ሀ, he'), findsOneWidget);
    expect(find.text('Recorded by Selam'), findsOneWidget);
    // The other group is a tap away.
    expect(_tile('lwa'), findsNothing);
    await tester.tap(find.text('Labialised'));
    await tester.pumpAndSettle();
    expect(_tile('lwa'), findsOneWidget);
  });

  testWidgets('a tap plays the letter and opens its sheet', (tester) async {
    final s = await _pump(tester);

    await tester.tap(_tile('ha'));
    await tester.pumpAndSettle();

    expect(s.player.played, ['$clip/ha.m4a']);
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('ሀገር'), findsOneWidget);
    expect(find.text('country'), findsOneWidget);

    await tester.tap(find.text('Slow'));
    await tester.pumpAndSettle();
    expect(s.player.played.last, 'slow $clip/ha.m4a');

    // The example word has its own recording.
    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    expect(s.player.played.last, '$clip/hager.m4a');

    // The rest of its family: ሁ from the same row.
    await tester.tap(find.byKey(SoundsScreen.familyKey('hu')));
    await tester.pumpAndSettle();
    expect(s.player.played.last, '$clip/hu.m4a');
    expect(find.text('Example'), findsNothing);
  });

  testWidgets('a letter said like another one says so, and plays its sound', (
    tester,
  ) async {
    final s = await _pump(tester);

    await tester.tap(_tile('hha'));
    await tester.pumpAndSettle();

    expect(find.text('Sounds the same as ሀ'), findsOneWidget);
    expect(s.player.played, ['$clip/ha.m4a']);
  });

  testWidgets('a sound that cannot play says so', (tester) async {
    final s = _Setup();
    s.player.fails = true;
    await _pump(tester, setup: s);

    await tester.tap(_tile('hu'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't play this sound."), findsOneWidget);
  });

  testWidgets('the chart saved on the phone shows offline', (tester) async {
    final s = _Setup();
    await s.charts.load();
    await s.charts.chart('am');
    final offline = _Setup()..api.offline = true;
    offline.store.files.addAll(s.store.files);

    await _pump(tester, setup: offline);

    expect(_tile('ha'), findsOneWidget);
  });

  testWidgets('offline with nothing saved: a way to try again', (tester) async {
    final s = _Setup()..api.offline = true;
    await _pump(tester, setup: s);

    expect(find.text("Couldn't load the sounds"), findsOneWidget);
    s.api.offline = false;
    await s.charts.refresh();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(_tile('ha'), findsOneWidget);
  });

  testWidgets('in Amharic', (tester) async {
    await _pump(tester, locale: const Locale('am'));

    expect(find.text('ድምጾች'), findsOneWidget);
    expect(find.text('ዲቃላ'), findsOneWidget);
  });
}
