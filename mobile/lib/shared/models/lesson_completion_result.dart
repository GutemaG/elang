/// Mirrors the backend's `XP_PER_CORRECT_ANSWER` domain constant
/// (`app/domain/lesson/value_objects.py`) -- the one piece of server
/// business logic simple and stable enough to duplicate client-side, so a
/// lesson finished offline can show a real XP-earned number immediately
/// instead of a blank field (010-offline-caching-and-sync-ui, story 003).
/// Nothing else about streak/crown/daily-total progression is duplicated --
/// see [LessonCompletionResult.pendingSync].
const int kXpPerCorrectAnswer = 5;

/// Result of a successful `FinishLesson` call — everything the
/// lesson-complete summary (story 004) and the dashboard's refreshed node
/// state need.
class LessonCompletionResult {
  const LessonCompletionResult({
    required this.xpEarned,
    required this.dailyXpTotal,
    required this.dailyXpTarget,
    required this.streakCount,
    required this.streakIncreasedToday,
    required this.accuracyPercent,
    required this.correctCount,
    required this.totalCount,
    required this.timeSpent,
    this.skillUnlockedTitle,
    this.crownLevel,
    this.crownLeveledUp = false,
    this.streakFreezeUnlocked = false,
    this.pendingSync = false,
    this.isReview = false,
  });

  final int xpEarned;
  final int dailyXpTotal;
  final int dailyXpTarget;
  final int streakCount;

  /// True only if this completion is what pushed the streak forward today
  /// (streak increments at most once per calendar day, per FR-4).
  final bool streakIncreasedToday;

  final int accuracyPercent;
  final int correctCount;
  final int totalCount;
  final Duration timeSpent;

  /// Set when finishing this lesson unlocked the next skill node.
  final String? skillUnlockedTitle;

  /// The completed skill's new crown level (1-5), if this lesson completed
  /// (or replayed) a skill.
  final int? crownLevel;

  /// True when [crownLevel] increased from a prior completion (a replay),
  /// as opposed to the first-ever completion (which sets crown level 1
  /// without counting as a "level up" flourish).
  final bool crownLeveledUp;

  /// True when reaching [crownLevel] also unlocked a streak-freeze
  /// consumable (FR-4), shown via the level-up modal.
  final bool streakFreezeUnlocked;

  /// True when this result came from an offline completion that was queued
  /// rather than confirmed by the server (010-offline-caching-and-sync-ui,
  /// story 003). [xpEarned]/[accuracyPercent]/[correctCount]/[totalCount]/
  /// [timeSpent] are still exact (client-known); [dailyXpTotal]/
  /// [streakCount]/[streakIncreasedToday]/crown fields are not yet known
  /// and hold safe defaults -- `LessonCompleteScreen` shows a "syncs when
  /// back online" placeholder for those instead of a guessed number.
  final bool pendingSync;

  /// The skill was already completed, so this attempt was a review: no XP,
  /// Amole, crown, streak or beans change.
  final bool isReview;

  bool get hasLevelUpFlourish => crownLeveledUp || streakFreezeUnlocked;
}
