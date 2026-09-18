/// One graded vocab item to report at Practice-session completion (bolt
/// 020-practice-ui, story 002).
class PracticeResult {
  const PracticeResult({required this.vocabItemId, required this.correct});

  final String vocabItemId;
  final bool correct;
}

/// Result of a successful `completePracticeSession` call -- deliberately
/// smaller than `LessonCompletionResult`: no streak/crown/skill-unlock
/// fields, since Practice doesn't touch those (this bolt's Plan-stage
/// decision).
class PracticeCompletionResult {
  const PracticeCompletionResult({
    required this.xpEarned,
    required this.amoleEarned,
    required this.correctCount,
    required this.totalCount,
    required this.accuracyPercent,
  });

  final int xpEarned;
  final int amoleEarned;
  final int correctCount;
  final int totalCount;
  final int accuracyPercent;
}
