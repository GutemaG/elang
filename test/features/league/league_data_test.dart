// The weekly league's data in the app (023-weekly-leagues, bolt 075, story
// 006): reading the response, the API client, the copy saved on the phone,
// the screen's controller, the account settings writes, and the avatar
// colours' contrast.

import 'dart:convert';
import 'dart:math' as math;

import 'package:elang/features/league/league_api.dart';
import 'package:elang/features/league/league_controller.dart';
import 'package:elang/features/league/league_models.dart';
import 'package:elang/features/league/league_store.dart';
import 'package:elang/features/league/widgets/league_widgets.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/app_config_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/settings/account_settings_api.dart';
import 'package:elang/shared/settings/known_settings.dart';
import 'package:elang/shared/settings/remote_settings_controller.dart';
import 'package:elang/shared/settings/remote_settings_store.dart';
import 'package:elang/shared/theme/app_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_league_api.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

Future<SessionRepository> _signedIn() async {
  final sessions = SessionRepository(storage: InMemorySecureStorageService());
  await sessions.saveSession(
    SessionState(
      token: 'tok',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
    ),
  );
  return sessions;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('CurrentLeague.fromJson', () {
    test('reads a full response, members in rank order', () {
      final json = leagueJson();
      (json['members']! as List).shuffle(math.Random(1));
      final league = CurrentLeague.fromJson(json)!;

      expect(league.tier, LeagueTier.lightRoast);
      expect(league.status, LeagueStatus.joined);
      expect(league.weekEndsAt, DateTime.utc(2026, 10, 5));
      expect((league.promoteCount, league.demoteCount), (2, 2));
      expect(league.members.map((m) => m.rank), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(league.members[2].isMe, isTrue);
      expect(league.members[2].name, 'Abebe');
      expect(league.rewardFor(1), 100);
      expect(league.rewardFor(3), 40);
      expect(league.rewardFor(4), 0);
      expect(league.lastResult, isNull);
    });

    test('unknown tiers and statuses, extra and missing fields', () {
      final league = CurrentLeague.fromJson({
        'tier': 'platinum',
        'status': 'paused',
        'week_ends_at': '2026-10-05T00:00:00Z',
        'members': [
          {'name': 'Tigist', 'rank': 1, 'new_field': true},
          {'rank': 2},
          'not a member',
        ],
        'something_new': [1, 2],
      })!;

      expect(league.tier, LeagueTier.greenBean);
      expect(league.status, LeagueStatus.notJoined);
      expect(league.members, hasLength(1));
      expect(league.members.single.initial, 'T');
      expect(league.rewards, isEmpty);
    });

    test('not a league at all is null', () {
      expect(CurrentLeague.fromJson('x'), isNull);
      expect(CurrentLeague.fromJson({'tier': 'green_bean'}), isNull);
      expect(
        CurrentLeague.fromJson({'week_ends_at': '2026-10-05T00:00:00Z'}),
        isNull,
      );
    });

    test('a last result is read, and survives the saved copy', () {
      final league = CurrentLeague.fromJson(
        leagueJson(
          lastResult: {
            'week_start': '2026-09-28',
            'tier': 'green_bean',
            'tier_after': 'light_roast',
            'movement': 'up',
            'rank': 1,
            'group_size': 6,
            'weekly_xp': 30,
            'reward_amole': 100,
          },
        ),
      )!;
      final again = CurrentLeague.fromJson(
        jsonDecode(jsonEncode(league.toJson())),
      )!;

      for (final l in [league, again]) {
        expect(l.lastResult!.tierAfter, LeagueTier.lightRoast);
        expect(l.lastResult!.rank, 1);
        expect(l.lastResult!.rewardAmole, 100);
      }
      expect(again.members.length, league.members.length);
      expect(again.status, league.status);
      expect(again.weekEndsAt, league.weekEndsAt);
    });
  });

  group('HttpLeagueApi', () {
    test('calls the endpoint with the session token', () async {
      late http.Request seen;
      final api = HttpLeagueApi(
        sessionRepository: await _signedIn(),
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode(leagueJson()), 200);
        }),
      );

      final league = await api.current();

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/v1/leagues/current');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(league.members, hasLength(8));
    });

    test('offline, an error status or a malformed body throws', () async {
      final sessions = await _signedIn();
      for (final client in [
        MockClient((_) async => throw http.ClientException('offline')),
        MockClient((_) async => http.Response('{}', 401)),
        MockClient((_) async => http.Response('not json', 200)),
        MockClient((_) async => http.Response('{"tier": 1}', 200)),
      ]) {
        final api = HttpLeagueApi(
          sessionRepository: sessions,
          baseUrl: 'https://api.test',
          client: client,
        );
        await expectLater(api.current(), throwsA(isA<LeagueApiException>()));
      }
    });
  });

  group('LeagueStore', () {
    test('round trip, a corrupt copy, the notice and forgetting', () async {
      final storage = InMemorySecureStorageService();
      final store = LeagueStore(storage: storage);
      final at = DateTime.utc(2026, 10, 2, 9);

      expect(await store.read(), isNull);
      await store.save(league(), at);
      final saved = await store.read();
      expect(saved!.savedAt, at);
      expect(saved.league.members, hasLength(8));

      expect(await store.noticeSeen(), isFalse);
      await store.markNoticeSeen();
      expect(await store.noticeSeen(), isTrue);

      await storage.write('league_current', '{broken');
      expect(await store.read(), isNull);

      await store.save(league(), at);
      await store.forget();
      expect(await store.read(), isNull);
      expect(await store.noticeSeen(), isFalse);
    });

    test('a new account forgets the league', () async {
      final storage = InMemorySecureStorageService();
      final sessions = SessionRepository(storage: storage);
      final store = LeagueStore(storage: storage);
      sessions.addAccountChangedListener(store.forget);
      await store.save(league(), DateTime.utc(2026, 10, 2));

      await sessions.clearSession();
      await Future<void>.delayed(Duration.zero);

      expect(await store.read(), isNull);
    });
  });

  group('LeagueController', () {
    final now = DateTime.utc(2026, 10, 2, 9);

    test('the saved copy first, then a fresh one, which is saved', () async {
      final store = LeagueStore(storage: InMemorySecureStorageService());
      await store.save(
        league(members: 3),
        now.subtract(const Duration(hours: 2)),
      );
      final api = FakeLeagueApi(league(members: 5));
      final c = LeagueController(api: api, store: store, clock: () => now);
      final seen = <(LeagueLoadState, int)>[];
      c.addListener(() => seen.add((c.state, c.league!.members.length)));

      await c.load();

      expect(seen.first, (LeagueLoadState.saved, 3));
      expect(seen.last, (LeagueLoadState.ready, 5));
      expect((await store.read())!.league.members, hasLength(5));
    });

    test('offline with a copy shows it with its time', () async {
      final store = LeagueStore(storage: InMemorySecureStorageService());
      final at = now.subtract(const Duration(hours: 2));
      await store.save(league(), at);
      final c = LeagueController(
        api: FakeLeagueApi()..offline = true,
        store: store,
        clock: () => now,
      );

      await c.load();

      expect(c.state, LeagueLoadState.saved);
      expect(c.savedAt, at);
    });

    test('offline with nothing saved is unavailable, until a retry', () async {
      final api = FakeLeagueApi()..offline = true;
      final c = LeagueController(
        api: api,
        store: LeagueStore(storage: InMemorySecureStorageService()),
        clock: () => now,
      );

      await c.load();
      expect(c.state, LeagueLoadState.unavailable);

      api.offline = false;
      await c.refresh();
      expect(c.state, LeagueLoadState.ready);
    });

    test('a failed refresh keeps the league, marked with its time', () async {
      final api = FakeLeagueApi();
      final c = LeagueController(
        api: api,
        store: LeagueStore(storage: InMemorySecureStorageService()),
        clock: () => now,
      );
      await c.load();

      api.offline = true;
      await c.refresh();

      expect(c.state, LeagueLoadState.saved);
      expect(c.league, isNotNull);
      expect(c.savedAt, now);
    });

    test('the notice shows only with a ranking, until dismissed', () async {
      final store = LeagueStore(storage: InMemorySecureStorageService());
      final api = FakeLeagueApi(league(status: 'not_joined'));
      final c = LeagueController(api: api, store: store, clock: () => now);
      await c.load();
      expect(c.showNotice, isFalse);

      api.next = league();
      await c.refresh();
      expect(c.showNotice, isTrue);

      await c.dismissNotice();
      expect(c.showNotice, isFalse);
      final again = LeagueController(api: api, store: store, clock: () => now);
      await again.load();
      expect(again.showNotice, isFalse);
    });
  });

  group('texts', () {
    final now = DateTime.utc(2026, 10, 2, 9);

    test('time left', () {
      expect(
        leagueTimeLeft(now.add(const Duration(days: 3, hours: 2)), now),
        '3 days left',
      );
      expect(
        leagueTimeLeft(now.add(const Duration(hours: 30)), now),
        '1 day left',
      );
      expect(
        leagueTimeLeft(now.add(const Duration(hours: 5)), now),
        '5 hours left',
      );
      expect(
        leagueTimeLeft(now.add(const Duration(minutes: 70)), now),
        '1 hour left',
      );
      expect(
        leagueTimeLeft(now.add(const Duration(minutes: 20)), now),
        'Ends soon',
      );
    });

    test('who moves', () {
      expect(leagueZoneSummary(2, 1), 'Top 2 move up · bottom 1 moves down');
      expect(leagueZoneSummary(1, 0), 'Top 1 moves up');
      expect(leagueZoneSummary(0, 3), 'Bottom 3 move down');
      expect(leagueZoneSummary(0, 0), isNull);
    });

    test('updated ago', () {
      expect(leagueUpdatedAgo(now, now), 'updated just now');
      expect(
        leagueUpdatedAgo(now.subtract(const Duration(minutes: 5)), now),
        'updated 5 min ago',
      );
      expect(
        leagueUpdatedAgo(now.subtract(const Duration(hours: 2)), now),
        'updated 2 h ago',
      );
      expect(
        leagueUpdatedAgo(now.subtract(const Duration(days: 3)), now),
        'updated 3 days ago',
      );
    });
  });

  group('account settings', () {
    RemoteSettingsController controller() => RemoteSettingsController(
      store: RemoteSettingsStore(storage: InMemorySecureStorageService()),
      configApi: AppConfigApi(
        client: MockClient((_) async => throw http.ClientException('x')),
      ),
    );

    test('show_in_leagues defaults to on', () {
      expect(RemoteSettings.empty.get(AccountSettings.showInLeagues), isTrue);
    });

    test('an update shows at once and keeps the saved map', () async {
      final c = controller();
      final api = FakeAccountSettingsApi();
      final seen = <bool>[];
      c.addListener(
        () => seen.add(c.account.get(AccountSettings.showInLeagues)),
      );

      await c.updateAccount({'show_in_leagues': false}, api);

      expect(seen.first, isFalse);
      expect(c.account.values, {'show_in_leagues': false});
      expect(api.updates, [
        {'show_in_leagues': false},
      ]);
    });

    test('a failed update is put back and rethrown', () async {
      final c = controller();
      final api = FakeAccountSettingsApi()..fail = true;

      await expectLater(
        c.updateAccount({'show_in_leagues': false}, api),
        throwsA(isA<AccountSettingsException>()),
      );

      expect(c.account.get(AccountSettings.showInLeagues), isTrue);
    });

    test('HttpAccountSettingsApi patches and reads the map back', () async {
      late http.Request seen;
      final api = HttpAccountSettingsApi(
        sessionRepository: await _signedIn(),
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'settings': {'show_in_leagues': false},
            }),
            200,
          );
        }),
      );

      expect(await api.update({'show_in_leagues': false}), {
        'show_in_leagues': false,
      });
      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/v1/users/me/settings');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(seen.body), {'show_in_leagues': false});
    });

    test('HttpAccountSettingsApi throws on a refusal or offline', () async {
      final sessions = await _signedIn();
      for (final client in [
        MockClient((_) async => http.Response('{}', 422)),
        MockClient((_) async => throw http.ClientException('offline')),
        MockClient((_) async => http.Response('{"settings": 1}', 200)),
      ]) {
        final api = HttpAccountSettingsApi(
          sessionRepository: sessions,
          baseUrl: 'https://api.test',
          client: client,
        );
        await expectLater(
          api.update({'show_in_leagues': true}),
          throwsA(isA<AccountSettingsException>()),
        );
      }
    });
  });

  test('every avatar letter is readable on its circle, in both themes', () {
    for (final MapEntry(key: name, value: palette) in AppPalette.all.entries) {
      final colours = leagueAvatarColours(palette);
      expect(colours, hasLength(8));
      for (final (i, pair) in colours.indexed) {
        expect(
          _contrast(pair.face, pair.letter),
          greaterThanOrEqualTo(3),
          reason: '$name avatar $i',
        );
      }
    }
  });
}
