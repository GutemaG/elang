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

  bool get hasLevelUpFlourish => crownLeveledUp || streakFreezeUnlocked;
}
