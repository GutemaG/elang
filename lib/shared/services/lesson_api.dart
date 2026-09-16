import '../models/beans_status.dart';
import '../models/lesson_completion_result.dart';
import '../models/lesson_content.dart';
import '../models/skill_tree.dart';

/// The `001-lesson-service` boundary this UI needs, independent of that
/// backend unit's eventual real contract.
///
/// Mirrors `AuthApi`'s role from `002-auth-onboarding-ui`: a thin interface
/// built and tested against `FakeLessonApi` in this bolt, with the real
/// HTTP implementation deferred to bolt 007 once `001-lesson-service` is
/// implemented. No screen or controller built against this interface
/// should need to change when that swap happens.
abstract class LessonApi {
  /// `LoadSkillTree` — fetches the dashboard's current unit banner, nodes,
  /// and HUD stats.
  Future<SkillTreeResponse> getSkillTree();

  /// `StartLesson` — fetches every exercise for [lessonId] in one request,
  /// plus the account's current beans balance. Never called again for the
  /// same attempt (no per-exercise round trip).
  Future<LessonContent> startLesson(String lessonId);

  /// `FinishLesson` — reports a completed attempt and gets back the
  /// XP/streak/crown-level outcome. [beansRemainingAtEnd] syncs the
  /// account's beans balance with whatever local deductions happened
  /// during the attempt (see `implementation-plan.md`).
  ///
  /// [attemptId] is generated once per lesson attempt by [LessonController]
  /// (see its constructor) and stays the same across any retry of this same
  /// completion call — the idempotency key `001-lesson-service`'s
  /// `POST /lessons/{id}/complete` uses to guarantee XP is awarded exactly
  /// once even if this call is retried after a network blip (bolt 005's
  /// ADR-5, Decision 2).
  ///
  /// Never called for an interrupted (out-of-beans, dismissed) attempt —
  /// that's what keeps "no partial XP on interruption" true.
  Future<LessonCompletionResult> completeLesson({
    required String lessonId,
    required String attemptId,
    required int correctCount,
    required int totalCount,
    required Duration timeSpent,
    required int beansRemainingAtEnd,
  });

  /// Current beans/refill state, for the out-of-beans modal.
  Future<BeansStatus> getBeansStatus();

  /// Attempts an immediate refill using the account's Amole balance.
  Future<RefillResult> refillBeansWithAmole();
}
