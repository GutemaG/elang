import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../tactile_pressable.dart';

/// Where an answer stands (DESIGN.md component 4).
enum AnswerTileState {
  /// Not chosen.
  idle,

  /// Chosen, not graded yet; also the first tile of a match pair.
  selected,

  /// Graded right.
  correct,

  /// Graded wrong: it shakes once.
  incorrect,

  /// A word-bank word already placed in the sentence: dimmed.
  used,

  /// Cannot be chosen right now: faded text.
  disabled,
}

/// How an answer tile is laid out, by question type.
enum AnswerTileShape {
  /// Full width, label on the left: multiple choice, listening, gap fill.
  row,

  /// Hugs its label, fully rounded, one fixed height so pills line up on an
  /// [AnswerSlotLine]: the word bank and spell tiles.
  pill,

  /// Fills its column, label centred: match pairs.
  cell,
}

/// The one answer tile (018-mobile-design-system, FR-7): every choice, word
/// and match card in a lesson, so selected, right and wrong look and move
/// the same in every question type.
///
/// It presses like every other tactile element. Correct and incorrect show
/// a check or a cross (a pill by colour alone), and incorrect shakes once
/// (not with reduced motion).
/// With [onTap] `null`, or when [state] is used or disabled, it cannot be
/// tapped and does not press.
class AnswerTile extends StatefulWidget {
  const AnswerTile({
    super.key,
    required this.label,
    this.state = AnswerTileState.idle,
    this.shape = AnswerTileShape.row,
    this.onTap,
  });

  final String label;
  final AnswerTileState state;
  final AnswerTileShape shape;
  final VoidCallback? onTap;

  static const double borderWidth = 2;

  /// The smallest face of a row or cell; with the rim, well over the 48 px
  /// tap target.
  static const double minFaceHeight = 56;

  /// The smallest pill face: with its rim, exactly the 48 px tap target.
  static const double minPillFaceHeight = 45;

  static const double iconSize = 22;

  /// How far an incorrect tile swings either side at first.
  static const double shakeDistance = 8;

  static const TextStyle labelStyle = AppTypography.bodyLg;

  /// A pill's outer height (face and rim) at the current text scale. Every
  /// pill is this tall, Latin or Fidel, so a row of them lines up and the
  /// answer line can rule its lines to match.
  static double pillHeightOf(BuildContext context) {
    final line =
        (MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) *
                labelStyle.height! *
                AppTypography.ethiopicLineHeightFactor)
            .ceilToDouble();
    final face = math.max(
      minPillFaceHeight,
      line + AppSpacing.spaceXs * 2 + borderWidth * 2,
    );
    return face + AppShadows.tileShelfDepth;
  }

  @override
  State<AnswerTile> createState() => _AnswerTileState();
}

class _AnswerTileState extends State<AnswerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppMotion.shake,
  );

  @override
  void initState() {
    super.initState();
    // A tile first built already wrong (a rebuilt list) still shakes once.
    if (widget.state == AnswerTileState.incorrect) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startShake());
    }
  }

  @override
  void didUpdateWidget(covariant AnswerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == AnswerTileState.incorrect &&
        oldWidget.state != AnswerTileState.incorrect) {
      _startShake();
    } else if (widget.state != AnswerTileState.incorrect) {
      _shake.reset();
    }
  }

  void _startShake() {
    if (!mounted || AppMotion.reduced(context)) return;
    _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _interactive =>
      widget.onTap != null &&
      widget.state != AnswerTileState.used &&
      widget.state != AnswerTileState.disabled;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final look = _TileLook.of(state);
    // Graded tiles keep their full colour so the result reads clearly;
    // only a choice that simply cannot be tapped fades.
    final faded =
        state == AnswerTileState.disabled ||
        (!_interactive &&
            (state == AnswerTileState.idle ||
                state == AnswerTileState.selected));
    final isSelected =
        state == AnswerTileState.selected ||
        state == AnswerTileState.correct ||
        state == AnswerTileState.incorrect;

    Widget tile = TweenAnimationBuilder<_TileLook>(
      tween: _TileLookTween(end: look),
      duration: AppMotion.state,
      curve: AppMotion.stateCurve,
      builder: (context, look, _) => TactilePressable(
        onPressed: _interactive ? widget.onTap : null,
        faceColor: look.face,
        borderColor: look.border,
        borderWidth: AnswerTile.borderWidth,
        borderRadius: BorderRadius.circular(
          widget.shape == AnswerTileShape.pill ? AppRadii.full : AppRadii.tile,
        ),
        shelfDepth: AppShadows.tileShelfDepth,
        shadows: (visible) => AppShadows.tileRaised(look.rim, visible: visible),
        height: widget.shape == AnswerTileShape.pill
            ? AnswerTile.pillHeightOf(context) - AppShadows.tileShelfDepth
            : null,
        child: _content(
          context,
          faded ? look.text.withValues(alpha: 0.6) : look.text,
          look,
        ),
      ),
    );

    if (widget.shape != AnswerTileShape.pill) {
      tile = SizedBox(width: double.infinity, child: tile);
    }
    if (state == AnswerTileState.used) {
      tile = Opacity(opacity: 0.35, child: tile);
    }

    return Semantics(
      container: true,
      button: true,
      enabled: _interactive,
      selected: isSelected,
      label: widget.label,
      excludeSemantics: true,
      onTap: _interactive ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final offset = _shake.isAnimating
              ? math.sin(t * math.pi * 6) * AnswerTile.shakeDistance * (1 - t)
              : 0.0;
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: tile,
      ),
    );
  }

  Widget _content(BuildContext context, Color textColor, _TileLook look) {
    final icon = switch (widget.state) {
      AnswerTileState.correct => Icons.check_circle,
      AnswerTileState.incorrect => Icons.cancel,
      _ => null,
    };
    final text = Text(
      widget.label,
      textAlign: widget.shape == AnswerTileShape.cell
          ? TextAlign.center
          : TextAlign.start,
      maxLines: widget.shape == AnswerTileShape.pill ? 1 : null,
      softWrap: widget.shape != AnswerTileShape.pill,
      style: AppTypography.forText(
        AnswerTile.labelStyle.copyWith(color: textColor),
        widget.label,
      ),
    );
    final iconWidget = icon == null
        ? null
        : Icon(icon, size: AnswerTile.iconSize, color: look.border);

    switch (widget.shape) {
      case AnswerTileShape.row:
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AnswerTile.minFaceHeight - AnswerTile.borderWidth * 2,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceMd,
              vertical: AppSpacing.spaceSm,
            ),
            child: Row(
              children: [
                Expanded(child: text),
                if (iconWidget != null) ...[
                  const SizedBox(width: AppSpacing.spaceXs),
                  iconWidget,
                ],
              ],
            ),
          ),
        );
      case AnswerTileShape.cell:
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AnswerTile.minFaceHeight - AnswerTile.borderWidth * 2,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceSm,
              vertical: AppSpacing.spaceSm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: text),
                if (iconWidget != null) ...[
                  const SizedBox(width: AppSpacing.space2xs),
                  iconWidget,
                ],
              ],
            ),
          ),
        );
      case AnswerTileShape.pill:
        // One line at a fixed height: a word too long for the row shrinks
        // to fit rather than wrapping out of its pill. A pill shows its
        // grade by colour alone: an icon would widen every word in a
        // checked sentence and reflow it under the learner.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceMd),
          child: Center(
            widthFactor: 1,
            child: FittedBox(fit: BoxFit.scaleDown, child: text),
          ),
        );
    }
  }
}

/// A tile's colours in one state: DESIGN.md component 4. Graded tiles rest
/// on their border colour's bevel, as the selected tile rests on gold's.
@immutable
class _TileLook {
  const _TileLook({
    required this.face,
    required this.border,
    required this.rim,
    required this.text,
  });

  final Color face;
  final Color border;
  final Color rim;
  final Color text;

  static const _idle = _TileLook(
    face: AppColors.surfaceContainerLowest,
    border: AppColors.tileBorder,
    rim: AppColors.tileShelf,
    text: AppColors.onSurface,
  );

  static _TileLook of(AnswerTileState state) => switch (state) {
    AnswerTileState.idle ||
    AnswerTileState.used ||
    AnswerTileState.disabled => _idle,
    AnswerTileState.selected => const _TileLook(
      face: AppColors.answerSelected,
      border: AppColors.secondaryBrand,
      rim: AppColors.activeNodeShelf,
      text: AppColors.onSurface,
    ),
    AnswerTileState.correct => const _TileLook(
      face: AppColors.answerCorrect,
      border: AppColors.primaryContainer,
      rim: AppColors.primaryBevel,
      text: AppColors.primaryContainer,
    ),
    AnswerTileState.incorrect => const _TileLook(
      face: AppColors.answerIncorrect,
      border: AppColors.tertiaryBrand,
      rim: AppColors.tertiaryBevel,
      text: AppColors.tertiaryBrand,
    ),
  };

  static _TileLook lerp(_TileLook a, _TileLook b, double t) => _TileLook(
    face: Color.lerp(a.face, b.face, t)!,
    border: Color.lerp(a.border, b.border, t)!,
    rim: Color.lerp(a.rim, b.rim, t)!,
    text: Color.lerp(a.text, b.text, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is _TileLook &&
      other.face == face &&
      other.border == border &&
      other.rim == rim &&
      other.text == text;

  @override
  int get hashCode => Object.hash(face, border, rim, text);
}

/// Eases a tile from one state's colours to the next over
/// [AppMotion.state].
class _TileLookTween extends Tween<_TileLook> {
  _TileLookTween({required super.end});

  @override
  _TileLook lerp(double t) => _TileLook.lerp(begin ?? end!, end!, t);
}
