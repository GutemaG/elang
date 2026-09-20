import 'exercise.dart';

/// Everything needed to run a lesson end-to-end, fetched in a single
/// request at lesson start (see `StartLesson` in the unit brief) and held
/// client-side for the whole attempt — no per-exercise round trip.
class LessonContent {
  const LessonContent({
    required this.lessonId,
    required this.skillId,
    required this.title,
    required this.exercises,
    required this.beansAtStart,
    required this.beansMax,
    this.contentVersion,
    this.unrenderableCount = 0,
  });

  final String lessonId;
  final String skillId;
  final String title;
  final List<Exercise> exercises;

  /// How many of the lesson's exercises this build could not render, and
  /// therefore dropped from [exercises].
  ///
  /// Forward compatibility: the server may serve an exercise type added
  /// after this client shipped. Before this field existed, one such
  /// exercise threw and took the whole lesson down — which is how a
  /// `spell_tiles` exercise (seeded by bolt `032`, client support pending
  /// in bolt `033`) made every lesson in every course unloadable.
  ///
  /// It must be carried rather than merely discarded, because
  /// `complete_lesson` rejects a `total_count` that disagrees with the
  /// lesson's own exercise count. Dropping an exercise silently would let
  /// a lesson play to the end and then fail with a 422, which is a worse
  /// failure than not loading at all. `LessonController` adds this back
  /// into both the total and the correct count, so a skipped exercise
  /// neither blocks completion nor costs the learner XP for something
  /// they were never shown.
  final int unrenderableCount;

  /// The account's beans balance as of lesson start — the local
  /// `LessonController` counts down from this, never re-reading the
  /// server mid-lesson.
  final int beansAtStart;
  final int beansMax;

  /// Offline-caching staleness signal (009-offline-caching-and-sync-ui,
  /// FR-1), stored alongside a downloaded pack so a later staleness check
  /// has something to compare against. `null` when not supplied (e.g. by
  /// an older fake) -- never required for a lesson to be playable.
  final DateTime? contentVersion;
}
