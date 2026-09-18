import 'exercise.dart';

/// One vocab item due for review, resolved to its full exercise content
/// (bolt 020-practice-ui, story 004) -- fetched via `LessonApi.getDueItems`
/// and rendered through the exact same exercise-engine widgets a regular
/// lesson uses.
class DueItem {
  const DueItem({
    required this.vocabItemId,
    required this.word,
    required this.translation,
    required this.exercise,
    required this.boxLevel,
    required this.nextReviewAt,
  });

  final String vocabItemId;
  final String word;
  final String translation;
  final Exercise exercise;
  final int boxLevel;
  final DateTime nextReviewAt;
}
