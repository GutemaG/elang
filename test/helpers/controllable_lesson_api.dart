// Test double for [LessonApi] with full manual control over each call's
// result, used where `FakeLessonApi`'s baked-in seed data/timing isn't
// precise enough (e.g. forcing beans to run out on the first wrong
// answer, or asserting exactly what `completeLesson` was called with).
//
// Mocking here is at the network boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention —
// `LessonController` always runs for real against this double.

import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/due_item.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/practice_completion_result.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/lesson_api.dart';

class CompletePracticeSessionCall {
  CompletePracticeSessionCall({
    required this.sessionId,
    required this.results,
    required this.timeSpent,
  });

  final String sessionId;
  final List<PracticeResult> results;
  final Duration timeSpent;
}

class CompleteLessonCall {
  CompleteLessonCall({
    required this.lessonId,
    required this.attemptId,
    required this.correctCount,
    required this.totalCount,
    required this.timeSpent,
    required this.beansRemainingAtEnd,
    required this.clientCompletedAt,
    required this.missedExerciseIds,
  });

  final String lessonId;
  final String attemptId;
  final int correctCount;
  final int totalCount;
  final Duration timeSpent;
  final int beansRemainingAtEnd;
  final DateTime clientCompletedAt;
  final List<String> missedExerciseIds;
}

class ControllableLessonApi implements LessonApi {
  SkillTreeResponse? skillTree;
  Object? skillTreeError;
  LessonContent? lessonContent;

  /// When set, `startLesson` throws this instead of returning
  /// [lessonContent] -- simulates a backend/network failure while
  /// downloading a lesson pack (009-offline-caching-and-sync-ui's
  /// download-failure edge case).
  Object? startLessonError;
  LessonCompletionResult? completionResult;

  /// When set, `completeLesson` throws this instead of returning
  /// [completionResult] -- simulates a backend/network failure during
  /// completion (story 005's edge case). Cleared by the test between a
  /// failed attempt and a successful retry.
  Object? completeLessonError;

  /// When set, `completeLesson` awaits this before returning/throwing --
  /// lets a test hold a call "in flight" to observe transient states (e.g.
  /// `SyncEngine`'s `syncing` status while a drain is actively running,
  /// 010-offline-caching-and-sync-ui's story 004).
  Future<void>? completeLessonGate;

  /// Attempt ids that should fail (with [completeLessonError], or a
  /// generic exception if that's unset) while every other attempt id
  /// succeeds -- lets a test simulate "the 2nd of 3 queued entries fails"
  /// without a single global failure flag affecting every call
  /// (`SyncEngine`'s "resumes correctly after a partial failure" case).
  Set<String> completeLessonFailingAttemptIds = {};
  BeansStatus? beansStatus;
  RefillResult? refillResult;

  final List<CompleteLessonCall> completeLessonCalls = [];
  int refillCallCount = 0;

  int? dueCount;
  List<DueItem>? dueItems;
  PracticeCompletionResult? practiceCompletionResult;
  Object? completePracticeSessionError;
  final List<CompletePracticeSessionCall> completePracticeSessionCalls = [];

  @override
  Future<SkillTreeResponse> getSkillTree() async {
    if (skillTreeError != null) throw skillTreeError!;
    return skillTree!;
  }

  @override
  Future<LessonContent> startLesson(String lessonId) async {
    if (startLessonError != null) throw startLessonError!;
    return lessonContent!;
  }

  @override
  Future<LessonCompletionResult> completeLesson({
    required String lessonId,
    required String attemptId,
    required int correctCount,
    required int totalCount,
    required Duration timeSpent,
    required int beansRemainingAtEnd,
    required DateTime clientCompletedAt,
    List<String> missedExerciseIds = const [],
  }) async {
    completeLessonCalls.add(
      CompleteLessonCall(
        lessonId: lessonId,
        attemptId: attemptId,
        correctCount: correctCount,
        totalCount: totalCount,
        timeSpent: timeSpent,
        beansRemainingAtEnd: beansRemainingAtEnd,
        clientCompletedAt: clientCompletedAt,
        missedExerciseIds: missedExerciseIds,
      ),
    );
    if (completeLessonGate != null) await completeLessonGate;
    if (completeLessonFailingAttemptIds.contains(attemptId)) {
      throw completeLessonError ?? Exception('forced failure for $attemptId');
    }
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

  @override
  Future<int> getDueCount() async => dueCount!;

  @override
  Future<List<DueItem>> getDueItems({int limit = 20}) async => dueItems!;

  @override
  Future<PracticeCompletionResult> completePracticeSession({
    required String sessionId,
    required List<PracticeResult> results,
    required Duration timeSpent,
  }) async {
    completePracticeSessionCalls.add(
      CompletePracticeSessionCall(
        sessionId: sessionId,
        results: results,
        timeSpent: timeSpent,
      ),
    );
    if (completePracticeSessionError != null) {
      throw completePracticeSessionError!;
    }
    return practiceCompletionResult!;
  }
}
