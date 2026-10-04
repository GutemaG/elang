// The signed-in app's bottom bar (HomeShell): Learn, Sounds, League,
// Downloads and Settings, with the course panel left holding only courses.

import 'package:elang/features/courses/course_badge.dart';
import 'package:elang/features/courses/course_panel.dart';
import 'package:elang/features/home/home_shell.dart';
import 'package:elang/features/league/league_dependencies.dart';
import 'package:elang/features/league/screens/league_screen.dart';
import 'package:elang/features/lesson/screens/download_management_screen.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/features/sounds/sound_chart_store.dart';
import 'package:elang/features/sounds/sound_charts.dart';
import 'package:elang/features/sounds/sounds_screen.dart';
import 'package:elang/shared/l10n/app_language.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_answer_feedback_player.dart';
import '../../helpers/fake_connectivity_monitor.dart';
import '../../helpers/fake_league_api.dart';
import '../../helpers/fake_lesson_audio_player.dart';
import '../../helpers/fake_lesson_pack_store.dart';
import '../../helpers/fake_pending_sync_queue_store.dart';
import '../../helpers/fake_user_preferences_api.dart';
import '../../helpers/in_memory_secure_storage_service.dart';
import '../sounds/sound_fixtures.dart';

Course _course(String language) => Course(
  id: 'c-en-$language',
  learningLanguage: language,
  fromLanguage: 'en',
  title: 'English to $language',
);

ControllableLessonApi _lessonApi(String language) => ControllableLessonApi()
  ..skillTree = SkillTreeResponse(
    course: _course(language),
    categories: const [
      SkillCategory(id: 'cat', title: 'Basics', subtitle: 's'),
    ],
    nodes: const [
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

class _Setup {
  _Setup({this.language = 'am', bool withLeague = true}) {
    leagueDeps = withLeague
        ? LeagueDependencies(
            storage: InMemorySecureStorageService(),
            sessionRepository: session,
            api: FakeLeagueApi(league()),
            accountSettingsApi: FakeAccountSettingsApi(),
          )
        : null;
  }

  final String language;
  final session = SessionRepository(storage: InMemorySecureStorageService());
  final soundApi = FakeSoundChartApi();
  final player = FakeSoundPlayer();
  late final charts = SoundCharts(
    api: soundApi,
    store: InMemorySoundChartStore(),
  );
  late final LeagueDependencies? leagueDeps;

  Widget app() {
    final api = _lessonApi(language);
    final connectivity = FakeConnectivityMonitor();
    final packStore = FakeLessonPackStore();
    return MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLanguage.delegates,
      supportedLocales: AppLanguage.locales,
      home: HomeShell(
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
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        soundCharts: charts,
        soundPlayer: player,
        sessionApi: SessionApi(),
        league: leagueDeps,
      ),
    );
  }
}

Future<_Setup> _pump(WidgetTester tester, [_Setup? setup]) async {
  final s = setup ?? _Setup();
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(s.app());
  await tester.pumpAndSettle();
  return s;
}

Finder _tab(HomeTab tab) => find.byKey(HomeShell.tabKey(tab));

Future<void> _open(WidgetTester tester, HomeTab tab) async {
  await tester.tap(_tab(tab));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bar has every place, with the Sounds tab for a language '
      'with a chart', (tester) async {
    await _pump(tester);

    for (final tab in HomeTab.values) {
      expect(_tab(tab), findsOneWidget, reason: tab.name);
    }
    for (final label in [
      'Learn',
      'Sounds',
      'League',
      'Downloads',
      'Settings',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    // The Sounds tab shows the script's first letter.
    expect(
      find.descendant(of: _tab(HomeTab.sounds), matching: find.text('ሀ')),
      findsOneWidget,
    );
    expect(find.byType(SkillTreeDashboardScreen), findsOneWidget);
  });

  testWidgets('no Sounds tab for a language without a chart, and no League '
      'tab without the league', (tester) async {
    await _pump(tester, _Setup(language: 'om', withLeague: false));

    expect(_tab(HomeTab.sounds), findsNothing);
    expect(_tab(HomeTab.league), findsNothing);
    expect(_tab(HomeTab.settings), findsOneWidget);
  });

  testWidgets('each tab opens its screen, and the path keeps its place', (
    tester,
  ) async {
    final s = await _pump(tester);

    await _open(tester, HomeTab.sounds);
    expect(find.byType(SoundsScreen), findsOneWidget);
    await tester.tap(find.byKey(SoundsScreen.tileKey('ha')));
    await tester.pumpAndSettle();
    expect(s.player.played, ['$clip/ha.m4a']);
    Navigator.of(tester.element(find.text('Slow'))).pop();
    await tester.pumpAndSettle();

    await _open(tester, HomeTab.league);
    expect(find.byType(LeagueScreen), findsOneWidget);
    // A tab has nothing to go back to.
    expect(find.byTooltip('Back'), findsNothing);
    // Leaving Sounds stops its sound.
    expect(s.player.stops, greaterThan(0));

    await _open(tester, HomeTab.downloads);
    expect(find.byType(DownloadManagementScreen), findsOneWidget);

    await _open(tester, HomeTab.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await _open(tester, HomeTab.learn);
    expect(find.byType(SkillTreeDashboardScreen), findsOneWidget);
  });

  testWidgets('the course panel holds only courses now', (tester) async {
    await _pump(tester);

    await tester.tap(find.byType(CourseBadge));
    await tester.pumpAndSettle();

    expect(find.byType(CoursePanel), findsOneWidget);
    expect(find.text('Manage downloads'), findsNothing);
    expect(find.byKey(const ValueKey('course-panel-league')), findsNothing);
  });

  testWidgets('back from another tab returns to the path', (tester) async {
    await _pump(tester);
    await _open(tester, HomeTab.settings);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(SkillTreeDashboardScreen).hitTestable(), findsOneWidget);
  });
}
