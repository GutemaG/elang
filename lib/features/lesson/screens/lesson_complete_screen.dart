import 'package:flutter/material.dart';

import '../../../shared/models/lesson_completion_result.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../widgets/level_up_sheet.dart';

/// Story 004's lesson-complete summary — maps to
/// `lesson_complete_summary_1/2/`. Always shows the base summary (XP,
/// streak, accuracy, daily-goal progress); when [result] also carries a
/// crown level-up or streak-freeze unlock, an additional
/// `level_up_streak_freeze_modal`-style overlay is shown before
/// "Continue" pops back to the dashboard (which reloads on return, per
/// `SkillTreeDashboardScreen`).
///
/// A review (a skill already completed, replayed) earns nothing, so it
/// shows how it went instead of XP, streak and the daily goal.
class LessonCompleteScreen extends StatelessWidget {
  const LessonCompleteScreen({super.key, required this.result});

  final LessonCompletionResult result;

  Future<void> _onContinue(BuildContext context) async {
    // A pending-sync result's crown/streak-freeze fields are always at
    // their safe defaults (never known offline) -- no level-up flourish to
    // show here regardless.
    if (!result.pendingSync && result.hasLevelUpFlourish) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
        builder: (sheetContext) => LevelUpSheet(
          result: result,
          onContinue: () => Navigator.of(sheetContext).pop(),
        ),
      );
      if (!context.mounted) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final progress = result.dailyXpTarget == 0
        ? 0.0
        : (result.dailyXpTotal / result.dailyXpTarget).clamp(0, 1).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.spaceLg),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerLow,
                ),
                child: const Icon(
                  Icons.local_cafe,
                  size: 56,
                  color: AppColors.secondaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Text(
                result.isReview ? 'Review Complete!' : 'Lesson Complete!',
                style: AppTypography.displayLgMobile.copyWith(
                  color: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              if (result.isReview)
                _ReviewSummary(result: result)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star,
                        color: AppColors.secondaryContainer,
                        value: '+${result.xpEarned}',
                        label: 'XP EARNED',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceXs),
                    Expanded(
                      child: result.pendingSync
                          ? const _StatCard(
                              icon: Icons.local_fire_department,
                              color: AppColors.tertiaryBrand,
                              value: '--',
                              label: 'SYNCS WHEN ONLINE',
                            )
                          : _StatCard(
                              icon: Icons.local_fire_department,
                              color: AppColors.tertiaryBrand,
                              value: '${result.streakCount} Days',
                              label: 'STREAK',
                              badge: result.streakIncreasedToday
                                  ? '+1 Today'
                                  : null,
                            ),
                    ),
                    const SizedBox(width: AppSpacing.spaceXs),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.verified,
                        color: AppColors.primaryContainer,
                        value: '${result.accuracyPercent}%',
                        label: 'ACCURACY',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadii.base),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Goal Progress',
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.spaceXs),
                      if (result.pendingSync)
                        Text(
                          "You're offline -- this lesson's XP will sync and "
                          'count toward today\'s goal once you\'re back online.',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: AppColors.surfaceContainer,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space2xs),
                        Text(
                          '${result.dailyXpTotal} / ${result.dailyXpTarget} XP today',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const Spacer(),
              TactileButton(
                label: 'Continue',
                onPressed: () => _onContinue(context),
                trailing: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.result});

  final LessonCompletionResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                color: AppColors.primaryContainer,
                value: '${result.correctCount}/${result.totalCount}',
                label: 'CORRECT',
              ),
            ),
            const SizedBox(width: AppSpacing.spaceXs),
            Expanded(
              child: _StatCard(
                icon: Icons.verified,
                color: AppColors.primaryContainer,
                value: '${result.accuracyPercent}%',
                label: 'ACCURACY',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.base),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Text(
            "Reviews don't earn XP or use beans. They keep what you've "
            'already learned fresh.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceXs,
        vertical: AppSpacing.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.base),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(color: AppColors.cardBevelDefault, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                badge!,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onTertiary,
                ),
              ),
            ),
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
