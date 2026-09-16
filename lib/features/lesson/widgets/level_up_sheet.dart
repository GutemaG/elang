import 'package:flutter/material.dart';

import '../../../shared/models/lesson_completion_result.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';

/// Story 004's crown-level-up / streak-freeze modal — maps to
/// `level_up_streak_freeze_modal/`. Only shown when
/// [LessonCompletionResult.hasLevelUpFlourish] is true; the base
/// lesson-complete summary always renders on its own regardless.
class LevelUpSheet extends StatelessWidget {
  const LevelUpSheet({super.key, required this.result, required this.onContinue});

  final LessonCompletionResult result;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bool freeze = result.streakFreezeUnlocked;
    final String title = freeze ? 'Streak Freeze Unlocked!' : 'Crown Level Up!';

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
                child: Icon(
                  freeze ? Icons.ac_unit : Icons.workspace_premium,
                  size: 44,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineLg.copyWith(
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              'You reached crown level ${result.crownLevel} '
              '${result.skillUnlockedTitle != null ? 'and unlocked ${result.skillUnlockedTitle}' : ''}'
              '${freeze ? '. A free streak freeze protects one missed day.' : '.'}',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            TactileButton(label: 'Continue', onPressed: onContinue),
          ],
        ),
      ),
    );
  }
}
