import 'package:flutter/material.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/exercise/answer_slot_line.dart';
import '../../../shared/widgets/exercise/answer_tile.dart';
import '../state/lesson_controller.dart';
import 'answer_states.dart';

/// Sentence-construction's "tap-to-build from a word bank" interaction
/// (FR-2): the built sentence on its ruled lines above a word bank; tapping
/// a bank word places it and dims it, tapping a placed word puts it back.
/// Once checked, the placed words take the grade and nothing is tappable.
class WordBankBuilder extends StatelessWidget {
  const WordBankBuilder({
    super.key,
    required this.wordBank,
    required this.built,
    required this.feedback,
    required this.onToggle,
  });

  final List<String> wordBank;
  final List<String> built;
  final TileFeedback feedback;
  final ValueChanged<String> onToggle;

  bool get _locked => feedback != TileFeedback.none;

  @override
  Widget build(BuildContext context) {
    final placed = switch (feedback) {
      TileFeedback.none => AnswerTileState.idle,
      TileFeedback.correct => AnswerTileState.correct,
      TileFeedback.incorrect => AnswerTileState.incorrect,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnswerSlotLine.sentence(
          grade: gradeOf(feedback),
          children: [
            for (final token in built)
              AnswerTile(
                label: token,
                shape: AnswerTileShape.pill,
                state: placed,
                onTap: _locked ? null : () => onToggle(token),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        Wrap(
          spacing: AppSpacing.spaceXs,
          runSpacing: AppSpacing.spaceXs,
          children: [
            for (final token in wordBank)
              AnswerTile(
                label: token,
                shape: AnswerTileShape.pill,
                state: built.contains(token)
                    ? AnswerTileState.used
                    : AnswerTileState.idle,
                onTap: (_locked || built.contains(token))
                    ? null
                    : () => onToggle(token),
              ),
          ],
        ),
      ],
    );
  }
}
