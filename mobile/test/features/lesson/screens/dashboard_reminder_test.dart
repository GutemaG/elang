// The dashboard keeps the daily reminder in step (021-daily-reminder, bolt
// 063): each load passes the streak, a fresh load also whether today is
// practised, and a lesson started from it reports when it counts. Each load
// also offers the first-launch prompt (bolt 065), which asks only once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_api_exception.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/reminders/reminder_service.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';
import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';
import '../../../helpers/skill_path.dart';

const _course = Course(
  id: 'c-en-am',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
);

SkillTreeResponse _tree({bool practisedToday = false}) => SkillTreeResponse(
  course: _course,
  categories: const [SkillCategory(id: 'cat', title: 'Banner', subtitle: 's')],
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
  streakCount: 7,
  beans: 5,
  beansMax: 5,
  totalXp: 340,
  practisedToday: practisedToday,
);

const _lesson = LessonContent(
  lessonId: 'lesson',
  skillId: 'skill',
  title: 'Greetings',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MultipleChoiceExercise(
      id: 'mc-1',
      prompt: 'ሀ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le'],
      correctOptionIndex: 0,
    ),
  ],
);

/// Records what the dashboard tells the reminder, and does nothing else.
class _SpyReminders extends ReminderService {
  _SpyReminders()
    : super(
        scheduler: FakeReminderScheduler(),
        store: ReminderStore(storage: InMemorySecureStorageService()),
      );

  final refreshes = <({int? streak, bool? practisedToday})>[];
  final counted = <({DateTime at, int? streak})>[];
  var signedOutCount = 0;
  var askCount = 0;

  @override
  Future<void> askOnFirstLaunch() async => askCount++;

  @override
  Future<void> signedOut() async => signedOutCount++;

  @override
  Future<void> refresh({int? streakCount, bool? practisedToday}) async {
    refreshes.add((streak: streakCount, practisedToday: practisedToday));
  }

  @override
  Future<void> lessonCounted(DateTime completedAt, {int? streakCount}) async {
    counted.add((at: completedAt, streak: streakCount));
  }
}

ControllableLessonApi _online({bool practisedToday = false}) =>
    ControllableLessonApi()
      ..skillTree = _tree(practisedToday: practisedToday)
      ..beansStatus = const BeansStatus(
        beans: 5,
        beansMax: 5,
        regenMinutesPerBean: 30,
        amoleBalance: 500,
        refillCostAmole: 350,
      )
      ..dueCount = 0
      ..lessonContent = _lesson;

Future<void> _pump(
  WidgetTester tester,
  ControllableLessonApi api,
  ReminderService reminders, {
  CourseCacheStore? cache,
}) async {
  final connectivity = FakeConnectivityMonitor();
  final packStore = FakeLessonPackStore();
  final session = SessionRepository(storage: InMemorySecureStorageService());
  await tester.pumpWidget(
    MaterialApp(
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
        courseApi: FakeCourseApi(courses: const [_course]),
        courseCache: cache ?? InMemoryCourseCacheStore(),
        sessionRepository: session,
        userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        reminders: reminders,
      ),
      routes: {
        AuthRoutes.signIn: (_) => const Scaffold(body: Text('SIGN-IN SCREEN')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("a network load passes the streak and today's practice", (
    tester,
  ) async {
    final reminders = _SpyReminders();

    await _pump(tester, _online(practisedToday: true), reminders);

    expect(reminders.refreshes, [(streak: 7, practisedToday: true)]);
    expect(reminders.askCount, 1);
  });

  testWidgets('the saved copy passes only the streak', (tester) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveDashboard(
      'c-en-am',
      _tree(practisedToday: true),
      amoleBalance: 500,
    );
    await cache.setActiveCourseId('c-en-am');
    final api = _online()
      ..skillTreeError = const LessonApiException('Network request failed');
    final reminders = _SpyReminders();

    await _pump(tester, api, reminders, cache: cache);

    expect(find.text('Offline, showing saved progress'), findsOneWidget);
    expect(reminders.refreshes, [(streak: 7, practisedToday: null)]);
    expect(reminders.askCount, 1);
  });

  testWidgets('a lesson from the dashboard reports that it counted', (
    tester,
  ) async {
    final api = _online()
      ..completionResult = const LessonCompletionResult(
        xpEarned: 5,
        dailyXpTotal: 5,
        dailyXpTarget: 30,
        streakCount: 8,
        streakIncreasedToday: true,
        accuracyPercent: 100,
        correctCount: 1,
        totalCount: 1,
        timeSpent: Duration(seconds: 5),
      );
    final reminders = _SpyReminders();
    await _pump(tester, api, reminders);

    await startSkill(tester, 'Greetings');
    await tester.tap(find.text('ha'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(reminders.counted, hasLength(1));
    expect(reminders.counted.single.streak, 8);
  });

  testWidgets('"sign in again" cancels the reminders (bolt 064)', (
    tester,
  ) async {
    final api = _online()
      ..skillTreeError = const LessonApiException(
        'unknown',
        errorCode: 'invalid_session',
      );
    final reminders = _SpyReminders();
    await _pump(tester, api, reminders);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN-IN SCREEN'), findsOneWidget);
    expect(reminders.signedOutCount, 1);
  });
}
