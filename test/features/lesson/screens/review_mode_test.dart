// Replaying a completed skill is a review: the dashboard asks first with a
// "Review" sheet, a wrong answer spends no beans (so it can never end in the
// out-of-beans prompt), and the summary shows how it went instead of XP.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';

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

const _lesson = LessonContent(
  lessonId: 'lesson-done',
  skillId: 'skill-done',
  title: 'Greetings',
  beansAtStart: 1,
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

const _reviewResult = LessonCompletionResult(
  xpEarned: 0,
  dailyXpTotal: 10,
  dailyXpTarget: 30,
  streakCount: 3,
  streakIncreasedToday: false,
  accuracyPercent: 100,
  correctCount: 1,
  totalCount: 1,
  timeSpent: Duration(seconds: 5),
  isReview: true,
);

SkillTreeResponse _tree(SkillNodeState state) => SkillTreeResponse(
  course: _course,
  categories: const [SkillCategory(id: 'cat', title: 'Banner', subtitle: 's')],
  nodes: [
    SkillTreeNode(
      id: 'skill-done',
      lessonId: 'lesson-done',
      title: 'Greetings',
      subtitle: '',
      state: state,
      categoryId: 'cat',
      crownLevel: state == SkillNodeState.completed ? 1 : 0,
    ),
  ],
  streakCount: 3,
  beans: 5,
  beansMax: 5,
  totalXp: 10,
);

ControllableLessonApi _api(SkillNodeState state) => ControllableLessonApi()
  ..skillTree = _tree(state)
  ..beansStatus = const BeansStatus(
    beans: 5,
    beansMax: 5,
    regenMinutesPerBean: 30,
    amoleBalance: 500,
    refillCostAmole: 350,
  )
  ..dueCount = 0
  ..lessonContent = _lesson
  ..completionResult = _reviewResult;

Widget _dashboard(ControllableLessonApi api) {
  final connectivity = FakeConnectivityMonitor();
  final packStore = FakeLessonPackStore();
  final session = SessionRepository(storage: InMemorySecureStorageService());
  return MaterialApp(
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
      sessionRepository: session,
      userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
    ),
  );
}

Widget _reviewLesson(ControllableLessonApi api, {bool online = true}) {
  final connectivity = FakeConnectivityMonitor(online: online);
  return MaterialApp(
    home: LessonScreen(
      lessonId: 'lesson-done',
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      connectivityMonitor: connectivity,
      lessonPackStore: FakeLessonPackStore()..save(_lesson),
      syncEngine: SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      ),
      isReview: true,
    ),
  );
}

void main() {
  testWidgets('tapping a completed skill asks to Review before starting', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboard(_api(SkillNodeState.completed)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Greetings'));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('ሀ'), findsNothing); // not in the lesson yet

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('ሀ'), findsOneWidget);
  });

  testWidgets('dismissing the Review sheet stays on the dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboard(_api(SkillNodeState.completed)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Greetings'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // the scrim
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsNothing);
    expect(find.text('ሀ'), findsNothing);
  });

  testWidgets('an active skill still starts its lesson straight away', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboard(_api(SkillNodeState.active)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Greetings'));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsNothing);
    expect(find.text('ሀ'), findsOneWidget);
  });

  testWidgets(
    'a wrong answer in a review spends no beans, even the last one',
    (tester) async {
      final api = _api(SkillNodeState.completed);
      await tester.pumpWidget(_reviewLesson(api));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsNothing); // no beans shown

      await tester.tap(find.text('le')); // wrong, with 1 bean at start
      await tester.pumpAndSettle();

      expect(find.text('Out of Beans!'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets('a finished review shows how it went, not XP', (tester) async {
    final api = _api(SkillNodeState.completed);
    await tester.pumpWidget(_reviewLesson(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ha'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.completeLessonCalls, hasLength(1));
    expect(find.text('Review Complete!'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('XP EARNED'), findsNothing);
  });

  testWidgets('offline, a review is queued and promises no XP', (
    tester,
  ) async {
    final api = _api(SkillNodeState.completed);
    await tester.pumpWidget(_reviewLesson(api, online: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ha'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.completeLessonCalls, isEmpty);
    expect(find.text('Review Complete!'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });
}
