import 'package:flutter/foundation.dart' show listEquals;

/// One exercise within a lesson.
///
/// A sealed class (matching `AuthResult`'s existing pattern in this
/// codebase) so `LessonController`'s grading and `LessonScreen`'s
/// exercise-type switch are both exhaustive at compile time.
///
/// NOTE (see `implementation-plan.md`'s Checkpoint Decisions): each
/// exercise carries its own correct answer so grading can happen
/// client-side with zero network round trips, per the "no per-exercise
/// network call" NFR. A real backend contract may not want to ship the
/// answer key to the client — that's an explicit open item for
/// `001-lesson-service`'s Technical Design, not decided here.
sealed class Exercise {
  const Exercise({required this.id});

  final String id;
}

class MultipleChoiceExercise extends Exercise {
  const MultipleChoiceExercise({
    required super.id,
    required this.prompt,
    required this.promptTranslation,
    required this.options,
    required this.correctOptionIndex,
  });

  /// The Amharic (or Afaan Oromo) prompt to translate/answer.
  final String prompt;

  /// English gloss shown beneath the prompt.
  final String promptTranslation;
  final List<String> options;
  final int correctOptionIndex;
}

class ListeningExercise extends Exercise {
  const ListeningExercise({
    required super.id,
    required this.audioUrl,
    required this.instruction,
    required this.options,
    required this.correctOptionIndex,
  });

  /// Cloudflare R2 (or, in the fake, a placeholder) URL for the audio clip.
  final String audioUrl;
  final String instruction;
  final List<String> options;
  final int correctOptionIndex;
}

class SentenceConstructionExercise extends Exercise {
  const SentenceConstructionExercise({
    required super.id,
    required this.promptTranslation,
    required this.wordBank,
    required this.correctSentence,
  });

  /// English sentence the learner builds the Amharic translation of.
  final String promptTranslation;

  /// Tappable tokens, including distractors, in fixed (already shuffled)
  /// display order.
  final List<String> wordBank;

  /// The correct token order — a subset (or all) of [wordBank].
  final List<String> correctSentence;
}

/// Grades a submitted answer against [exercise], client-side.
///
/// [answer] must be an `int` (the selected option index) for
/// [MultipleChoiceExercise]/[ListeningExercise], or a `List<String>` (the
/// learner's built token order) for [SentenceConstructionExercise].
bool isAnswerCorrect(Exercise exercise, Object answer) {
  return switch (exercise) {
    MultipleChoiceExercise e => answer == e.correctOptionIndex,
    ListeningExercise e => answer == e.correctOptionIndex,
    SentenceConstructionExercise e =>
      answer is List<String> && listEquals(answer, e.correctSentence),
  };
}
