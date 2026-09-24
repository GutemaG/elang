import 'package:flutter/material.dart';

import '../../../shared/models/exercise.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(leftTiles, isLeft: true)),
        const SizedBox(width: AppSpacing.spaceSm),
        Expanded(child: _column(rightTiles, isLeft: false)),
      ],
    );
  }

  Widget _column(List<MatchPairsTile> tiles, {required bool isLeft}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tile in tiles)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: Builder(
              builder: (context) {
                final state = _stateFor(tile.id, isLeft: isLeft);
                return _MatchPairsTileChip(
                  label: tile.text,
                  state: state,
                  onTap: state == _MatchPairsTileState.correct
                      ? null
                      : () => onTileTap(tile.id, isLeft: isLeft),
                );
              },
            ),
          ),
      ],
    );
  }

  _MatchPairsTileState _stateFor(String tileId, {required bool isLeft}) {
    final matched = isLeft
        ? matchedPairs.containsKey(tileId)
        : matchedPairs.containsValue(tileId);
    if (matched) return _MatchPairsTileState.correct;
    final wrong = wrongPair;
    if (wrong != null && tileId == (isLeft ? wrong.$1 : wrong.$2)) {
      return _MatchPairsTileState.incorrect;
    }
    if (tileId == armedTileId && isLeft == armedIsLeft) {
      return _MatchPairsTileState.armed;
    }
    return _MatchPairsTileState.unselected;
  }
}

enum _MatchPairsTileState { unselected, armed, correct, incorrect }

class _MatchPairsTileChip extends StatelessWidget {
  const _MatchPairsTileChip({
    required this.label,
    required this.state,
    this.onTap,
  });

  final String label;
  final _MatchPairsTileState state;
  final VoidCallback? onTap;

  _ChipStyle get _style => switch (state) {
    _MatchPairsTileState.unselected => const _ChipStyle(
      background: AppColors.surfaceContainerLowest,
      border: AppColors.cardBorderDefault,
      textColor: AppColors.onSurface,
    ),
    _MatchPairsTileState.armed => const _ChipStyle(
      background: AppColors.answerSelected,
      border: AppColors.secondaryContainer,
      textColor: AppColors.onSurface,
    ),
    _MatchPairsTileState.correct => const _ChipStyle(
      background: AppColors.answerCorrect,
      border: AppColors.primaryContainer,
      textColor: AppColors.primaryContainer,
    ),
    _MatchPairsTileState.incorrect => const _ChipStyle(
      background: AppColors.answerIncorrect,
      border: AppColors.tertiaryBrand,
      textColor: AppColors.tertiaryBrand,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final interactive = onTap != null;
    return Semantics(
      button: true,
      selected: state != _MatchPairsTileState.unselected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceSm,
          ),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: style.border, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.cardBevelDefault, offset: const Offset(0, 3)),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: interactive ? style.textColor : style.textColor.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipStyle {
  const _ChipStyle({required this.background, required this.border, required this.textColor});

  final Color background;
  final Color border;
  final Color textColor;
}
