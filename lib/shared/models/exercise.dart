import 'package:flutter/foundation.dart' show listEquals, mapEquals;

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

/// One tappable tile in a [MatchPairsExercise]'s left or right column.
///
/// Needs a stable [id] (unlike [MultipleChoiceExercise.options]' plain
/// `List<String>`) because the two columns are shuffled independently —
/// position alone can no longer identify which left tile pairs with which
/// right tile.
class MatchPairsTile {
  const MatchPairsTile({required this.id, required this.text});

  final String id;
  final String text;
}

class MatchPairsExercise extends Exercise {
  const MatchPairsExercise({
    required super.id,
    required this.prompt,
    required this.leftTiles,
    required this.rightTiles,
    required this.correctPairs,
  });

  final String prompt;

  /// Two independently-shuffleable columns (left = Amharic terms, right =
  /// English translations).
  final List<MatchPairsTile> leftTiles;
  final List<MatchPairsTile> rightTiles;

  /// The correct association, `leftTileId -> rightTileId`. Served
  /// separately from the tiles themselves (mirroring
  /// `multiple_choice`'s `correctOptionIndex`) rather than embedded in the
  /// tiles — see 004-match-pairs-exercise-type's backend correction notes
  /// (bolt 011) for why a self-revealing content shape was rejected.
  final Map<String, String> correctPairs;
}

/// A sentence in the learning language with one word taken out, and the
/// words to choose between (015-gap-fill-exercise-type, bolt 031).
///
/// The sentence arrives as the text either side of the gap, so this class
/// never parses a marker out of a string — see `GapFillContent` on the
/// backend for why that shape was chosen. Either side may be empty, which
/// simply means the gap is at that end of the sentence.
///
/// Answered by index, like [MultipleChoiceExercise]: the API speaks in
/// choice ids, and `_toExercise` converts. Keeping gap-fill index-based
/// lets it reuse `LessonController.chooseOption` with no new state.
class GapFillExercise extends Exercise {
  const GapFillExercise({
    required super.id,
    required this.prompt,
    required this.sentenceBefore,
    required this.sentenceAfter,
    required this.options,
    required this.correctOptionIndex,
  });

  /// The instruction, already carrying the sentence's meaning in the
  /// learner's own language (e.g. "Complete the sentence: 'I want bread'").
  final String prompt;

  /// The sentence either side of the gap, already trimmed. The space around
  /// the gap belongs to the layout, not to the data.
  final String sentenceBefore;
  final String sentenceAfter;

  final List<String> options;
  final int correctOptionIndex;
}

/// Grades a submitted answer against [exercise], client-side.
///
/// [answer] must be an `int` (the selected option index) for
/// [MultipleChoiceExercise]/[ListeningExercise]/[GapFillExercise], a
/// `List<String>` (the learner's built token order) for
/// [SentenceConstructionExercise], or a `Map<String, String>`
/// (`leftTileId -> rightTileId`) for [MatchPairsExercise].
bool isAnswerCorrect(Exercise exercise, Object answer) {
  return switch (exercise) {
    MultipleChoiceExercise e => answer == e.correctOptionIndex,
    ListeningExercise e => answer == e.correctOptionIndex,
    SentenceConstructionExercise e =>
      answer is List<String> && listEquals(answer, e.correctSentence),
    MatchPairsExercise e =>
      answer is Map<String, String> && mapEquals(answer, e.correctPairs),
    // Same shape as multiple choice: one index, no partial credit.
    GapFillExercise e => answer == e.correctOptionIndex,
  };
}
