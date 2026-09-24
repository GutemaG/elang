import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../state/lesson_controller.dart';

/// A single "Choice & Match Tile" (`DESIGN.md` component 4) — used for
/// multiple-choice options, listening options, and (individually) sentence
/// word-bank tokens.
///
/// Renders the 4 documented states (default/selected/correct/incorrect,
/// with a shake animation on incorrect) driven by [feedback] + [selected].
class ChoiceTile extends StatefulWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.feedback,
    this.onTap,
  });

  final String label;
  final bool selected;

  /// Only meaningful when [selected] is true — an unselected tile never
  /// shows correct/incorrect styling even after the exercise is checked.
  final TileFeedback feedback;
  final VoidCallback? onTap;

  @override
  State<ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<ChoiceTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    if (widget.selected && widget.feedback == TileFeedback.incorrect) {
      _shakeController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ChoiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justBecameIncorrect =
        widget.selected &&
        widget.feedback == TileFeedback.incorrect &&
        !(oldWidget.selected && oldWidget.feedback == TileFeedback.incorrect);
    if (justBecameIncorrect) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  _TileStyle get _style {
    if (!widget.selected) {
      return const _TileStyle(
        background: AppColors.surfaceContainerLowest,
        border: AppColors.cardBorderDefault,
        textColor: AppColors.onSurface,
      );
    }
    return switch (widget.feedback) {
      TileFeedback.none => const _TileStyle(
        background: AppColors.answerSelected,
        border: AppColors.secondaryContainer,
        textColor: AppColors.onSurface,
      ),
      TileFeedback.correct => const _TileStyle(
        background: AppColors.answerCorrect,
        border: AppColors.primaryContainer,
        textColor: AppColors.primaryContainer,
      ),
      TileFeedback.incorrect => const _TileStyle(
        background: AppColors.answerIncorrect,
        border: AppColors.tertiaryBrand,
        textColor: AppColors.tertiaryBrand,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final bool interactive = widget.onTap != null;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final double shake =
            (widget.selected && widget.feedback == TileFeedback.incorrect)
            ? _shakeOffset(_shakeController.value)
            : 0;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: InkWell(
          onTap: widget.onTap,
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
                BoxShadow(
                  color: AppColors.cardBevelDefault,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppTypography.bodyLg.copyWith(
                      color: interactive
                          ? style.textColor
                          : style.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                if (widget.selected && widget.feedback == TileFeedback.correct)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primaryContainer,
                  ),
                if (widget.selected &&
                    widget.feedback == TileFeedback.incorrect)
                  const Icon(Icons.cancel, color: AppColors.tertiaryBrand),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _shakeOffset(double t) {
    // A couple of decaying oscillations rather than a raw sine, so the
    // tile visibly settles instead of stopping mid-swing.
    final decay = 1 - t;
    return 10 * decay * (t < 0.5 ? -1 : 1) * (t * 10 % 2 < 1 ? 1 : -1);
  }
}

class _TileStyle {
  const _TileStyle({
    required this.background,
    required this.border,
    required this.textColor,
  });

  final Color background;
  final Color border;
  final Color textColor;
}
