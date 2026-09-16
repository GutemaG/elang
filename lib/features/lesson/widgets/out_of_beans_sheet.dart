import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';

/// Story 003's out-of-beans modal — maps to `out_of_beans_refill_modal/`.
///
/// Shown the instant local beans hit 0 mid-lesson. Offers an Amole refill
/// (disabled when the account can't afford it, per that story's edge
/// case) or a "Not now" dismiss; either path hands control back to the
/// caller via the two callbacks rather than navigating itself, so
/// `LessonScreen` stays in charge of what "resume" vs. "return to
/// dashboard" actually does.
class OutOfBeansSheet extends StatelessWidget {
  const OutOfBeansSheet({
    super.key,
    required this.status,
    required this.onRefill,
    required this.onDismiss,
  });

  final BeansStatus status;
  final VoidCallback onRefill;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final remaining = status.nextBeanAt?.difference(DateTime.now());
    final String countdown = remaining == null
        ? '--:--'
        : _formatDuration(remaining);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerLow,
                ),
                child: const Icon(
                  Icons.local_cafe_outlined,
                  size: 48,
                  color: AppColors.tertiaryBrand,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              'Out of Beans!',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLg.copyWith(
                color: AppColors.tertiaryBrand,
              ),
            ),
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              "Don't worry, mistakes help you brew fluency! Beans refill "
              'automatically over time so you can continue your lessons.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            Container(
              padding: const EdgeInsets.all(AppSpacing.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, color: AppColors.tertiaryBrand),
                  const SizedBox(width: AppSpacing.spaceXs),
                  Expanded(
                    child: Text(
                      'Next bean in',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    countdown,
                    semanticsLabel: 'Next bean in $countdown',
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.tertiaryBrand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            TactileButton(
              label: status.canAffordRefill
                  ? 'Refill with ${status.refillCostAmole} Amole'
                  : 'Not enough Amole',
              onPressed: status.canAffordRefill ? onRefill : null,
              backgroundColor: AppColors.secondaryContainer,
              bevelColor: AppColors.secondaryBevel,
              foregroundColor: AppColors.onSecondaryContainer,
              leading: const Icon(
                Icons.bolt,
                color: AppColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            TextButton(
              onPressed: onDismiss,
              child: Text(
                'Not now',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final minutes = clamped.inMinutes.remainder(60).toString().padLeft(
      2,
      '0',
    );
    final seconds = clamped.inSeconds.remainder(60).toString().padLeft(
      2,
      '0',
    );
    return '$minutes:$seconds';
  }
}
