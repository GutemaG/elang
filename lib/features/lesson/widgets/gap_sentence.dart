import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// A sentence with one word taken out, and a gap the chosen word drops into
/// (015-gap-fill-exercise-type, bolt 031).
///
/// Laid out as one `Text.rich` rather than a `Wrap` of per-word chips: the
/// sentence has to break across lines like prose, in Fidel and in Latin, and
/// a `Wrap` would re-implement line breaking badly.
///
/// The gap keeps a fixed width — the widest option it could ever hold — so
/// the sentence does not reflow when a word is chosen or changed. Reflowing
/// on every tap makes the sentence hard to re-read, which is the one thing
/// this exercise asks the learner to do.
class GapSentence extends StatelessWidget {
  const GapSentence({
    super.key,
    required this.before,
    required this.after,
    required this.options,
    this.filled,
  });

  /// The sentence either side of the gap, already trimmed. Either may be
  /// empty, meaning the gap sits at that end of the sentence.
  final String before;
  final String after;

  /// Every word that could land in the gap — used to size it, so that it
  /// never has to grow.
  final List<String> options;

  /// The chosen word, or null while the gap is still empty.
  final String? filled;

  static const double _gapPadding = AppSpacing.spaceSm;
  static const double _underlineHeight = 2;

  TextStyle get _sentenceStyle =>
      AppTypography.displayLgMobile.copyWith(color: AppColors.onSurface);

  /// The widest any option could render, so the gap is sized once and never
  /// resizes under the learner.
  double _gapWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final option in options) {
      final painter = TextPainter(
        text: TextSpan(text: option, style: _sentenceStyle),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }
    return widest + _gapPadding * 2;
  }

  @override
  Widget build(BuildContext context) {
    final style = _sentenceStyle;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (before.isNotEmpty) TextSpan(text: '$before '),
          WidgetSpan(
            // Aligned on the text's own baseline so the filled word sits on
            // the same line as the words around it rather than floating.
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _Gap(
              width: _gapWidth(context),
              filled: filled,
              style: style,
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: ' $after'),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.width, required this.filled, required this.style});

  final double width;
  final String? filled;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final word = filled;
    return Semantics(
      // Without this the gap reads as nothing at all, or as its filled word
      // with no indication it is the answer slot.
      container: true,
      excludeSemantics: true,
      label: word == null ? 'blank' : 'blank, filled with $word',
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: GapSentence._gapPadding,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.primaryContainer,
              width: GapSentence._underlineHeight,
            ),
          ),
        ),
        // No fixed height: the row takes the line's own height, so a larger
        // text scale grows the gap with the text instead of clipping it.
        child: Text(
          word ?? '',
          style: style,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
