import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// The colours a section banner can take. Each category gets the next one, so
/// consecutive sections are always told apart at a glance.
///
/// All three backgrounds are the deep end of a Highland Pulse brand ramp, so
/// white title text clears contrast on every one of them; [accent] is the
/// light tone of the same hue, used for the count and the progress fill.
class _BannerPalette {
  const _BannerPalette({
    required this.background,
    required this.bevel,
    required this.accent,
  });

  final Color background;
  final Color bevel;
  final Color accent;
}

const List<_BannerPalette> _palettes = [
  _BannerPalette(
    background: AppColors.primaryContainer,
    bevel: AppColors.primaryBevel,
    accent: AppColors.primaryFixedDim,
  ),
  _BannerPalette(
    background: AppColors.secondary,
    bevel: AppColors.onSecondaryContainer,
    accent: AppColors.secondaryFixedDim,
  ),
  _BannerPalette(
    background: AppColors.tertiaryContainer,
    bevel: AppColors.tertiary,
    accent: AppColors.tertiaryFixedDim,
  ),
];

/// One category's banner, pinned beneath the dashboard header while that
/// category's own nodes scroll past (011-dashboard-ui-polish, story 002).
///
/// Carries exactly what the scrolling card carried before -- title, subtitle,
/// completed count and progress -- as a raised, coloured card. The line count
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

  /// The category's position in the course; picks its colour.
  final int colorIndex;

  static const double _progressHeight = 8;

  /// Depth of the card's bevel, drawn below it and so part of the space the
  /// pinned sliver has to reserve.
  static const double _bevel = 5;

  /// Breathing room above and below the card, inside the pinned area.
  static const double _gap = AppSpacing.spaceXs;

  /// The card's own padding.
  static const double _padV = AppSpacing.spaceSm;
  static const double _padH = AppSpacing.spaceMd;

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
    final count = _lineHeight(
      context,
      '$_countProbe Completed',
      AppTypography.labelSm,
    );
    final content =
        (titleBlock > count ? titleBlock : count) +
        AppSpacing.space2xs +
        _progressHeight;
    return (_gap * 2 + _padV * 2 + content + _bevel).ceilToDouble();
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

  _BannerPalette get _palette => _palettes[colorIndex % _palettes.length];

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_margin, _gap, _margin, _gap + _bevel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: _padV),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(AppRadii.base),
          boxShadow: [
            BoxShadow(color: palette.bevel, offset: const Offset(0, _bevel)),
          ],
        ),
        child: Column(
          // Hugs its content, so the banner's natural height is measurable
          // and can be checked against what [extentOf] reserved.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: AppColors.onPrimary,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                // Flexible so a very large text setting truncates the count
                // rather than pushing the row past the card's edge.
                Flexible(
                  child: Text(
                    '$completed/$total Completed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      color: palette.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space2xs),
            // The bar takes whatever vertical space is left rather than a
            // fixed height. [extentOf] measures the text and should leave it
            // exactly [_progressHeight], but a pinned sliver has to commit to
            // a height *before* laying out, and a prediction that is a
            // fraction short would otherwise overflow. Here it just draws a
            // slightly thinner bar, which nobody can see.
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.full),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : completed / total,
                  minHeight: _progressHeight,
                  backgroundColor: AppColors.onPrimary.withValues(alpha: 0.24),
                  valueColor: AlwaysStoppedAnimation(palette.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
