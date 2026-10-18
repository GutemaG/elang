// 026-lesson-path-nodes: one bubble per lesson on the home path, under its
// skill's label; each lesson's state, popover and what a tap starts; no
// "Lesson N of M" once lessons are bubbles; a tree without lessons drawn
// one bubble per skill, as before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/lesson/widgets/skill_path_node.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_api.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/widgets/path_node.dart';
import 'package:elang/shared/widgets/path_popover.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';
import '../../../helpers/skill_path.dart';

const _category = SkillCategory(
  id: 'cat-a',
  title: 'First conversations',
  subtitle: '',
);

/// Letters is done (crown 2, a new pass not started), Greetings is part
/// way through (Hello done), Food is locked.
const _skills = [
  SkillTreeNode(
    id: 'skill-letters',
    lessonId: 'l-a',
    title: 'Letters',
    subtitle: '',
    state: SkillNodeState.completed,
    categoryId: 'cat-a',
    crownLevel: 2,
    lessonCount: 2,
    lessons: [
      SkillLesson(id: 'l-a', title: 'Letter A', done: false),
      SkillLesson(id: 'l-b', title: 'Letter B', done: false),
    ],
  ),
  SkillTreeNode(
    id: 'skill-greetings',
    lessonId: 'l-how',
    title: 'Greetings',
    subtitle: '',
    state: SkillNodeState.active,
    categoryId: 'cat-a',
    lessonsDone: 1,
    lessonCount: 3,
    lessons: [
      SkillLesson(id: 'l-hello', title: 'Hello & goodbye', done: true),
      SkillLesson(id: 'l-how', title: 'How are you?', done: false),
      SkillLesson(id: 'l-thanks', title: 'Thank you & sorry', done: false),
    ],
  ),
  SkillTreeNode(
    id: 'skill-food',
    lessonId: 'l-coffee',
    title: 'Food',
    subtitle: '',
    state: SkillNodeState.locked,
    categoryId: 'cat-a',
    lessonCount: 2,
    lessons: [
      SkillLesson(id: 'l-coffee', title: 'Coffee', done: false),
      SkillLesson(id: 'l-tea', title: 'Tea', done: false),
    ],
  ),
];

SkillTreeResponse _tree(List<SkillTreeNode> nodes) => SkillTreeResponse(
  categories: const [_category],
  nodes: nodes,
  streakCount: 1,
  beans: 5,
  beansMax: 5,
  totalXp: 0,
);

ControllableLessonApi _api(SkillTreeResponse tree) => ControllableLessonApi()
  ..skillTree = tree
  ..beansStatus = const BeansStatus(
    beans: 5,
    beansMax: 5,
    regenMinutesPerBean: 30,
    amoleBalance: 0,
    refillCostAmole: 350,
  )
  ..dueCount = 0
  ..lessonContent = const LessonContent(
    lessonId: 'l-how',
    skillId: 'skill-greetings',
    title: 'How are you?',
    beansAtStart: 5,
    beansMax: 5,
    exercises: [
      MultipleChoiceExercise(
        id: 'ex-1',
        prompt: 'ሀ',
        promptTranslation: 'sound?',
        options: ['ha', 'le'],
        correctOptionIndex: 0,
      ),
    ],
  );

Future<void> _pump(WidgetTester tester, LessonApi api) async {
  // Tall enough for the whole path, so every bubble can be tapped.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sessions = SessionRepository(storage: InMemorySecureStorageService());
  final connectivity = FakeConnectivityMonitor();
  await tester.pumpWidget(
    MaterialApp(
      home: SkillTreeDashboardScreen(
        lessonApi: api,
        audioPlayer: FakeLessonAudioPlayer(),
        feedbackPlayer: FakeAnswerFeedbackPlayer(),
        connectivityMonitor: connectivity,
        lessonPackStore: FakeLessonPackStore(),
        lessonPackDownloader: LessonPackDownloader(
          lessonApi: api,
          packStore: FakeLessonPackStore(),
        ),
        syncEngine: SyncEngine(
          lessonApi: api,
          connectivityMonitor: connectivity,
          queueStore: FakePendingSyncQueueStore(),
        ),
        courseApi: FakeCourseApi(),
        sessionRepository: sessions,
        userPreferencesApi: HttpUserPreferencesApi(sessionRepository: sessions),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PathStop _stop(WidgetTester tester, String title) =>
    tester.widget<SkillPathNode>(findSkill(title)).stop;

Future<void> _closePopover(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(PathPopover))).pop();
  await tester.pumpAndSettle();
}

void main() {
  group('the path', () {
    testWidgets('has a bubble per lesson, under its skill’s label', (
      tester,
    ) async {
      await _pump(tester, _api(_tree(_skills)));

      expect(find.byType(SkillPathNode), findsNWidgets(7));
      for (final title in ['Letters', 'Greetings', 'Food']) {
        expect(
          find.descendant(
            of: find.byType(PathSkillLabel),
            matching: find.text(title),
          ),
          findsOneWidget,
        );
      }
      // The crown is on the completed skill's label, not on its bubbles.
      expect(
        find.descendant(
          of: find.byType(PathSkillLabel),
          matching: find.byType(PathCrownBadge),
        ),
        findsOneWidget,
      );
      expect(find.text('Lv 2'), findsOneWidget);
      // No ring and no "Continue" on a lesson bubble.
      expect(find.byKey(PathNode.progressRingKey), findsNothing);
      expect(find.text('CONTINUE'), findsNothing);
      // The section header counts lessons: Letter A, B and Hello of 7.
      expect(find.bySemanticsLabel(RegExp('3 of 7 completed')), findsOneWidget);
    });

    testWidgets('gives each lesson its state', (tester) async {
      await _pump(tester, _api(_tree(_skills)));

      expect(_stop(tester, 'Letter A').state, SkillNodeState.completed);
      expect(_stop(tester, 'Letter B').state, SkillNodeState.completed);
      expect(_stop(tester, 'Hello & goodbye').state, SkillNodeState.completed);
      expect(_stop(tester, 'How are you?').state, SkillNodeState.active);
      expect(_stop(tester, 'Thank you & sorry').state, SkillNodeState.locked);
      expect(_stop(tester, 'Coffee').state, SkillNodeState.locked);
      expect(_stop(tester, 'Tea').state, SkillNodeState.locked);
      // Only the current lesson wears the Start bubble.
      expect(find.byKey(PathNode.calloutKey), findsOneWidget);
    });

    testWidgets('a tree without lessons is one bubble per skill, as before', (
      tester,
    ) async {
      final old = [
        for (final s in _skills)
          SkillTreeNode(
            id: s.id,
            lessonId: s.lessonId,
            title: s.title,
            subtitle: '',
            state: s.state,
            categoryId: s.categoryId,
            crownLevel: s.crownLevel,
            lessonsDone: s.lessonsDone,
            lessonCount: s.lessonCount,
          ),
      ];
      await _pump(tester, _api(_tree(old)));

      expect(find.byType(SkillPathNode), findsNWidgets(3));
      expect(find.byType(PathSkillLabel), findsNothing);
      expect(find.byKey(PathNode.progressRingKey), findsOneWidget);

      await openSkill(tester, 'Greetings');
      expect(find.text('Lesson 2 of 3'), findsOneWidget);
    });
  });

  group('a lesson’s popover', () {
    testWidgets('names the lesson and says what it can do', (tester) async {
      await _pump(tester, _api(_tree(_skills)));

      await openSkill(tester, 'How are you?');
      expect(
        find.descendant(
          of: find.byType(PathPopover),
          matching: find.text('How are you?'),
        ),
        findsOneWidget,
      );
      expect(find.text('Ready when you are.'), findsOneWidget);
      expect(find.byKey(PathPopover.actionKey), findsOneWidget);
      expect(find.textContaining('Lesson 1 of'), findsNothing);
      await _closePopover(tester);

      await openSkill(tester, 'Thank you & sorry');
      expect(
        find.text('Finish the lesson above to unlock this one.'),
        findsOneWidget,
      );
      // A locked bubble's button only says it is locked.
      expect(
        find.descendant(
          of: find.byKey(PathPopover.actionKey),
          matching: find.textContaining(RegExp('locked', caseSensitive: false)),
        ),
        findsOneWidget,
      );
      await _closePopover(tester);

      await openSkill(tester, 'Coffee');
      expect(
        find.text('Finish the skills above to unlock this one.'),
        findsOneWidget,
      );
      await _closePopover(tester);

      await openSkill(tester, 'Hello & goodbye');
      expect(
        find.text("You've done this lesson. Play it again any time."),
        findsOneWidget,
      );
      expect(find.byKey(PathPopover.actionKey), findsOneWidget);
      await _closePopover(tester);

      await openSkill(tester, 'Letter B');
      expect(
        find.text(
          "You've completed this skill. Reviews don't earn XP or use beans.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('starts the tapped lesson, with no skill progress', (
      tester,
    ) async {
      await _pump(tester, _api(_tree(_skills)));

      await startSkill(tester, 'How are you?');

      final screen = tester.widget<LessonScreen>(find.byType(LessonScreen));
      expect(screen.lessonId, 'l-how');
      expect(screen.isReview, isFalse);
      expect(screen.skillProgress, isNull);
    });

    testWidgets('plays a done lesson again, and reviews a completed skill’s', (
      tester,
    ) async {
      await _pump(tester, _api(_tree(_skills)));

      await startSkill(tester, 'Hello & goodbye');
      var screen = tester.widget<LessonScreen>(find.byType(LessonScreen));
      expect(screen.lessonId, 'l-hello');
      expect(screen.isReview, isFalse);

      Navigator.of(tester.element(find.byType(LessonScreen))).pop();
      await tester.pumpAndSettle();

      await startSkill(tester, 'Letter B');
      screen = tester.widget<LessonScreen>(find.byType(LessonScreen));
      expect(screen.lessonId, 'l-b');
      expect(screen.isReview, isTrue);
    });
  });
}
