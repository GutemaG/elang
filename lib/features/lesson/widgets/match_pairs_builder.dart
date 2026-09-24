import 'package:flutter/material.dart';

import '../../../shared/models/exercise.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/exercise/answer_tile.dart';

/// Match-pairs' "tap-to-link" interaction (FR-2/FR-3 of
/// 004-match-pairs-exercise-type): two independently-shuffled tile
/// columns; tap a tile in either column, then its partner in the other.
///
/// Each pair is graded as soon as it is made: a right pair turns green and
/// stays locked, a wrong one flashes red and both tiles can be tapped again.
/// That replaced the original "link everything, then one atomic Check"
/// model, which made the learner find out about every mistake at once at
/// the end. All state lives in `LessonController`; this only draws it.
class MatchPairsBuilder extends StatelessWidget {
  const MatchPairsBuilder({
    super.key,
    required this.leftTiles,
    required this.rightTiles,
    required this.matchedPairs,
    required this.armedTileId,
    required this.armedIsLeft,
    required this.wrongPair,
    required this.onTileTap,
  });

  final List<MatchPairsTile> leftTiles;
  final List<MatchPairsTile> rightTiles;

  /// Pairs already graded right: `leftTileId -> rightTileId`.
  final Map<String, String> matchedPairs;

  /// The tile tapped first, waiting for its partner; [armedIsLeft] says
  /// which column it is in.
  final String? armedTileId;
  final bool armedIsLeft;

  /// The pair just graded wrong, as `(left, right)`, while it flashes.
  final (String, String)? wrongPair;
  final void Function(String tileId, {required bool isLeft}) onTileTap;

  @override
  Widget build(BuildContext context) {
    // Laid out a row at a time, not as two columns, so the two tiles side
    // by side are always the same height: a Fidel label is taller than a
    // Latin one, and two free columns would drift out of line.
    final rows = leftTiles.length > rightTiles.length
        ? leftTiles.length
        : rightTiles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _cell(leftTiles, i, isLeft: true)),
                  const SizedBox(width: AppSpacing.spaceSm),
                  Expanded(child: _cell(rightTiles, i, isLeft: false)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(List<MatchPairsTile> tiles, int index, {required bool isLeft}) {
    if (index >= tiles.length) return const SizedBox.shrink();
    final tile = tiles[index];
    final state = _stateFor(tile.id, isLeft: isLeft);
    return AnswerTile(
      label: tile.text,
      shape: AnswerTileShape.cell,
      state: state,
      onTap: state == AnswerTileState.correct
          ? null
          : () => onTileTap(tile.id, isLeft: isLeft),
    );
  }

  /// Armed is the kit's selected; a locked pair is correct; the pair just
  /// graded wrong is incorrect, which shakes.
  AnswerTileState _stateFor(String tileId, {required bool isLeft}) {
    final matched = isLeft
        ? matchedPairs.containsKey(tileId)
        : matchedPairs.containsValue(tileId);
    if (matched) return AnswerTileState.correct;
    final wrong = wrongPair;
    if (wrong != null && tileId == (isLeft ? wrong.$1 : wrong.$2)) {
      return AnswerTileState.incorrect;
    }
    if (tileId == armedTileId && isLeft == armedIsLeft) {
      return AnswerTileState.selected;
    }
    return AnswerTileState.idle;
  }
}
