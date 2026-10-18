import 'package:flutter/foundation.dart' show listEquals, mapEquals;

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';

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
  const Exercise({required this.id, this.pronunciation});

  final String id;

  /// The question's word or sentence in Latin letters (`ቡና` -> `bunna`),
  /// shown under it for a learner who cannot read the script yet; `null`
  /// when the exercise has none. A question that is only heard has none.
  final String? pronunciation;
}

/// The pronunciation of the option at [index] in [pronunciations], a list
/// kept beside the options it describes; `null` when it has none, or the
/// list is shorter (an exercise with no pronunciations has an empty list).
String? pronunciationAt(List<String?> pronunciations, int index) =>
    index < pronunciations.length ? pronunciations[index] : null;

class MultipleChoiceExercise extends Exercise {
  const MultipleChoiceExercise({
    required super.id,
    required this.prompt,
    required this.promptTranslation,
    required this.options,
    required this.correctOptionIndex,
    this.optionPronunciations = const [],
    super.pronunciation,
  });

  /// The Amharic (or Afaan Oromo) prompt to translate/answer.
  final String prompt;

  /// English gloss shown beneath the prompt.
  final String promptTranslation;
  final List<String> options;
  final int correctOptionIndex;

  /// Each option's pronunciation, by position (see [pronunciationAt]).
  final List<String?> optionPronunciations;
}

class ListeningExercise extends Exercise {
  const ListeningExercise({
    required super.id,
    required this.audioUrl,
    required this.instruction,
    required this.options,
    required this.correctOptionIndex,
    this.optionPronunciations = const [],
  });

  /// Cloudflare R2 (or, in the fake, a placeholder) URL for the audio clip.
  final String audioUrl;
  final String instruction;
  final List<String> options;
  final int correctOptionIndex;

  /// Each option's pronunciation, by position (see [pronunciationAt]).
  final List<String?> optionPronunciations;
}

class SentenceConstructionExercise extends Exercise {
  const SentenceConstructionExercise({
    required super.id,
    required this.promptTranslation,
    required this.wordBank,
    required this.correctSentence,
    this.wordPronunciations = const {},
    super.pronunciation,
  });

  /// English sentence the learner builds the Amharic translation of.
  final String promptTranslation;

  /// Tappable tokens, including distractors, in fixed (already shuffled)
  /// display order.
  final List<String> wordBank;

  /// The correct token order — a subset (or all) of [wordBank].
  final List<String> correctSentence;

  /// Each word's pronunciation, by its text: the word bank is keyed by
  /// text, and the same word always sounds the same. A word with none is
  /// not in it.
  final Map<String, String> wordPronunciations;
}

/// Punctuation at either end of a word: `,` `.` `?` `!`, the Ethiopic `፣`
/// `።` `፤`, quotes and the like. Apostrophes stay, since in Afaan Oromo
/// `'` is a letter (hudhaa).
final _edgePunctuation = RegExp(
  r"^(?:(?!['’])[\p{P}\p{S}])+|(?:(?!['’])[\p{P}\p{S}])+$",
  unicode: true,
);

/// [word] without the punctuation at its ends (`Nagaatti,` -> `Nagaatti`,
/// `ይሁኑ፣` -> `ይሁኑ`), as a word-bank tile shows it; [word] itself when it
/// is nothing but punctuation.
String bareWord(String word) {
  final bare = word.trim().replaceAll(_edgePunctuation, '');
  return bare.isEmpty ? word.trim() : bare;
}

/// One tappable tile in a [MatchPairsExercise]'s left or right column.
///
/// Needs a stable [id] (unlike [MultipleChoiceExercise.options]' plain
/// `List<String>`) because the two columns are shuffled independently —
/// position alone can no longer identify which left tile pairs with which
/// right tile.
class MatchPairsTile {
  const MatchPairsTile({
    required this.id,
    required this.text,
    this.pronunciation,
  });

  final String id;
  final String text;

  /// [text] in Latin letters, if it has a pronunciation.
  final String? pronunciation;
}

class MatchPairsExercise extends Exercise {
  const MatchPairsExercise({
    required super.id,
    required this.prompt,
    required this.leftTiles,
    required this.rightTiles,
    required this.correctPairs,
    super.pronunciation,
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
    this.optionPronunciations = const [],
    super.pronunciation,
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

  /// Each option's pronunciation, by position (see [pronunciationAt]).
  final List<String?> optionPronunciations;
}

/// One picture a learner can choose in a picture question (019-image-
/// choice-exercise-types).
///
/// [altText] is never shown beside the picture: it is what a screen reader
/// reads, and what shows in the picture's place if it cannot be loaded.
/// It may be empty (bolt 055); [labelAt] then names the picture by place.
class PictureChoice {
  const PictureChoice({required this.imageUrl, required this.altText});

  /// An https address, a resolved local `/media/...` address, or in the
  /// fake an `assets/...` path.
  final String imageUrl;
  final String altText;

  /// [altText], or "Picture 2" for the second picture when it has none,
  /// in [l] (English by default).
  String labelAt(int index, [AppLocalizations? l]) => altText.trim().isEmpty
      ? (l ?? AppLocalizationsEn()).pictureN(index + 1)
      : altText;
}

/// Read a word, then tap its picture (019-image-choice-exercise-types).
///
/// Answered by index, like [MultipleChoiceExercise]: the API speaks in
/// choice ids, and `_toExercise` converts.
class ImageChoiceExercise extends Exercise {
  const ImageChoiceExercise({
    required super.id,
    required this.prompt,
    required this.choices,
    required this.correctOptionIndex,
    super.pronunciation,
  });

  /// The instruction and the word, e.g. "Choose the picture: 'ውሻ'".
  final String prompt;
  final List<PictureChoice> choices;
  final int correctOptionIndex;
}

/// Hear a word, then tap its picture (019-image-choice-exercise-types).
/// The word is never written: [instruction] only says what to do.
class AudioImageChoiceExercise extends Exercise {
  const AudioImageChoiceExercise({
    required super.id,
    required this.audioUrl,
    required this.instruction,
    required this.choices,
    required this.correctOptionIndex,
  });

  final String audioUrl;
  final String instruction;
  final List<PictureChoice> choices;
  final int correctOptionIndex;
}

/// One character tile in a [SpellTilesExercise] (016-spell-from-tiles-
/// exercise-type, bolt 033).
///
/// The same shape as [MatchPairsTile], deliberately not the same class:
/// here [text] is **expected to repeat** (`ፍራፍሬ` needs two `ፍ` tiles,
/// `Maaloo` two `a` and two `o`), so a tile is only ever identified by
/// [id]. Anything that looks a tile up by its text silently collapses such
/// a word -- the one bug this type exists not to have.
class SpellTile {
  const SpellTile({required this.id, required this.text, this.pronunciation});

  final String id;
  final String text;

  /// [text] in Latin letters (`ቡ` -> `bu`), if it has a pronunciation.
  final String? pronunciation;
}

/// Spell a word by tapping its characters in order (016-spell-from-tiles-
/// exercise-type, bolt 033).
///
/// Answered with the tapped tile ids, in order, and toggled through the
/// same `LessonController.toggleWordBankToken` a built sentence uses: ids
/// are unique within an exercise, so toggling one adds or removes exactly
/// that tile, twin or not.
class SpellTilesExercise extends Exercise {
  const SpellTilesExercise({
    required super.id,
    required this.prompt,
    required this.tiles,
    required this.correctSequence,
    super.pronunciation,
  });

  /// What to spell, in the learner's own language, e.g. "Spell 'Hello'".
  final String prompt;

  /// The word's characters, shuffled, plus distractors, in display order.
  final List<SpellTile> tiles;

  /// Tile ids in **a** correct order, as served -- not the only one. Twin
  /// tiles are interchangeable, so grading compares the spelled text (see
  /// [spelled]), not this list (bolt 032, decision D3).
  final List<String> correctSequence;

  /// The characters [tileIds] spell, in order; `null` if any id is not one
  /// of this exercise's tiles.
  List<String>? spelled(List<String> tileIds) {
    final textById = {for (final tile in tiles) tile.id: tile.text};
    final texts = <String>[];
    for (final id in tileIds) {
      final text = textById[id];
      if (text == null) return null;
      texts.add(text);
    }
    return texts;
  }
}

/// Grades a submitted answer against [exercise], client-side.
///
/// [answer] must be an `int` (the selected option index) for
/// [MultipleChoiceExercise]/[ListeningExercise]/[GapFillExercise] and both
/// picture types, a
/// `List<String>` (the learner's built token order) for
/// [SentenceConstructionExercise], a `List<String>` of tapped tile ids for
/// [SpellTilesExercise], or a `Map<String, String>`
/// (`leftTileId -> rightTileId`) for [MatchPairsExercise].
bool isAnswerCorrect(Exercise exercise, Object answer) {
  return switch (exercise) {
    MultipleChoiceExercise e => answer == e.correctOptionIndex,
    ListeningExercise e => answer == e.correctOptionIndex,
    // By the bare words: "Nagaatti," and "Nagaatti" are the same tile to
    // the learner, so either one builds the sentence.
    SentenceConstructionExercise e =>
      answer is List<String> &&
          listEquals(
            [for (final w in answer) bareWord(w).toLowerCase()],
            [for (final w in e.correctSentence) bareWord(w).toLowerCase()],
          ),
    MatchPairsExercise e =>
      answer is Map<String, String> && mapEquals(answer, e.correctPairs),
    // Same shape as multiple choice: one index, no partial credit.
    GapFillExercise e => answer == e.correctOptionIndex,
    ImageChoiceExercise e => answer == e.correctOptionIndex,
    AudioImageChoiceExercise e => answer == e.correctOptionIndex,
    // By the spelled text, not the ids: a twin tapped in the other order
    // spells the same word (bolt 032, decision D3).
    SpellTilesExercise e =>
      answer is List<String> &&
          switch (e.spelled(answer)) {
            final built? => listEquals(built, e.spelled(e.correctSequence)),
            null => false,
          },
  };
}
