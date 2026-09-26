import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_shadows.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';

/// The tones a section banner takes in turn, so consecutive sections are
/// always told apart at a glance: the card's border, shelf and bar take the
/// tone, and the face stays white.
const List<AppTone> _tones = [
  AppTone.primary,
  AppTone.secondary,
  AppTone.tertiary,
];

/// One category's banner, pinned beneath the dashboard header while that
/// category's own nodes scroll past (011-dashboard-ui-polish, story 002).
///
/// Carries exactly what the scrolling card carried before -- title, subtitle,
/// completed count and progress -- as the dashboard mockup's milestone card
/// (018-mobile-design-system, bolt 047): a white [AppCard] with the Tibeb
/// stripe, a "3/5 Completed" [CountBadge] and an [AppProgressBar]. The line count
/// is fixed (one each for title and subtitle, ellipsised) so [extentOf] is
/// exact at any text scale; a variable-height banner could not be pinned,
/// because a pinned sliver must declare its extent before it lays out.
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

  /// Everything the card adds around its content: its shelf, its border, the
  /// Tibeb stripe and its compact padding.
  static const double _cardChrome =
      AppShadows.shelfDepth +
      2 * AppCard.borderWidth +
      TibebStripe.gradientHeight +
      2 * AppSpacing.spaceSm;

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
    final tone = _tones[colorIndex % _tones.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(_margin, _gap, _margin, _gap),
      child: AppCard(
        tone: tone,
        topStripe: true,
        padding: AppCardPadding.compact,
        child: Column(
          // Hugs its content, so the banner's natural height is measurable
          // and can be checked against what [extentOf] reserved.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
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
              child: AppProgressBar(
                value: total == 0 ? 0 : completed / total,
                tone: tone,
                gradient: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
