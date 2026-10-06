import 'package:flutter/material.dart';

import '../../../shared/models/exercise.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/exercise/answer_slot_line.dart';
import '../../../shared/widgets/exercise/answer_tile.dart';
import '../state/lesson_controller.dart';
import 'answer_states.dart';

/// Sentence-construction's "tap-to-build from a word bank" interaction
/// (FR-2): the built sentence on its ruled lines above a word bank; tapping
/// a bank word places it and dims it, tapping a placed word puts it back.
/// Once checked, the placed words take the grade and nothing is tappable.
///
/// Words are placed by position, so a word the sentence needs twice is in
/// the bank twice and each copy dims on its own. Tiles show the bare word,
/// without the punctuation at its ends (`Nagaatti,` reads `Nagaatti`).
class WordBankBuilder extends StatelessWidget {
  const WordBankBuilder({
    super.key,
    required this.wordBank,
    required this.built,
    required this.feedback,
    required this.onPlace,
    required this.onRemoveAt,
    this.placedPositions = const [],
    this.pronunciations = const {},
  });

  final List<String> wordBank;

  /// Each word's pronunciation, by its text; a word with none is not in it.
  /// With any at all, every pill is made tall so they all line up.
  final Map<String, String> pronunciations;
  final List<String> built;
  final TileFeedback feedback;

  /// The bank position each word in [built] came from. When it does not
  /// match [built], the first unused copy of each word counts as placed.
  final List<int> placedPositions;

  /// The bank word at this position was tapped: add it to the end of
  /// [built].
  final void Function(int position, String word) onPlace;

  /// The placed word at this position in [built] was tapped: take it out.
  final ValueChanged<int> onRemoveAt;

  bool get _locked => feedback != TileFeedback.none;

  /// Which bank positions are in [built]: by [placedPositions], or else
  /// each placed word uses up the first copy of its text not used yet.
  List<bool> _usedInBank() {
    if (placedPositions.length == built.length && built.isNotEmpty) {
      return [
        for (var i = 0; i < wordBank.length; i++) placedPositions.contains(i),
      ];
    }
    final left = <String, int>{};
    for (final word in built) {
      left[word] = (left[word] ?? 0) + 1;
    }
    final used = <bool>[];
    for (final word in wordBank) {
      final count = left[word] ?? 0;
      used.add(count > 0);
      if (count > 0) left[word] = count - 1;
    }
    return used;
  }

  String? _spoken(String word) => switch (pronunciations[word]) {
    final spoken? => bareWord(spoken),
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final used = _usedInBank();
    final placed = switch (feedback) {
      TileFeedback.none => AnswerTileState.idle,
      TileFeedback.correct => AnswerTileState.correct,
      TileFeedback.incorrect => AnswerTileState.incorrect,
    };
    final tall = pronunciations.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnswerSlotLine.sentence(
          grade: gradeOf(feedback),
          tallPills: tall,
          children: [
            for (var i = 0; i < built.length; i++)
              AnswerTile(
                label: bareWord(built[i]),
                pronunciation: _spoken(built[i]),
                tallPill: tall,
                shape: AnswerTileShape.pill,
                state: placed,
                onTap: _locked ? null : () => onRemoveAt(i),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        Wrap(
          spacing: AppSpacing.spaceXs,
          runSpacing: AppSpacing.spaceXs,
          children: [
            for (var i = 0; i < wordBank.length; i++)
              AnswerTile(
                label: bareWord(wordBank[i]),
                pronunciation: _spoken(wordBank[i]),
                tallPill: tall,
                shape: AnswerTileShape.pill,
                state: used[i] ? AnswerTileState.used : AnswerTileState.idle,
                onTap: (_locked || used[i])
                    ? null
                    : () => onPlace(i, wordBank[i]),
              ),
          ],
        ),
      ],
    );
  }
}
