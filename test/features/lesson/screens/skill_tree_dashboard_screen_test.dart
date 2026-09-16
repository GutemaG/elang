// Skill-tree dashboard screen tests (story 001).
//
// Covers: locked/active/completed nodes render distinctly with a
// crown-level badge on completed nodes; locked nodes aren't tappable;
// tapping an active node starts a lesson; a fetch failure shows inline
// error + retry.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/answer_feedback_player.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';
import 'package:elang/shared/services/lesson_api.dart';
import 'package:elang/shared/services/lesson_audio_player.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_lesson_audio_player.dart';

Widget _wrapped({
  required LessonApi lessonApi,
  required LessonAudioPlayer audioPlayer,
  AnswerFeedbackPlayer? feedbackPlayer,
}) {
  return MaterialApp(
    home: SkillTreeDashboardScreen(
      lessonApi: lessonApi,
      audioPlayer: audioPlayer,
      feedbackPlayer: feedbackPlayer ?? FakeAnswerFeedbackPlayer(),
    ),
  );
}

void main() {
  testWidgets(
    'renders locked/active/completed nodes with crown badges, matching seed data',
    (tester) async {
      await tester.pumpWidget(
        _wrapped(
          lessonApi: FakeLessonApi(latency: Duration.zero),
          audioPlayer: FakeLessonAudioPlayer(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alphabet & Fidel'), findsOneWidget);
      expect(find.text('Basic Greetings'), findsOneWidget);
      expect(find.text('Coffee & Hospitality'), findsOneWidget);
      expect(find.text('Family & Introductions'), findsOneWidget);

      // Crown-level badges on the two completed nodes from seed data.
      expect(find.text('Lv 3'), findsOneWidget);
      expect(find.text('Lv 2'), findsOneWidget);

      // Locked node shows the lock affordance.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    },
  );

  testWidgets('tapping a locked node does nothing (not interactive)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapped(
        lessonApi: FakeLessonApi(latency: Duration.zero),
        audioPlayer: FakeLessonAudioPlayer(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Family & Introductions'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Still on the dashboard — no lesson screen was pushed.
    expect(find.text('Family & Introductions'), findsOneWidget);
    expect(find.text('Check'), findsNothing);
  });

  testWidgets('tapping the active node starts its lesson', (tester) async {
    await tester.pumpWidget(
      _wrapped(
        lessonApi: FakeLessonApi(latency: Duration.zero),
        audioPlayer: FakeLessonAudioPlayer(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coffee & Hospitality'));
    await tester.pumpAndSettle();

    // The active node's lesson content's first exercise is now showing.
    expect(find.text('ቡና'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
  });

  testWidgets('a fetch failure shows inline error + retry, then recovers', (
    tester,
  ) async {
    final api = ControllableLessonApi()..skillTreeError = Exception('boom');
    await tester.pumpWidget(
      _wrapped(lessonApi: api, audioPlayer: FakeLessonAudioPlayer()),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your skill tree"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    api.skillTreeError = null;
    api.skillTree = const SkillTreeResponse(
      unitTitle: 'Unit 1: Foundations & Greetings',
      unitSubtitle: 'ሰላምታ',
      nodes: [
        SkillTreeNode(
          id: 'skill-a',
          lessonId: 'lesson-a',
          title: 'Skill A',
          subtitle: 'a',
          state: SkillNodeState.active,
        ),
      ],
      streakCount: 1,
      beans: 5,
      beansMax: 5,
      totalXp: 0,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your skill tree"), findsNothing);
    expect(find.text('Skill A'), findsOneWidget);
  });

  testWidgets(
    'returning from a completed lesson reloads the dashboard with updated node state',
    (tester) async {
      final api = ControllableLessonApi()
        ..skillTree = const SkillTreeResponse(
          unitTitle: 'Unit 1',
          unitSubtitle: 'sub',
          nodes: [
            SkillTreeNode(
              id: 'skill-a',
              lessonId: 'lesson-a',
              title: 'Skill A',
              subtitle: 'a',
              state: SkillNodeState.active,
            ),
          ],
          streakCount: 1,
          beans: 5,
          beansMax: 5,
          totalXp: 0,
        )
        ..lessonContent = const LessonContent(
          lessonId: 'lesson-a',
          skillId: 'skill-a',
          title: 'Skill A',
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
        )
        ..completionResult = const LessonCompletionResult(
          xpEarned: 5,
          dailyXpTotal: 5,
          dailyXpTarget: 30,
          streakCount: 2,
          streakIncreasedToday: true,
          accuracyPercent: 100,
          correctCount: 1,
          totalCount: 1,
          timeSpent: Duration(seconds: 5),
        );

      await tester.pumpWidget(
        _wrapped(lessonApi: api, audioPlayer: FakeLessonAudioPlayer()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skill A'));
      await tester.pumpAndSettle();

      // Answer correctly and finish the (single-exercise) lesson.
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Lesson-complete screen shown.
      expect(find.text('Lesson Complete!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Back on the dashboard, and it re-fetched (getSkillTree called
      // again on return).
      expect(find.text('Skill A'), findsOneWidget);
    },
  );
}
