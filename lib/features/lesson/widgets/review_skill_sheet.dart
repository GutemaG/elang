import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';

/// Shown when a completed skill is tapped: a completed skill is only ever
/// reviewed, so the learner says so here instead of dropping straight into
/// the lesson as if it were new. Pops `true` for Review, `null` otherwise.
class ReviewSkillSheet extends StatelessWidget {
  const ReviewSkillSheet({super.key, required this.skillTitle});

  final String skillTitle;

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.secondaryFixed,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 44,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              skillTitle,
              textAlign: TextAlign.center,
              style: AppTypography.headlineLg.copyWith(
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              "You've completed this skill. Review it any time -- reviews "
              "don't earn XP or use beans.",
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            TactileButton(
              label: 'Review',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
