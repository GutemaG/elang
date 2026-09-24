import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'answer_action_bar.dart';
import 'answer_tile.dart';

/// Where an answer is built (018-mobile-design-system, FR-7): the ruled
/// lines a sentence's word pills sit on, or the gap in a gap-fill sentence.
///
/// The line is a warm grey until the answer is graded, then green or
/// terracotta, in both forms.
class AnswerSlotLine extends StatelessWidget {
  /// Ruled lines for a sentence built from word pills ([children], usually
  /// [AnswerTile]s in the pill shape).
  ///
  /// It always holds at least [minLines] lines, so the page does not jump as
  /// words are added, and grows a line at a time when they wrap. Empty, it
  /// shows [hint] on the first line.
  const AnswerSlotLine.sentence({
    super.key,
    required List<Widget> this.children,
    this.grade,
    this.hint = 'Tap words below to build your answer',
    this.minLines = 2,
  }) : before = null,
       after = null,
       options = null,
       filled = null;

  /// A sentence with one word missing: [before] and [after] either side of
  /// a gap the chosen word ([filled]) drops into.
  ///
  /// The sentence is one piece of text, so it breaks across lines like
  /// prose in Fidel and Latin. The gap is as wide as the widest of
  /// [options], so the sentence never reflows when a word is chosen or
  /// changed: reflowing on every tap makes it hard to re-read, which is the
  /// one thing the question asks.
  const AnswerSlotLine.gap({
    super.key,
    required String this.before,
    required String this.after,
    required List<String> this.options,
    this.filled,
    this.grade,
  }) : children = null,
       hint = null,
       minLines = 1;

  final List<Widget>? children;
  final String? hint;
  final int minLines;

  /// Either side of the gap, already trimmed; either may be empty, meaning
  /// the gap sits at that end of the sentence.
  final String? before;
  final String? after;

  /// Every word that could fill the gap, used only to size it.
  final List<String>? options;

  /// The chosen word, or `null` while the gap is empty.
  final String? filled;

  /// `null` until the answer is graded.
  final AnswerGrade? grade;

  static const double lineWidth = 2;

  /// Space between two lines of pills; the rule runs through its middle.
  static const double runGap = AppSpacing.spaceXs;

  static const double _gapPadding = AppSpacing.spaceSm;

  Color get _lineColour => switch (grade) {
    null => AppColors.tileShelf,
    AnswerGrade.correct => AppColors.primaryContainer,
    AnswerGrade.incorrect => AppColors.tertiaryBrand,
  };

  @override
  Widget build(BuildContext context) {
    final words = children;
    return words == null ? _gapSentence(context) : _sentence(context, words);
  }

  Widget _sentence(BuildContext context, List<Widget> words) {
    final pill = AnswerTile.pillHeightOf(context);
    final pitch = pill + runGap;
    return CustomPaint(
      painter: _RulesPainter(
        firstLine: pill + runGap / 2,
        pitch: pitch,
        colour: _lineColour,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: double.infinity,
          minHeight: pitch * minLines,
        ),
        // Loose inside the held height, so the first line of pills (or the
        // hint) sits on the first rule rather than being stretched.
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: runGap),
            child: words.isEmpty
                ? SizedBox(
                    height: pill,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        hint!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: AppSpacing.spaceXs,
                    runSpacing: runGap,
                    children: words,
                  ),
          ),
        ),
      ),
    );
  }

  TextStyle _sentenceStyle() => AppTypography.forText(
    AppTypography.displayLgMobile.copyWith(color: AppColors.onSurface),
    '$before${options!.join()}$after',
  );

  /// The widest any option could render, so the gap is sized once and never
  /// resizes under the learner.
  double _gapWidth(BuildContext context, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final option in options!) {
      final painter = TextPainter(
        text: TextSpan(text: option, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest + _gapPadding * 2;
  }

  Widget _gapSentence(BuildContext context) {
    final style = _sentenceStyle();
    final word = filled;
    final wordColour = switch (grade) {
      null => AppColors.onSurface,
      AnswerGrade.correct => AppColors.primaryContainer,
      AnswerGrade.incorrect => AppColors.tertiaryBrand,
    };
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (before!.isNotEmpty) TextSpan(text: '$before '),
          WidgetSpan(
            // On the text's own baseline, so the filled word sits on the
            // same line as the words around it rather than floating.
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Semantics(
              // Without this the gap reads as nothing at all, or as its
              // word with no sign it is the answer slot.
              container: true,
              excludeSemantics: true,
              label: word == null ? 'blank' : 'blank, filled with $word',
              child: Container(
                width: _gapWidth(context, style),
                padding: const EdgeInsets.symmetric(horizontal: _gapPadding),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _lineColour, width: lineWidth),
                  ),
                ),
                // No fixed height: the gap takes the line's own height, so
                // larger text grows it instead of clipping it.
                child: Text(
                  word ?? '',
                  style: style.copyWith(color: wordColour),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (after!.isNotEmpty) TextSpan(text: ' $after'),
        ],
      ),
    );
  }
}

/// The ruled lines under each row of pills.
class _RulesPainter extends CustomPainter {
  const _RulesPainter({
    required this.firstLine,
    required this.pitch,
    required this.colour,
  });

  final double firstLine;
  final double pitch;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = AnswerSlotLine.lineWidth;
    for (var y = firstLine; y < size.height; y += pitch) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulesPainter old) =>
      old.firstLine != firstLine || old.pitch != pitch || old.colour != colour;
}
