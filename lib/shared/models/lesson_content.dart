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
  });

  final String lessonId;
  final String skillId;
  final String title;
  final List<Exercise> exercises;

  /// The account's beans balance as of lesson start — the local
  /// `LessonController` counts down from this, never re-reading the
  /// server mid-lesson.
  final int beansAtStart;
  final int beansMax;
}
