import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';

/// Asked when the learner backs out of a lesson part-way through: nothing
/// is saved until the last exercise, so leaving loses this lesson's
/// progress. Pops `true` for Leave; Keep learning, a tap on the scrim or a
/// swipe down all stay in the lesson.
class ExitLessonSheet extends StatelessWidget {
  const ExitLessonSheet({super.key, this.isPractice = false});

  final bool isPractice;

  @override
  Widget build(BuildContext context) {
    final what = isPractice ? 'practice' : 'lesson';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerLow,
                ),
                child: const Icon(
                  Icons.logout,
                  size: 40,
                  color: AppColors.tertiaryBrand,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              'Leave this $what?',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLg.copyWith(
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              "Your progress in this $what won't be saved.",
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            TactileButton(
              label: 'Keep learning',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Leave',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.tertiaryBrand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
