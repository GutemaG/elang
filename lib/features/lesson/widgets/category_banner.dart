import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/theme/app_shadows.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status.dart';

/// The tones the section header takes in turn, so the learner can see the
/// header change as they scroll from one section into the next.
const List<AppTone> _tones = [
  AppTone.primary,
  AppTone.secondary,
  AppTone.tertiary,
];

/// The dashboard's one section header, pinned beneath the stats bar and
/// showing whichever section the learner is scrolled to
/// (020-dashboard-section-header, after Duolingo's unit card). It replaced
/// intent 011's banner per section, which put several coloured blocks on
/// one screen.
///
/// A solid [AppCard] in the section's tone, carrying the title, subtitle,
/// a "3/5 Completed" [CountBadge] and an [AppProgressBar]. The line count
/// is fixed (one each for title and subtitle, ellipsised) so [extentOf] is
/// exact at any text scale; the header is a pinned sliver, which must
/// declare its extent before it lays out.
class CategoryBanner extends StatelessWidget {
  const CategoryBanner({
    super.key,
    required this.category,
    required this.completed,
    required this.total,
    this.colorIndex = 0,
  });

  final SkillCategory category;
  final int completed;
  final int total;

  /// The category's position in the course; picks its tone.
  final int colorIndex;

  /// Breathing room above and below the card, inside the pinned area.
  static const double _gap = AppSpacing.spaceXs;

  /// Everything the card adds around its content: its shelf, its border and
  /// its compact padding.
  static const double _cardChrome =
      AppShadows.shelfDepth + 2 * AppCard.borderWidth + 2 * AppSpacing.spaceSm;

  /// Kept narrower than the screen margin so the banner reads as a wide card
  /// rather than a full-bleed bar, while still being wider than the content
  /// column it sits above.
  static const double _margin = AppSpacing.spaceSm;

  /// What the pinned sliver must reserve for this banner.
  ///
  /// The height is **measured, not derived**. Arithmetic over the type scale
  /// looks exact and is not: the engine rounds each line box up, the font in
  /// use may not be the one the style names, and Fidel can fall back to a face
  /// with its own metrics. Reserving a computed value left the banner a pixel
  /// short on device while every test passed, because the test font's metrics
  /// happened to agree with the arithmetic. A `TextPainter` lays the real
  /// strings out in the real font, so what is reserved is what will render.
  static double extentOf(BuildContext context, SkillCategory category) {
    final titleBlock =
        _lineHeight(context, category.title, AppTypography.labelLg) +
        _lineHeight(context, category.subtitle, AppTypography.bodySm);
    final count =
        _lineHeight(context, '$_countProbe Completed', AppTypography.labelSm) +
        CountBadge.verticalChrome();
    final content =
        (titleBlock > count ? titleBlock : count) +
        AppSpacing.space2xs +
        AppProgressBar.regularHeight;
    return (_gap * 2 + _cardChrome + content).ceilToDouble();
  }

  /// The one height that fits every section of [categories], so the header
  /// keeps its size as it changes from section to section.
  static double extentOfAll(
    BuildContext context,
    List<SkillCategory> categories,
  ) {
    var extent = 0.0;
    for (final category in categories) {
      final e = extentOf(context, category);
      if (e > extent) extent = e;
    }
    return extent;
  }

  /// The tone of the section at [index].
  static AppTone toneAt(int index) => _tones[index % _tones.length];

  /// Digits are the only part of the count that can vary in height, and every
  /// digit shares a line box, so any two will do.
  static const String _countProbe = '0/0';

  /// A mixed-script probe. An empty or all-Latin string can lay out shorter
  /// than the face Fidel falls back to, and an empty one shorter again, so the
  /// reserved line is never smaller than this.
  static const String _lineProbe = 'Agሀ';

  static double _lineHeight(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final probe = _measure(context, _lineProbe, style);
    final actual = _measure(context, text, style);
    return actual > probe ? actual : probe;
  }

  static double _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
      ellipsis: '…',
    )..layout();
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    final tone = toneAt(colorIndex);
    final value = total == 0 ? 0.0 : completed / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_margin, _gap, _margin, _gap),
      child: Semantics(
        header: true,
        container: true,
        excludeSemantics: true,
        label:
            '${category.title}, ${category.subtitle}, '
            '$completed of $total completed',
        child: AppCard(
          tone: tone,
          filled: true,
          padding: AppCardPadding.compact,
          child: Column(
            // Hugs its content, so the banner's natural height is measurable
            // and can be checked against what [extentOf] reserved.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // The title gets two thirds of the row, so a name like
                  // "Foundations & Greetings" is not cut at half width.
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLg.copyWith(
                            color: tone.onFill,
                          ),
                        ),
                        Text(
                          category.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: tone.onFill,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  // Scales down rather than pushing the row past the card's
                  // edge at a very large text setting.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: CountBadge(label: '$completed/$total Completed'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space2xs),
              // The bar takes whatever vertical space is left. [extentOf]
              // measures the text and should leave it its full height, but a
              // pinned sliver has to commit to a height *before* laying out,
              // and a prediction that is a fraction short would otherwise
              // overflow. Here it just draws a slightly thinner bar, which
              // nobody can see.
              Flexible(
                child: AppProgressBar(value: value, tone: tone, onFilled: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
