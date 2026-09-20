import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import 'pinned_header_sliver.dart';

/// One category's banner, pinned beneath the dashboard header while that
/// category's own nodes scroll past (011-dashboard-ui-polish, story 002).
///
/// Carries exactly what the scrolling card carried before -- title, subtitle,
/// completed count and progress -- in a compact bar. The line count is fixed
/// (one each for title and subtitle, ellipsised) so [extentOf] is exact at any
/// text scale; a variable-height banner could not be pinned, because a pinned
/// sliver must declare its extent before it lays out.
class CategoryBanner extends StatelessWidget {
  const CategoryBanner({
    super.key,
    required this.category,
    required this.completed,
    required this.total,
  });

  final SkillCategory category;
  final int completed;
  final int total;

  static const double _progressHeight = 8;
  static const double _borderWidth = 1;

  /// What the pinned sliver must reserve for this banner.
  static double extentOf(BuildContext context) {
    final titleBlock =
        scaledLineHeight(context, AppTypography.labelLg) +
        scaledLineHeight(context, AppTypography.bodySm);
    final count = scaledLineHeight(context, AppTypography.labelSm);
    return AppSpacing.spaceXs * 2 +
        (titleBlock > count ? titleBlock : count) +
        AppSpacing.space2xs +
        _progressHeight +
        _borderWidth;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorderDefault,
            width: _borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.spaceXs,
        ),
        child: Column(
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
                Text(
                  '$completed/$total Completed',
                  maxLines: 1,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space2xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.full),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : completed / total,
                minHeight: _progressHeight,
                backgroundColor: AppColors.surfaceContainer,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.primaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
