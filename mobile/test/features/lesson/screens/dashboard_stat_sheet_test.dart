// The dashboard's counters open the stats sheet (013-stat-pill-interactions,
// bolt 060): on the counter tapped, online and from the saved copy, and a
// refill in the sheet shows on the counters at once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/lesson/widgets/lesson_hud.dart';
import 'package:elang/features/lesson/widgets/stat_sheet.dart';
import 'package:elang/features/lesson/widgets/streak_calendar.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/models/stat_history.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_api_exception.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/widgets/app_status.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

const _course = Course(
  id: 'c-en-am',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
);

const _tree = SkillTreeResponse(
  course: _course,
  categories: [SkillCategory(id: 'cat', title: 'Banner', subtitle: 's')],
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
  streakCount: 7,
  beans: 2,
  beansMax: 5,
  totalXp: 340,
);

BeansStatus _beans() => BeansStatus(
  beans: 2,
  beansMax: 5,
  regenMinutesPerBean: 30,
  amoleBalance: 500,
  refillCostAmole: 350,
  nextBeanAt: DateTime.now().add(const Duration(minutes: 20)),
);

class _Rig {
  _Rig({required this.lessonApi, CourseCacheStore? cache})
    : cache = cache ?? InMemoryCourseCacheStore();

  final ControllableLessonApi lessonApi;
  final CourseCacheStore cache;
  final packStore = FakeLessonPackStore();
  late final downloader = LessonPackDownloader(
    lessonApi: lessonApi,
    packStore: packStore,
  );
  final connectivity = FakeConnectivityMonitor();
  late final syncEngine = SyncEngine(
    lessonApi: lessonApi,
    connectivityMonitor: connectivity,
    queueStore: FakePendingSyncQueueStore(),
  );

  Future<void> pump(WidgetTester tester) async {
    final session = SessionRepository(storage: InMemorySecureStorageService());
    await tester.pumpWidget(
      MaterialApp(
        home: SkillTreeDashboardScreen(
          lessonApi: lessonApi,
          audioPlayer: FakeLessonAudioPlayer(),
          feedbackPlayer: FakeAnswerFeedbackPlayer(),
          connectivityMonitor: connectivity,
          lessonPackStore: packStore,
          lessonPackDownloader: downloader,
          syncEngine: syncEngine,
          courseApi: FakeCourseApi(courses: const [_course]),
          courseCache: cache,
          sessionRepository: session,
          userPreferencesApi: HttpUserPreferencesApi(
            sessionRepository: session,
          ),
          soundPreferenceRepository: SoundPreferenceRepository(
            storage: InMemorySecureStorageService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

ControllableLessonApi _online() => ControllableLessonApi()
  ..skillTree = _tree
  ..beansStatus = _beans()
  ..dueCount = 0
  ..streakHistory = StreakHistory(
    practisedDays: [DateTime.now().toUtc()],
    currentStreak: 7,
    longestStreak: 11,
    joinedOn: DateTime.utc(2026, 1, 1),
  )
  ..amoleHistory = [
    AmoleEntry(
      amount: 10,
      source: 'perfect_lesson',
      createdAt: DateTime.now().toUtc(),
    ),
  ];

Finder _hudPill(StatKind kind) => find.descendant(
  of: find.byType(LessonHud),
  matching: find.byWidgetPredicate((w) => w is StatPill && w.kind == kind),
);

Finder _sheetTab(StatKind kind) =>
    find.byKey(ValueKey('stat-sheet-tab-${kind.name}'));

void main() {
  testWidgets('each counter opens the sheet on its own tab', (tester) async {
    await _Rig(lessonApi: _online()).pump(tester);

    for (final (kind, title) in [
      (StatKind.streak, '7 day streak'),
      (StatKind.beans, 'Beans'),
      (StatKind.xp, '340 XP'),
      (StatKind.amole, '500 Amole'),
    ]) {
      await tester.tap(_hudPill(kind));
      await tester.pumpAndSettle();
      expect(find.byType(StatSheet), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(tester.widget<StatPill>(_sheetTab(kind)).selected, isTrue);

      await tester.ensureVisible(find.text('Close'));
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(StatSheet), findsNothing);
    }
  });

  testWidgets('a refill in the sheet shows on the counters at once', (
    tester,
  ) async {
    final api = _online()
      ..refillResult = const RefillSuccess(newBeans: 5, newAmoleBalance: 150);
    await _Rig(lessonApi: api).pump(tester);
    expect(tester.widget<StatPill>(_hudPill(StatKind.beans)).value, 2);

    await tester.tap(_hudPill(StatKind.beans));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Refill with Amole'));
    await tester.tap(find.text('Refill with Amole'));
    await tester.pumpAndSettle();
    expect(api.refillCallCount, 1);

    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.widget<StatPill>(_hudPill(StatKind.beans)).value, 5);
    expect(tester.widget<StatPill>(_hudPill(StatKind.amole)).value, 150);
  });

  testWidgets('an online load saves the beans timing for offline use', (
    tester,
  ) async {
    final rig = _Rig(lessonApi: _online());
    await rig.pump(tester);

    final saved = (await rig.cache.loadDashboard('c-en-am'))!.beansStatus!;
    expect(saved.nextBeanAt, isNotNull);
    expect(saved.regenMinutesPerBean, 30);
    expect(saved.refillCostAmole, 350);
  });

  testWidgets('offline, the counters still open the sheet, which counts '
      'down but cannot refill', (tester) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveDashboard(
      'c-en-am',
      _tree,
      amoleBalance: 500,
      beansStatus: _beans(),
    );
    await cache.setActiveCourseId('c-en-am');
    final api = _online()
      ..skillTreeError = const LessonApiException('Network request failed');
    await _Rig(lessonApi: api, cache: cache).pump(tester);
    expect(find.text('Offline, showing saved progress'), findsOneWidget);

    await tester.tap(_hudPill(StatKind.beans));
    await tester.pumpAndSettle();
    expect(find.text('Next bean in'), findsOneWidget);
    expect(find.text('Refill needs a connection'), findsOneWidget);
    expect(api.refillCallCount, 0);
  });

  testWidgets('the streak and Amole tabs load through the lesson API', (
    tester,
  ) async {
    final api = _online();
    await _Rig(lessonApi: api).pump(tester);

    await tester.tap(_hudPill(StatKind.streak));
    await tester.pumpAndSettle();
    expect(api.streakHistoryCalls, hasLength(1));
    final (from, to) = api.streakHistoryCalls.single;
    expect(from, StreakCalendar.firstDayShown(utcDay(DateTime.now())));
    expect(to, utcDay(DateTime.now()));
    expect(find.text('Longest: 11 days'), findsOneWidget);
    expect(find.byType(StreakCalendar), findsOneWidget);

    await tester.tap(_sheetTab(StatKind.amole));
    await tester.pumpAndSettle();
    expect(api.amoleHistoryCallCount, 1);
    expect(find.text('Perfect lesson'), findsOneWidget);
  });
}
