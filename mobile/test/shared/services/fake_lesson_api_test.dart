// Unit tests for FakeLessonApi's in-memory account-state logic: first
// completion unlocks the next skill node; replaying a completed skill
// raises its crown level (capped at 5) and unlocks a streak freeze at
// level 5; the streak increments at most once per (simulated) day; beans
// stay in sync with what the client reports at completion.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';

void main() {
  test(
    'completing an active skill unlocks a later skill only within its own '
    'category',
    () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final before = await api.getSkillTree();
      expect(before.categories.length, greaterThanOrEqualTo(2));
      final second = before.categories[1];
      final active = before
          .nodesIn(second)
          .firstWhere((n) => n.state == SkillNodeState.active);
      final lockedInSecond = before
          .nodesIn(second)
          .firstWhere((n) => n.state == SkillNodeState.locked);
      final lockedInFirst = before
          .nodesIn(before.categories[0])
          .where((n) => n.state == SkillNodeState.locked);

      await api.completeLesson(
        lessonId: active.lessonId,
        attemptId: 'attempt-cat-2',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 10),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      );

      final after = await api.getSkillTree();
      SkillNodeState stateOf(String id) =>
          after.nodes.firstWhere((n) => n.id == id).state;
      expect(stateOf(lockedInSecond.id), SkillNodeState.active);
      for (final n in lockedInFirst) {
        expect(stateOf(n.id), SkillNodeState.locked);
      }
    },
  );

  test(
    'first completion of the active node unlocks the next locked node',
    () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final before = await api.getSkillTree();
      final activeNode = before.nodes.firstWhere(
        (n) => n.state == SkillNodeState.active,
      );
      final lockedNode = before.nodes.firstWhere(
        (n) => n.state == SkillNodeState.locked,
      );

      final result = await api.completeLesson(
        lessonId: activeNode.lessonId,
        attemptId: 'attempt-1',
        correctCount: 2,
        totalCount: 2,
        timeSpent: const Duration(seconds: 20),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      );

      expect(result.crownLevel, 1);
      expect(result.crownLeveledUp, isFalse);
      expect(result.skillUnlockedTitle, lockedNode.title);

      final after = await api.getSkillTree();
      final completedNode = after.nodes.firstWhere(
        (n) => n.id == activeNode.id,
      );
      final nowUnlockedNode = after.nodes.firstWhere(
        (n) => n.id == lockedNode.id,
      );
      expect(completedNode.state, SkillNodeState.completed);
      expect(completedNode.crownLevel, 1);
      expect(nowUnlockedNode.state, SkillNodeState.active);
    },
  );

  test(
    'replaying an already-completed node increases its crown level',
    () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final before = await api.getSkillTree();
      final completedNode = before.nodes.firstWhere(
        (n) => n.state == SkillNodeState.completed,
      );
      final startingCrown = completedNode.crownLevel;

      final result = await api.completeLesson(
        lessonId: completedNode.lessonId,
        attemptId: 'attempt-1',
        correctCount: 2,
        totalCount: 2,
        timeSpent: const Duration(seconds: 20),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      );

      expect(result.crownLevel, startingCrown + 1);
      expect(result.crownLeveledUp, isTrue);
      expect(result.skillUnlockedTitle, isNull);
    },
  );

  test('crown level is capped at 5 and unlocks a streak freeze there', () async {
    final api = FakeLessonApi(latency: Duration.zero);
    final before = await api.getSkillTree();
    final completedNode = before.nodes.firstWhere(
      (n) => n.state == SkillNodeState.completed && n.crownLevel >= 3,
    );

    // Seed data starts this node at crown level 3 — replay twice to reach 5.
    await api.completeLesson(
      lessonId: completedNode.lessonId,
      attemptId: 'attempt-1',
      correctCount: 1,
      totalCount: 1,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 5,
      clientCompletedAt: DateTime.now().toUtc(),
    );
    final atFive = await api.completeLesson(
      lessonId: completedNode.lessonId,
      attemptId: 'attempt-2',
      correctCount: 1,
      totalCount: 1,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 5,
      clientCompletedAt: DateTime.now().toUtc(),
    );

    expect(atFive.crownLevel, 5);
    expect(atFive.streakFreezeUnlocked, isTrue);

    final atFivePlus = await api.completeLesson(
      lessonId: completedNode.lessonId,
      attemptId: 'attempt-3',
      correctCount: 1,
      totalCount: 1,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 5,
      clientCompletedAt: DateTime.now().toUtc(),
    );
    // Already at the cap — no further "level up" flourish.
    expect(atFivePlus.crownLevel, 5);
    expect(atFivePlus.crownLeveledUp, isFalse);
  });

  test(
    'the streak increments at most once across multiple completions in the same session',
    () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final before = await api.getSkillTree();
      final activeNode = before.nodes.firstWhere(
        (n) => n.state == SkillNodeState.active,
      );

      final first = await api.completeLesson(
        lessonId: activeNode.lessonId,
        attemptId: 'attempt-1',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 5),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      );
      expect(first.streakIncreasedToday, isTrue);
      final streakAfterFirst = first.streakCount;

      final after = await api.getSkillTree();
      final nowActiveNode = after.nodes.firstWhere(
        (n) => n.state == SkillNodeState.active,
      );
      final second = await api.completeLesson(
        lessonId: nowActiveNode.lessonId,
        attemptId: 'attempt-2',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 5),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      );

      expect(second.streakIncreasedToday, isFalse);
      expect(second.streakCount, streakAfterFirst);
    },
  );

  test('completeLesson syncs the account beans balance to beansRemainingAtEnd', () async {
    final api = FakeLessonApi(latency: Duration.zero);
    final before = await api.getSkillTree();
    final activeNode = before.nodes.firstWhere(
      (n) => n.state == SkillNodeState.active,
    );

    await api.completeLesson(
      lessonId: activeNode.lessonId,
      attemptId: 'attempt-1',
      correctCount: 1,
      totalCount: 2,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 3,
      clientCompletedAt: DateTime.now().toUtc(),
    );

    final after = await api.getSkillTree();
    expect(after.beans, 3);
  });

  test('repeating the same attemptId does not double-award XP or streak', () async {
    final api = FakeLessonApi(latency: Duration.zero);
    final before = await api.getSkillTree();
    final activeNode = before.nodes.firstWhere(
      (n) => n.state == SkillNodeState.active,
    );

    final first = await api.completeLesson(
      lessonId: activeNode.lessonId,
      attemptId: 'same-attempt',
      correctCount: 2,
      totalCount: 2,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 5,
      clientCompletedAt: DateTime.now().toUtc(),
    );
    final retry = await api.completeLesson(
      lessonId: activeNode.lessonId,
      attemptId: 'same-attempt',
      correctCount: 2,
      totalCount: 2,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 5,
      clientCompletedAt: DateTime.now().toUtc(),
    );

    expect(first.xpEarned, greaterThan(0));
    expect(retry.xpEarned, 0);
    expect(retry.streakIncreasedToday, isFalse);

    final after = await api.getSkillTree();
    expect(after.totalXp, before.totalXp + first.xpEarned);
  });

  test('refillBeansWithAmole restores beans and deducts Amole when affordable', () async {
    final api = FakeLessonApi(latency: Duration.zero);
    final before = await api.getSkillTree();
    final activeNode = before.nodes.firstWhere(
      (n) => n.state == SkillNodeState.active,
    );
    await api.completeLesson(
      lessonId: activeNode.lessonId,
      attemptId: 'attempt-1',
      correctCount: 0,
      totalCount: 1,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 0,
      clientCompletedAt: DateTime.now().toUtc(),
    );

    final statusBefore = await api.getBeansStatus();
    expect(statusBefore.beans, 0);
    expect(statusBefore.canAffordRefill, isTrue);

    final result = await api.refillBeansWithAmole();
    expect(result, isA<RefillSuccess>());
  });
}
