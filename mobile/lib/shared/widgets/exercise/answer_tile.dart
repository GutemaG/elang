import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme_context.dart';
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

  /// Square, a picture in place of the label: the two picture question
  /// types (019-image-choice-exercise-types). Built through `PictureTile`.
  picture,
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
///
/// The [AnswerTileShape.picture] shape draws [picture] instead of the
/// label, and the label becomes what a screen reader reads.
///
/// A [pronunciation] (the label in Latin letters, `ቡና` -> `bunna`) shows
/// as a smaller muted line under the label. Pills are all one height, so a
/// pill shows it only in a row whose pills are all made tall
/// ([tallPill]); a pill with a pronunciation is always tall.
class AnswerTile extends StatefulWidget {
  const AnswerTile({
    super.key,
    required this.label,
    this.state = AnswerTileState.idle,
    this.shape = AnswerTileShape.row,
    this.onTap,
    this.picture,
    this.pronunciation,
    this.tallPill = false,
  }) : assert(
         (shape == AnswerTileShape.picture) == (picture != null),
         'A picture tile needs a picture, and only a picture tile takes one',
       ),
       assert(
         shape != AnswerTileShape.picture || pronunciation == null,
         'A picture tile has no label to pronounce',
       );

  final String label;
  final AnswerTileState state;
  final AnswerTileShape shape;
  final VoidCallback? onTap;

  /// [label] in Latin letters; `null` shows no second line.
  final String? pronunciation;

  /// A pill as tall as one with a pronunciation, whether or not this one
  /// has one, so every pill in a sentence or a bank lines up.
  final bool tallPill;

  /// What a picture tile shows, fitted inside its square face. Any text it
  /// shows (a picture that failed to load) takes the tile's text colour.
  final Widget? picture;

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

  /// A pronunciation under a row's or a cell's label.
  static const TextStyle pronunciationStyle = AppTypography.phonetic;

  /// A pronunciation under a pill's label: smaller, so a tall pill stays
  /// close to a plain one.
  static const TextStyle pillPronunciationStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  /// How far a picture sits inside a picture tile's border.
  static const double pictureInset = AppSpacing.spaceXs;

  /// Text a picture tile shows in place of its picture.
  static const TextStyle pictureTextStyle = AppTypography.bodyMd;

  /// A pill's outer height (face and rim) at the current text scale. Every
  /// pill is this tall, Latin or Fidel, so a row of them lines up and the
  /// answer line can rule its lines to match. [withPronunciation] adds the
  /// pronunciation line a tall pill holds.
  static double pillHeightOf(
    BuildContext context, {
    bool withPronunciation = false,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final label =
        scaler.scale(labelStyle.fontSize!) *
        labelStyle.height! *
        AppTypography.ethiopicLineHeightFactor;
    final spoken = withPronunciation
        ? scaler.scale(pillPronunciationStyle.fontSize!) *
              pillPronunciationStyle.height!
        : 0.0;
    final line = (label + spoken).ceilToDouble();
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

  bool get _tall => widget.tallPill || widget.pronunciation != null;

  bool get _interactive =>
      widget.onTap != null &&
      widget.state != AnswerTileState.used &&
      widget.state != AnswerTileState.disabled;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final look = _TileLook.of(state, context.colors);
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
        shadows: (visible) =>
            context.shadows.tileRaised(look.rim, visible: visible),
        height: widget.shape == AnswerTileShape.pill
            ? AnswerTile.pillHeightOf(context, withPronunciation: _tall) -
                  AppShadows.tileShelfDepth
            : null,
        child: _content(
          context,
          faded ? look.text.withValues(alpha: 0.6) : look.text,
          look,
          faded: faded,
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

  /// [text] with the pronunciation line under it, or [text] alone. The line
  /// is muted until the tile is graded, then takes the grade's colour.
  Widget _withPronunciation(
    BuildContext context,
    Widget text,
    Color textColor, {
    required bool graded,
  }) {
    final spoken = widget.pronunciation;
    if (spoken == null) return text;
    final pill = widget.shape == AnswerTileShape.pill;
    final cell = widget.shape == AnswerTileShape.cell;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cell || pill
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        text,
        Text(
          spoken,
          textAlign: cell ? TextAlign.center : TextAlign.start,
          maxLines: pill ? 1 : null,
          softWrap: !pill,
          style:
              (pill
                      ? AnswerTile.pillPronunciationStyle
                      : AnswerTile.pronunciationStyle)
                  .copyWith(
                    color: graded ? textColor : context.colors.textMuted,
                  ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    Color textColor,
    _TileLook look, {
    required bool faded,
  }) {
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
    final label = _withPronunciation(
      context,
      text,
      textColor,
      graded: icon != null,
    );

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
                Expanded(child: label),
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
                Flexible(child: label),
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
            child: FittedBox(fit: BoxFit.scaleDown, child: label),
          ),
        );
      case AnswerTileShape.picture:
        // A square face with the picture inset, as LibreLingo's picture
        // cards are. A faded tile fades its picture as a row fades its
        // text. The grade sits in the top corner on the face colour, so it
        // reads over any picture.
        final picture = DefaultTextStyle(
          style: AnswerTile.pictureTextStyle.copyWith(color: look.text),
          textAlign: TextAlign.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: widget.picture,
          ),
        );
        return AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(AnswerTile.pictureInset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                faded ? Opacity(opacity: 0.6, child: picture) : picture,
                if (iconWidget != null)
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: look.face,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space2xs / 2),
                        child: iconWidget,
                      ),
                    ),
                  ),
              ],
            ),
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

  static _TileLook _idle(AppPalette colors) => _TileLook(
    face: colors.surfaceContainerLowest,
    border: colors.tileBorder,
    rim: colors.tileShelf,
    text: colors.onSurface,
  );

  static _TileLook of(AnswerTileState state, AppPalette colors) =>
      switch (state) {
        AnswerTileState.idle ||
        AnswerTileState.used ||
        AnswerTileState.disabled => _idle(colors),
        AnswerTileState.selected => _TileLook(
          face: colors.answerSelectedFace,
          border: colors.secondaryBrand,
          rim: colors.activeNodeShelf,
          text: colors.onSurface,
        ),
        AnswerTileState.correct => _TileLook(
          face: colors.answerCorrectFace,
          border: colors.primaryContainer,
          rim: colors.primaryShelf,
          text: colors.primaryAccent,
        ),
        AnswerTileState.incorrect => _TileLook(
          face: colors.answerIncorrectFace,
          border: colors.tertiaryBrand,
          rim: colors.tertiaryShelf,
          text: colors.tertiaryAccent,
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
