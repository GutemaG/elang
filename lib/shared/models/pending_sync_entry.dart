/// One offline-completed lesson attempt awaiting sync
/// (010-offline-caching-and-sync-ui, story 003).
///
/// Carries exactly the fields `LessonApi.completeLesson` needs -- syncing an
/// entry is just replaying that same call once connectivity returns
/// (`001-offline-sync-service`'s ADR-6: no batch-sync endpoint). No separate
/// "queued at" timestamp: [clientCompletedAt] already is the instant this
/// was queued, since an offline completion is queued the moment it happens.
class PendingSyncEntry {
  const PendingSyncEntry({
    required this.attemptId,
    required this.lessonId,
    required this.correctCount,
    required this.totalCount,
    required this.timeSpent,
    required this.beansRemainingAtEnd,
    required this.clientCompletedAt,
    this.missedExerciseIds = const [],
  });

  final String attemptId;
  final String lessonId;
  final int correctCount;
  final int totalCount;
  final Duration timeSpent;
  final int beansRemainingAtEnd;
  final DateTime clientCompletedAt;

  /// Bolt 019 (008-srs-and-practice, ADR-10): threaded through unchanged to
  /// the replayed `completeLesson` call once connectivity returns, so an
  /// offline-completed lesson's vocab progress is no less accurate than an
  /// online one's.
  final List<String> missedExerciseIds;
}
