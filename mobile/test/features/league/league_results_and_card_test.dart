// Last week's result and the dashboard's league card (023-weekly-leagues,
// bolt 076, stories 008 and 009), and league rewards in the Amole history.

import 'dart:convert';

import 'package:elang/features/league/league_api.dart';
import 'package:elang/features/league/league_dependencies.dart';
import 'package:elang/features/league/league_models.dart';
import 'package:elang/features/league/screens/league_screen.dart';
import 'package:elang/features/league/widgets/league_result_sheet.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/models/stat_history.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_answer_feedback_player.dart';
import '../../helpers/fake_connectivity_monitor.dart';
import '../../helpers/fake_lesson_audio_player.dart';
import '../../helpers/fake_lesson_pack_store.dart';
import '../../helpers/fake_league_api.dart';
import '../../helpers/fake_pending_sync_queue_store.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

const _course = Course(
  id: 'c-en-am',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
);

ControllableLessonApi _lessonApi() => ControllableLessonApi()
  ..skillTree = const SkillTreeResponse(
    course: _course,
    categories: [SkillCategory(id: 'cat', title: 'Basics', subtitle: 's')],
    nodes: [
      SkillTreeNode(
        id: 'skill',
        lessonId: 'lesson',
        title: 'Greetings',
        subtitle: '',
        state: SkillNodeState.active,
        categoryId: 'cat',
      ),
    ],
    streakCount: 3,
    beans: 5,
    beansMax: 5,
    totalXp: 120,
  )
  ..beansStatus = const BeansStatus(
    beans: 5,
    beansMax: 5,
    regenMinutesPerBean: 30,
    amoleBalance: 500,
    refillCostAmole: 350,
  )
  ..dueCount = 0;

Map<String, Object?> _result({
  String tier = 'green_bean',
  String after = 'light_roast',
  int? rank = 2,
  int reward = 60,
}) => {
  'week_start': '2026-09-28',
  'tier': tier,
  'tier_after': after,
  'movement': 'up',
  'rank': rank,
  'group_size': 12,
  'weekly_xp': 140,
  'reward_amole': reward,
};

LeagueDependencies _league(FakeLeagueApi api) => LeagueDependencies(
  storage: InMemorySecureStorageService(),
  sessionRepository: SessionRepository(storage: InMemorySecureStorageService()),
  api: api,
  accountSettingsApi: FakeAccountSettingsApi(),
);

Widget _dashboard(LeagueDependencies? league) {
  final api = _lessonApi();
  final connectivity = FakeConnectivityMonitor();
  final packStore = FakeLessonPackStore();
  final session = SessionRepository(storage: InMemorySecureStorageService());
  return MaterialApp(
    theme: AppTheme.light,
    home: SkillTreeDashboardScreen(
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      connectivityMonitor: connectivity,
      lessonPackStore: packStore,
      lessonPackDownloader: LessonPackDownloader(
        lessonApi: api,
        packStore: packStore,
      ),
      syncEngine: SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      ),
      courseApi: FakeCourseApi(),
      sessionRepository: session,
      userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
      league: league,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Finder get _card => find.byKey(LeagueCard.cardKey);

void main() {
  group('the dashboard card', () {
    testWidgets('joined: tier, place and XP; it opens the league', (
      tester,
    ) async {
      final api = FakeLeagueApi(league(members: 12));
      final deps = _league(api);
      await deps.store.markNoticeSeen();
      await _pump(tester, _dashboard(deps));

      expect(_card, findsOneWidget);
      expect(find.text('Light Roast'), findsOneWidget);
      expect(find.text('3rd of 12 · 70 XP this week'), findsOneWidget);

      await tester.tap(_card);
      await tester.pumpAndSettle();
      expect(find.byType(LeagueScreen), findsOneWidget);
    });

    testWidgets('not joined: an invitation naming the tier', (tester) async {
      await _pump(
        tester,
        _dashboard(_league(FakeLeagueApi(league(status: 'not_joined')))),
      );

      expect(find.text("Join this week's league"), findsOneWidget);
      expect(find.text('Earn XP to join · Light Roast'), findsOneWidget);
    });

    testWidgets('switched off, offline with nothing saved, or no league: '
        'no card', (tester) async {
      await _pump(
        tester,
        _dashboard(_league(FakeLeagueApi(league(status: 'hidden')))),
      );
      expect(_card, findsNothing);

      await _pump(tester, _dashboard(_league(FakeLeagueApi()..offline = true)));
      expect(_card, findsNothing);

      await _pump(tester, _dashboard(null));
      expect(_card, findsNothing);
    });

    testWidgets('offline with a saved copy: the saved card', (tester) async {
      final deps = _league(FakeLeagueApi()..offline = true);
      await deps.store.save(league(members: 12), DateTime.utc(2026, 10, 1));
      await _pump(tester, _dashboard(deps));

      expect(find.text('3rd of 12 · 70 XP this week'), findsOneWidget);
    });

    testWidgets('coming back from the league reloads the card', (tester) async {
      final api = FakeLeagueApi(league(status: 'not_joined'));
      final deps = _league(api);
      await _pump(tester, _dashboard(deps));
      expect(find.text("Join this week's league"), findsOneWidget);

      // A first lesson of the week, say: now ranked.
      api.next = league(members: 5);
      await tester.tap(_card);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('3rd of 5 · 70 XP this week'), findsOneWidget);
    });
  });

  group('the result sheet', () {
    LeagueResult result(Map<String, Object?> json) =>
        LeagueResult.fromJson(json)!;

    test('titles and bodies: up, stayed and down', () {
      final up = result(_result());
      expect(LeagueResultSheet.title(up), 'You moved up to Light Roast!');
      expect(LeagueResultSheet.body(up), 'You finished 2nd of 12 with 140 XP.');

      final stayed = result(
        _result(tier: 'medium_roast', after: 'medium_roast'),
      );
      expect(LeagueResultSheet.title(stayed), 'You stayed in Medium Roast');

      final down = result(_result(tier: 'medium_roast', after: 'light_roast'));
      expect(LeagueResultSheet.title(down), 'You dropped to Light Roast');
      expect(LeagueResultSheet.body(down), endsWith('Climb back this week!'));

      final left = result(_result(rank: null));
      expect(
        LeagueResultSheet.body(left),
        'You had left the league before the week ended.',
      );
    });

    test('ordinals', () {
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 30].map(ordinal), [
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '21st',
        '22nd',
        '23rd',
        '30th',
      ]);
    });

    testWidgets('shown on the dashboard once, then marked seen', (
      tester,
    ) async {
      final api = FakeLeagueApi(
        CurrentLeague.fromJson(leagueJson(lastResult: _result()))!,
      );
      final deps = _league(api);
      await _pump(tester, _dashboard(deps));

      expect(find.text('You moved up to Light Roast!'), findsOneWidget);
      expect(find.text('+60 Amole'), findsOneWidget);
      expect(api.seenCalls, 0);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(LeagueResultSheet), findsNothing);
      expect(api.seenCalls, 1);

      // The league screen gets the same result: not shown again this run.
      await tester.tap(_card);
      await tester.pumpAndSettle();
      expect(find.byType(LeagueResultSheet), findsNothing);
    });

    testWidgets('no reward, no badge', (tester) async {
      final api = FakeLeagueApi(
        CurrentLeague.fromJson(
          leagueJson(lastResult: _result(reward: 0, rank: 7)),
        )!,
      );
      await _pump(tester, _dashboard(_league(api)));

      expect(find.text('You finished 7th of 12 with 140 XP.'), findsOneWidget);
      expect(find.textContaining('Amole'), findsNothing);
    });

    testWidgets('marking it seen offline: it comes back next run', (
      tester,
    ) async {
      final next = CurrentLeague.fromJson(leagueJson(lastResult: _result()))!;
      final api = _SeenFails(next);
      await _pump(tester, _dashboard(_league(api)));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(api.seenCalls, 1);

      // The next run: a new app, the backend still offering it.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _dashboard(_league(api)));
      expect(find.text('You moved up to Light Roast!'), findsOneWidget);
    });

    testWidgets('the league screen shows it if it gets it first', (
      tester,
    ) async {
      final api = FakeLeagueApi(
        CurrentLeague.fromJson(leagueJson(lastResult: _result()))!,
      );
      final deps = _league(api);
      await deps.store.markNoticeSeen();
      await _pump(
        tester,
        MaterialApp(
          theme: AppTheme.light,
          home: LeagueScreen(
            api: api,
            store: deps.store,
            accountSettingsApi: deps.accountSettingsApi,
            onLeague: deps.showResultOnce,
          ),
        ),
      );

      expect(find.byType(LeagueResultSheet), findsOneWidget);
    });

    test('HttpLeagueApi marks it seen with a POST', () async {
      final sessions = SessionRepository(
        storage: InMemorySecureStorageService(),
      );
      await sessions.saveSession(
        SessionState(
          token: 'tok',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          authProvider: 'google',
        ),
      );
      late http.Request seen;
      final ok = HttpLeagueApi(
        sessionRepository: sessions,
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          seen = request;
          return http.Response('', 204);
        }),
      );
      await ok.markResultSeen();
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/leagues/last-result/seen');
      expect(seen.headers['Authorization'], 'Bearer tok');

      final failing = HttpLeagueApi(
        sessionRepository: sessions,
        baseUrl: 'https://api.test',
        client: MockClient((_) async => http.Response('', 500)),
      );
      await expectLater(
        failing.markResultSeen(),
        throwsA(isA<LeagueApiException>()),
      );
    });
  });

  test('a league reward reads "League reward" in the Amole history', () {
    final entry = AmoleEntry.fromJson(
      jsonDecode(
        '{"amount": 100, "source": "league_reward", '
        '"created_at": "2026-10-05T00:00:00Z"}',
      ),
    );
    expect(entry!.reason, 'League reward');
  });
}

/// Answers with a league, but can never mark its result seen.
class _SeenFails extends FakeLeagueApi {
  _SeenFails(super.next);

  @override
  Future<void> markResultSeen() async {
    seenCalls++;
    throw const LeagueApiException('offline');
  }
}
