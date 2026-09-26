import 'package:flutter/material.dart';

import '../../../shared/models/exercise.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/exercise/answer_slot_line.dart';
import '../../../shared/widgets/exercise/answer_tile.dart';
import '../state/lesson_controller.dart';
import 'answer_states.dart';

/// Spell-from-tiles (016-spell-from-tiles-exercise-type, bolt 033): the
/// word being spelled on a ruled line above the character tiles; tapping a
/// tile places its character and dims it, tapping a placed character puts
/// that tile back. Once checked, the placed characters take the grade and
/// nothing is tappable.
///
/// Laid out like `WordBankBuilder`, and deliberately not built on it:
/// that one is keyed by text, and here text repeats (`ፍራፍሬ` has two `ፍ`
/// tiles). Everything below is keyed by [SpellTile.id], so tapping one
/// twin never touches the other. See the intent's `units.md`, "Note on Not
/// Sharing the Word Bank".
class SpellTilesBuilder extends StatelessWidget {
  const SpellTilesBuilder({
    super.key,
    required this.tiles,
    required this.placed,
    required this.feedback,
    required this.onToggle,
  });

  final List<SpellTile> tiles;

  /// The placed tiles' ids, in tap order.
  final List<String> placed;
  final TileFeedback feedback;

  /// Called with the tapped tile's id.
  final ValueChanged<String> onToggle;

  bool get _locked => feedback != TileFeedback.none;

  @override
  Widget build(BuildContext context) {
    final textById = {for (final tile in tiles) tile.id: tile.text};
    final placedState = switch (feedback) {
      TileFeedback.none => AnswerTileState.idle,
      TileFeedback.correct => AnswerTileState.correct,
      TileFeedback.incorrect => AnswerTileState.incorrect,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnswerSlotLine.sentence(
          grade: gradeOf(feedback),
          hint: 'Tap the characters below to spell it',
          minLines: 1,
          children: [
            for (final id in placed)
              AnswerTile(
                key: ValueKey('placed-$id'),
                label: textById[id] ?? '',
                shape: AnswerTileShape.pill,
                state: placedState,
                onTap: _locked ? null : () => onToggle(id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        // Pills hug their character, so a wide Fidel syllable is never
        // clipped to a Latin letter's width, and the wrap adds rows rather
        // than overflowing.
        Wrap(
          spacing: AppSpacing.spaceXs,
          runSpacing: AppSpacing.spaceXs,
          children: [
            for (final tile in tiles)
              AnswerTile(
                key: ValueKey('bank-${tile.id}'),
                label: tile.text,
                shape: AnswerTileShape.pill,
                state: placed.contains(tile.id)
                    ? AnswerTileState.used
                    : AnswerTileState.idle,
                onTap: (_locked || placed.contains(tile.id))
                    ? null
                    : () => onToggle(tile.id),
              ),
          ],
        ),
      ],
    );
  }
}
