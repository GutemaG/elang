import 'package:flutter/material.dart';

import '../../../shared/models/exercise.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../state/lesson_controller.dart';

/// Match-pairs' "tap-to-link" interaction (FR-2/FR-3 of
/// 004-match-pairs-exercise-type): two independently-shuffled tile
/// columns; tapping a left tile arms it, tapping a right tile completes
/// the pair. Mirrors [WordBankBuilder]'s "build first, one atomic Check"
/// model rather than live per-pair feedback — see
/// `memory-bank/bolts/012-match-pairs-ui/implementation-plan.md`'s
/// Technical Approach for why.
class MatchPairsBuilder extends StatelessWidget {
  const MatchPairsBuilder({
    super.key,
    required this.leftTiles,
    required this.rightTiles,
    required this.pairs,
    required this.armedLeftTileId,
    required this.feedback,
    required this.onTileTap,
  });

  final List<MatchPairsTile> leftTiles;
  final List<MatchPairsTile> rightTiles;

  /// Current tentative (or, once [feedback] is non-`none`, final) answer:
  /// `leftTileId -> rightTileId`.
  final Map<String, String> pairs;
  final String? armedLeftTileId;
  final TileFeedback feedback;
  final void Function(String tileId, {required bool isLeft}) onTileTap;

  bool get _locked => feedback != TileFeedback.none;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tile in leftTiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                  child: _MatchPairsTileChip(
                    label: tile.text,
                    state: _stateFor(tile.id, isLeft: true),
                    onTap: _locked ? null : () => onTileTap(tile.id, isLeft: true),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tile in rightTiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                  child: _MatchPairsTileChip(
                    label: tile.text,
                    state: _stateFor(tile.id, isLeft: false),
                    onTap: _locked ? null : () => onTileTap(tile.id, isLeft: false),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  _MatchPairsTileState _stateFor(String tileId, {required bool isLeft}) {
    final isLinked = isLeft ? pairs.containsKey(tileId) : pairs.containsValue(tileId);
    if (_locked) {
      // Once checked, every linked tile shares the exercise's single
      // correct/incorrect verdict — matching every other exercise type's
      // "one atomic result", not a per-pair breakdown.
      if (!isLinked) return _MatchPairsTileState.unselected;
      return feedback == TileFeedback.correct
          ? _MatchPairsTileState.correct
          : _MatchPairsTileState.incorrect;
    }
    if (isLeft && tileId == armedLeftTileId) return _MatchPairsTileState.armed;
    if (isLinked) return _MatchPairsTileState.linked;
    return _MatchPairsTileState.unselected;
  }
}

enum _MatchPairsTileState { unselected, armed, linked, correct, incorrect }

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
      background: Color(0xFFFFF7ED),
      border: AppColors.secondaryContainer,
      textColor: AppColors.onSurface,
    ),
    _MatchPairsTileState.linked => const _ChipStyle(
      background: Color(0xFFFFF7ED),
      border: AppColors.secondaryContainer,
      textColor: AppColors.onSurface,
    ),
    _MatchPairsTileState.correct => const _ChipStyle(
      background: Color(0xFFE8F8F0),
      border: AppColors.primaryContainer,
      textColor: AppColors.primaryContainer,
    ),
    _MatchPairsTileState.incorrect => const _ChipStyle(
      background: Color(0xFFFDF0EE),
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
