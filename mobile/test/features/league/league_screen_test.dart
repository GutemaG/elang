// The weekly league screen (023-weekly-leagues, bolt 075, stories 006 and
// 007): the ranking with its zones, the states without one, offline, and
// the one-time note that others see the learner's first name.

import 'package:elang/features/league/league_store.dart';
import 'package:elang/features/league/screens/league_screen.dart';
import 'package:elang/features/league/widgets/league_widgets.dart';
import 'package:elang/shared/services/app_config_api.dart';
import 'package:elang/shared/settings/known_settings.dart';
import 'package:elang/shared/settings/remote_settings_controller.dart';
import 'package:elang/shared/settings/remote_settings_store.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_league_api.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

final _now = DateTime.utc(2026, 10, 2, 9);

class _Setup {
  _Setup({FakeLeagueApi? api}) : api = api ?? FakeLeagueApi();

  final FakeLeagueApi api;
  final settingsApi = FakeAccountSettingsApi();
  final store = LeagueStore(storage: InMemorySecureStorageService());
  final settings = RemoteSettingsController(
    store: RemoteSettingsStore(storage: InMemorySecureStorageService()),
    configApi: AppConfigApi(
      client: MockClient((_) async => throw http.ClientException('x')),
    ),
  );

  Widget app() => RemoteSettingsScope(
    controller: settings,
    child: MaterialApp(
      theme: AppTheme.light,
      home: LeagueScreen(
        api: api,
        store: store,
        accountSettingsApi: settingsApi,
        clock: () => _now,
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, _Setup setup) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(setup.app());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The texts of the ranking's rows and dividers, top to bottom.
List<String> _ranking(WidgetTester tester) {
  final widgets = tester.widgetList<Widget>(
    find.byWidgetPredicate((w) => w is LeagueRow || w is LeagueZoneDivider),
  );
  return [
    for (final w in widgets)
      if (w is LeagueRow)
        '${w.member.rank}'
      else if (w is LeagueZoneDivider)
        w.up ? 'UP' : 'DOWN',
  ];
}

void main() {
  testWidgets('the ranking: header, my row, rewards and both zones', (
    tester,
  ) async {
    final setup = _Setup();
    await setup.store.markNoticeSeen();
    await _pump(tester, setup);

    expect(find.text('Light Roast league'), findsOneWidget);
    expect(find.text('2 days left'), findsOneWidget);
    expect(find.text('Top 2 move up · bottom 2 move down'), findsOneWidget);
    expect(_ranking(tester), [
      '1', '2', 'UP', '3', '4', '5', '6', 'DOWN', '7', '8', //
    ]);
    expect(find.text('Abebe (You)'), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);
    expect(find.text('+60'), findsOneWidget);
    expect(find.text('+40'), findsOneWidget);
    expect(find.text('90 XP'), findsOneWidget);
    expect(find.byKey(LeagueScreen.offlineKey), findsNothing);
    expect(find.byKey(LeagueScreen.noticeKey), findsNothing);
  });

  testWidgets('a small group in the lowest tier: no line where nobody moves', (
    tester,
  ) async {
    final setup = _Setup(
      api: FakeLeagueApi(
        league(tier: 'green_bean', members: 3, promote: 1, demote: 0),
      ),
    );
    await setup.store.markNoticeSeen();
    await _pump(tester, setup);

    expect(find.text('Green Bean league'), findsOneWidget);
    expect(find.text('Top 1 moves up'), findsOneWidget);
    expect(_ranking(tester), ['1', 'UP', '2', '3']);
  });

  testWidgets('alone in a group: no dividers at all', (tester) async {
    final setup = _Setup(
      api: FakeLeagueApi(league(members: 1, promote: 1, demote: 0)),
    );
    await setup.store.markNoticeSeen();
    await _pump(tester, setup);

    expect(_ranking(tester), ['1']);
  });

  testWidgets('not joined yet: how to join, and back to lessons', (
    tester,
  ) async {
    final setup = _Setup(api: FakeLeagueApi(league(status: 'not_joined')));
    await _pump(tester, setup);

    expect(find.text('Earn XP this week to join'), findsOneWidget);
    expect(find.byType(LeagueRow), findsNothing);
    expect(find.byKey(LeagueScreen.noticeKey), findsNothing);
    expect(find.text('Start a lesson'), findsOneWidget);
  });

  testWidgets('switched off: one button turns it back on and reloads', (
    tester,
  ) async {
    final setup = _Setup(api: FakeLeagueApi(league(status: 'hidden')));
    await setup.store.markNoticeSeen();
    await _pump(tester, setup);
    expect(find.text("You're not in a league"), findsOneWidget);

    setup.api.next = league();
    await tester.tap(find.text('Show me in leagues'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(setup.settingsApi.updates, [
      {'show_in_leagues': true},
    ]);
    expect(setup.settings.account.get(AccountSettings.showInLeagues), isTrue);
    expect(find.byType(LeagueRow), findsNWidgets(8));
  });

  testWidgets('switching back on offline says so and stays', (tester) async {
    final setup = _Setup(api: FakeLeagueApi(league(status: 'hidden')));
    setup.settingsApi.fail = true;
    await _pump(tester, setup);

    await tester.tap(find.text('Show me in leagues'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Couldn't save. Check your connection."), findsOneWidget);
    expect(find.text("You're not in a league"), findsOneWidget);
  });

  testWidgets('offline with a saved copy: shown, with its age', (tester) async {
    final setup = _Setup()..api.offline = true;
    await setup.store.save(league(), _now.subtract(const Duration(hours: 2)));
    await setup.store.markNoticeSeen();
    await _pump(tester, setup);

    expect(find.byKey(LeagueScreen.offlineKey), findsOneWidget);
    expect(find.text('Offline · updated 2 h ago'), findsOneWidget);
    expect(find.byType(LeagueRow), findsNWidgets(8));
  });

  testWidgets('offline with nothing saved: not an error, and Retry works', (
    tester,
  ) async {
    final setup = _Setup()..api.offline = true;
    await _pump(tester, setup);

    expect(find.text('Connect to see your league'), findsOneWidget);

    setup.api.offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LeagueRow), findsNWidgets(8));
  });

  testWidgets('the first-name note shows once, until "Got it"', (tester) async {
    final setup = _Setup();
    await _pump(tester, setup);

    expect(find.byKey(LeagueScreen.noticeKey), findsOneWidget);
    expect(
      find.text('Others in your league see your first name'),
      findsOneWidget,
    );

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(find.byKey(LeagueScreen.noticeKey), findsNothing);
    expect(await setup.store.noticeSeen(), isTrue);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, setup);
    expect(find.byKey(LeagueScreen.noticeKey), findsNothing);
  });

  testWidgets('"Stay out" in the note turns leagues off', (tester) async {
    final setup = _Setup();
    await _pump(tester, setup);

    setup.api.next = league(status: 'hidden');
    await tester.tap(find.text('Stay out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(setup.settingsApi.updates, [
      {'show_in_leagues': false},
    ]);
    expect(setup.settings.account.get(AccountSettings.showInLeagues), isFalse);
    expect(find.text("You're not in a league"), findsOneWidget);
    expect(find.byKey(LeagueScreen.noticeKey), findsNothing);
  });

  testWidgets('a row reads as one phrase', (tester) async {
    final semantics = tester.ensureSemantics();
    final setup = _Setup();
    await setup.store.markNoticeSeen();
    await _pump(tester, setup);

    expect(
      find.bySemanticsLabel(
        'Place 1, Learner 1001, 90 XP, 100 Amole if the week ended now',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Place 3, Abebe (You), 70 XP, '
        '40 Amole if the week ended now',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
