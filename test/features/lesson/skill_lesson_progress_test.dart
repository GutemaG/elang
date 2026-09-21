// A skill is made of several lessons and turns green only when all of them
// are done. These tests pin how that progress is shown: a ring and "1/2" on a
// part-way node, and how many lessons are left (or that the skill is
// finished) on the summary.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_complete_screen.dart';
import 'package:elang/features/lesson/widgets/skill_path_node.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/skill_lesson_progress.dart';
import 'package:elang/shared/models/skill_tree.dart';

SkillTreeNode _node({
  SkillNodeState state = SkillNodeState.active,
  int done = 1,
  int count = 2,
}) => SkillTreeNode(
  id: 'skill:numbers',
  lessonId: 'numbers:six-to-ten',
  title: 'Numbers',
  subtitle: '',
  state: state,
  categoryId: 'cat',
  crownLevel: state == SkillNodeState.completed ? 1 : 0,
  lessonsDone: done,
  lessonCount: count,
);

const _result = LessonCompletionResult(
  xpEarned: 20,
  dailyXpTotal: 20,
  dailyXpTarget: 30,
  streakCount: 2,
  streakIncreasedToday: false,
  accuracyPercent: 100,
  correctCount: 2,
  totalCount: 2,
  timeSpent: Duration(seconds: 30),
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SkillTreeNode lesson counts', () {
    test('survive the offline cache round trip', () {
      final back = SkillTreeNode.fromJson(_node().toJson());

      expect(back.lessonsDone, 1);
      expect(back.lessonCount, 2);
    });

    test('default to 0 for a cache written before they existed', () {
      final json = _node().toJson()
        ..remove('lessons_done')
        ..remove('lesson_count');

      final back = SkillTreeNode.fromJson(json);

      expect(back.lessonsDone, 0);
      expect(back.lessonCount, 0);
      expect(back.isPartlyDone, isFalse);
    });

    test('count as part-way only when started but not finished', () {
      expect(_node(done: 1, count: 2).isPartlyDone, isTrue);
      expect(_node(done: 0, count: 2).isPartlyDone, isFalse);
      expect(_node(done: 2, count: 2).isPartlyDone, isFalse);
      expect(_node(done: 0, count: 1).isPartlyDone, isFalse);
      expect(
        _node(state: SkillNodeState.completed, done: 1).isPartlyDone,
        isFalse,
      );
    });
  });

  group('SkillLessonProgress.forNode', () {
    test('names the next lesson and how many are left after it', () {
      final first = SkillLessonProgress.forNode(_node(done: 0))!;
      expect(first.lessonNumber, 1);
      expect(first.lessonsLeftAfter, 1);
      expect(first.finishesSkill, isFalse);

      final last = SkillLessonProgress.forNode(_node(done: 1))!;
      expect(last.lessonNumber, 2);
      expect(last.finishesSkill, isTrue);
    });

    test('says nothing for a one-lesson skill, a review, or no counts', () {
      expect(SkillLessonProgress.forNode(_node(done: 0, count: 1)), isNull);
      expect(SkillLessonProgress.forNode(_node(count: 0, done: 0)), isNull);
      expect(
        SkillLessonProgress.forNode(_node(state: SkillNodeState.completed)),
        isNull,
      );
    });
  });

  group('SkillPathNode', () {
    testWidgets('a part-way skill shows a ring and its lesson count', (
      tester,
    ) async {
      await tester.pumpWidget(_host(SkillPathNode(node: _node(done: 1))));

      expect(find.text('Numbers · 1/2'), findsOneWidget);
      expect(find.byKey(const ValueKey('skill-progress-ring')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('1 of 2 lessons done')),
        findsOneWidget,
      );
    });

    testWidgets('an unstarted or finished skill shows neither', (tester) async {
      await tester.pumpWidget(_host(SkillPathNode(node: _node(done: 0))));
      expect(find.text('Numbers'), findsOneWidget);
      expect(find.byKey(const ValueKey('skill-progress-ring')), findsNothing);

      await tester.pumpWidget(
        _host(SkillPathNode(node: _node(state: SkillNodeState.completed))),
      );
      expect(find.text('Numbers'), findsOneWidget);
      expect(find.byKey(const ValueKey('skill-progress-ring')), findsNothing);
    });
  });

  group('LessonCompleteScreen', () {
    testWidgets('after lesson 1 of 2, says one more is left', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LessonCompleteScreen(
            result: _result,
            skillProgress: SkillLessonProgress.forNode(_node(done: 0)),
          ),
        ),
      );

      expect(find.text('Lesson 1 of 2 done'), findsOneWidget);
      expect(find.text('1 more lesson to finish Numbers.'), findsOneWidget);
    });

    testWidgets('after the last lesson, says the skill is finished', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LessonCompleteScreen(
            result: const LessonCompletionResult(
              xpEarned: 20,
              dailyXpTotal: 20,
              dailyXpTarget: 30,
              streakCount: 2,
              streakIncreasedToday: false,
              accuracyPercent: 100,
              correctCount: 2,
              totalCount: 2,
              timeSpent: Duration(seconds: 30),
              skillUnlockedTitle: 'Time',
            ),
            skillProgress: SkillLessonProgress.forNode(_node(done: 1)),
          ),
        ),
      );

      expect(find.text('You finished Numbers!'), findsOneWidget);
      expect(find.text('Time is now unlocked.'), findsOneWidget);
    });

    testWidgets('without progress, shows no skill card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LessonCompleteScreen(result: _result)),
      );

      expect(find.textContaining('to finish'), findsNothing);
      expect(find.textContaining('You finished'), findsNothing);
    });
  });
}
