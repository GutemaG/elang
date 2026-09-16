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
  });

  final String attemptId;
  final String lessonId;
  final int correctCount;
  final int totalCount;
  final Duration timeSpent;
  final int beansRemainingAtEnd;
  final DateTime clientCompletedAt;
}
