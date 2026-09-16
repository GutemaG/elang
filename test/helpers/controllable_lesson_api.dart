// Test double for [LessonApi] with full manual control over each call's
// result, used where `FakeLessonApi`'s baked-in seed data/timing isn't
// precise enough (e.g. forcing beans to run out on the first wrong
// answer, or asserting exactly what `completeLesson` was called with).
//
// Mocking here is at the network boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention —
// `LessonController` always runs for real against this double.

import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/lesson_api.dart';

class CompleteLessonCall {
  CompleteLessonCall({
    required this.lessonId,
    required this.attemptId,
    required this.correctCount,
    required this.totalCount,
    required this.timeSpent,
    required this.beansRemainingAtEnd,
  });

  final String lessonId;
  final String attemptId;
  final int correctCount;
  final int totalCount;
  final Duration timeSpent;
  final int beansRemainingAtEnd;
}

class ControllableLessonApi implements LessonApi {
  SkillTreeResponse? skillTree;
  Object? skillTreeError;
  LessonContent? lessonContent;
  LessonCompletionResult? completionResult;

  /// When set, `completeLesson` throws this instead of returning
  /// [completionResult] -- simulates a backend/network failure during
  /// completion (story 005's edge case). Cleared by the test between a
  /// failed attempt and a successful retry.
  Object? completeLessonError;
  BeansStatus? beansStatus;
  RefillResult? refillResult;

  final List<CompleteLessonCall> completeLessonCalls = [];
  int refillCallCount = 0;

  @override
  Future<SkillTreeResponse> getSkillTree() async {
    if (skillTreeError != null) throw skillTreeError!;
    return skillTree!;
  }

  @override
  Future<LessonContent> startLesson(String lessonId) async => lessonContent!;

  @override
  Future<LessonCompletionResult> completeLesson({
    required String lessonId,
    required String attemptId,
    required int correctCount,
    required int totalCount,
    required Duration timeSpent,
    required int beansRemainingAtEnd,
  }) async {
    completeLessonCalls.add(
      CompleteLessonCall(
        lessonId: lessonId,
        attemptId: attemptId,
        correctCount: correctCount,
        totalCount: totalCount,
        timeSpent: timeSpent,
        beansRemainingAtEnd: beansRemainingAtEnd,
      ),
    );
    if (completeLessonError != null) throw completeLessonError!;
    return completionResult!;
  }

  @override
  Future<BeansStatus> getBeansStatus() async => beansStatus!;

  @override
  Future<RefillResult> refillBeansWithAmole() async {
    refillCallCount++;
    return refillResult!;
  }
}
