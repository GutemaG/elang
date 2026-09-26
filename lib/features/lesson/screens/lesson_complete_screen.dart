import 'package:flutter/material.dart';

import '../../../shared/models/lesson_completion_result.dart';
import '../../../shared/models/skill_lesson_progress.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
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
///
/// With [skillProgress], it also says where this lesson left its skill:
/// how many lessons are still to go, or that the skill is now finished.
///
/// Built on the library as the mockups lay it out (018-mobile-design-system,
/// bolt 048): the celebration page, [StatCard]s, progress cards with
/// [AppProgressBar]s, and Continue docked at the bottom.
class LessonCompleteScreen extends StatelessWidget {
  const LessonCompleteScreen({
    super.key,
    required this.result,
    this.skillProgress,
  });

  final LessonCompletionResult result;
  final SkillLessonProgress? skillProgress;

  Future<void> _onContinue(BuildContext context) async {
    // A pending-sync result's crown/streak-freeze fields are always at
    // their safe defaults (never known offline) -- no level-up flourish to
    // show here regardless.
    if (!result.pendingSync && result.hasLevelUpFlourish) {
      await showLevelUpDialog(context, result);
      if (!context.mounted) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final progress = result.dailyXpTarget == 0
        ? 0.0
        : (result.dailyXpTotal / result.dailyXpTarget).clamp(0, 1).toDouble();

    return AppPage(
      background: AppPageBackground.celebration,
      bottomDock: [
        AppButton.primary(
          label: 'Continue',
          onPressed: () => _onContinue(context),
          trailing: const Icon(Icons.arrow_forward, size: 20),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.spaceMd),
          const Center(
            child: IconBadge(
              icon: Icons.local_cafe,
              tone: AppTone.secondary,
              size: 120,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            result.isReview ? 'Review Complete!' : 'Lesson Complete!',
            textAlign: TextAlign.center,
            style: AppTypography.displayLgMobile.copyWith(
              color: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          if (skillProgress != null && !result.isReview) ...[
            _SkillProgressCard(
              progress: skillProgress!,
              unlockedTitle: result.skillUnlockedTitle,
            ),
            const SizedBox(height: AppSpacing.spaceMd),
          ],
          if (result.isReview)
            _ReviewSummary(result: result)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.star,
                    tone: AppTone.secondary,
                    value: '+${result.xpEarned}',
                    label: 'XP EARNED',
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceXs),
                Expanded(
                  child: result.pendingSync
                      ? const StatCard(
                          icon: Icons.local_fire_department,
                          tone: AppTone.tertiary,
                          value: '--',
                          label: 'SYNCS WHEN ONLINE',
                        )
                      : StatCard(
                          icon: Icons.local_fire_department,
                          tone: AppTone.tertiary,
                          value: '${result.streakCount} Days',
                          label: 'STREAK',
                          ribbon: result.streakIncreasedToday
                              ? '+1 Today'
                              : null,
                        ),
                ),
                const SizedBox(width: AppSpacing.spaceXs),
                Expanded(
                  child: StatCard(
                    icon: Icons.verified,
                    tone: AppTone.primary,
                    value: '${result.accuracyPercent}%',
                    label: 'ACCURACY',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            AppCard(
              tone: AppTone.secondary,
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
                    AppProgressBar(
                      value: progress,
                      tone: AppTone.secondary,
                      gradient: true,
                      semanticLabel: 'Daily goal',
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
        ],
      ),
    );
  }
}

/// "Lesson 1 of 2 done. 1 more lesson to finish Numbers." -- or, on the
/// skill's last lesson, that the skill is finished and what it unlocked.
class _SkillProgressCard extends StatelessWidget {
  const _SkillProgressCard({required this.progress, this.unlockedTitle});

  final SkillLessonProgress progress;
  final String? unlockedTitle;

  @override
  Widget build(BuildContext context) {
    final left = progress.lessonsLeftAfter;
    final String headline;
    final String detail;
    if (progress.finishesSkill) {
      headline = 'You finished ${progress.skillTitle}!';
      detail = unlockedTitle != null
          ? '$unlockedTitle is now unlocked.'
          : 'All ${progress.lessonCount} lessons done.';
    } else {
      headline =
          'Lesson ${progress.lessonNumber} of ${progress.lessonCount} done';
      detail =
          '$left more ${left == 1 ? 'lesson' : 'lessons'} to finish '
          '${progress.skillTitle}.';
    }
    return AppCard(
      tone: AppTone.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: AppTypography.labelLg.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          AppProgressBar(
            value: progress.lessonCount == 0
                ? 0
                : progress.lessonNumber / progress.lessonCount,
            gradient: true,
            semanticLabel: 'Lessons done in ${progress.skillTitle}',
          ),
          const SizedBox(height: AppSpacing.space2xs),
          Text(
            detail,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.check_circle,
                tone: AppTone.primary,
                value: '${result.correctCount}/${result.totalCount}',
                label: 'CORRECT',
              ),
            ),
            const SizedBox(width: AppSpacing.spaceXs),
            Expanded(
              child: StatCard(
                icon: Icons.verified,
                tone: AppTone.primary,
                value: '${result.accuracyPercent}%',
                label: 'ACCURACY',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        const InfoBanner(
          icon: Icons.info_outline,
          tone: AppTone.neutral,
          message:
              "Reviews don't earn XP or use beans. They keep what you've "
              'already learned fresh.',
        ),
      ],
    );
  }
}
