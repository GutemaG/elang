import 'package:flutter/material.dart';

import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/selectable_option_card.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../auth_routes.dart';

/// A single daily-goal preset shown on [DailyGoalSelectionScreen].
class GoalOption {
  const GoalOption({
    required this.minutes,
    required this.title,
    required this.description,
    required this.xpPerDay,
    required this.icon,
  });

  final int minutes;
  final String title;
  final String description;
  final int xpPerDay;
  final IconData icon;
}

const List<GoalOption> _goalOptions = [
  GoalOption(
    minutes: 5,
    title: 'Casual',
    description: 'Gentle warm up',
    xpPerDay: 10,
    icon: Icons.eco,
  ),
  GoalOption(
    minutes: 10,
    title: 'Regular',
    description: 'Steady progress',
    xpPerDay: 20,
    icon: Icons.local_cafe,
  ),
  GoalOption(
    minutes: 15,
    title: 'Serious',
    description: 'Fast retention',
    xpPerDay: 30,
    icon: Icons.coffee,
  ),
  GoalOption(
    minutes: 20,
    title: 'Intense',
    description: 'Speed fluency',
    xpPerDay: 50,
    icon: Icons.local_fire_department,
  ),
];

/// Default daily-goal preset per the plan: "Regular / 10 min" is
/// pre-selected.
const int _defaultGoalMinutes = 10;

/// Daily-goal selection screen — maps to
/// `stich-screens/.../4._daily_goal_selection/`.
///
/// Single-select, radio-style behavior across the 4 presets.
class DailyGoalSelectionScreen extends StatefulWidget {
  const DailyGoalSelectionScreen({
    super.key,
    required this.onboardingRepository,
  });

  final OnboardingRepository onboardingRepository;

  @override
  State<DailyGoalSelectionScreen> createState() =>
      _DailyGoalSelectionScreenState();
}

class _DailyGoalSelectionScreenState extends State<DailyGoalSelectionScreen> {
  int _selectedMinutes = _defaultGoalMinutes;

  Future<void> _onContinuePressed() async {
    await widget.onboardingRepository.selectDailyGoal(_selectedMinutes);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AuthRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.spaceMd),
                    Text(
                      'Choose your daily goal',
                      style: AppTypography.displayLgMobile.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2xs),
                    Text(
                      'How much time do you want to dedicate to Habesha '
                      'languages each day?',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceLg),
                    for (final option in _goalOptions)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.spaceSm,
                        ),
                        child: SelectableOptionCard(
                          leading: _GoalIcon(
                            icon: option.icon,
                            selected: _selectedMinutes == option.minutes,
                          ),
                          title: '${option.title} · ${option.minutes} min/day',
                          subtitle:
                              '${option.description} · +${option.xpPerDay} XP/day',
                          badgeLabel: option.minutes == _defaultGoalMinutes
                              ? 'RECOMMENDED'
                              : null,
                          selected: _selectedMinutes == option.minutes,
                          onTap: () =>
                              setState(() => _selectedMinutes = option.minutes),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.spaceSm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadii.base),
                      ),
                      child: Text(
                        'Tip: Studying during your morning Buna ritual '
                        'boosts long-term recall.',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile,
                AppSpacing.spaceSm,
                AppSpacing.marginMobile,
                AppSpacing.spaceLg,
              ),
              child: Column(
                children: [
                  TactileButton(
                    label: 'Continue',
                    onPressed: _onContinuePressed,
                    trailing: const Icon(
                      Icons.arrow_forward,
                      color: AppColors.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceXs),
                  Text(
                    'You can change your goal anytime in Settings.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalIcon extends StatelessWidget {
  const _GoalIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryFixed.withValues(alpha: 0.5)
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(
        icon,
        size: 26,
        color: selected ? AppColors.primaryContainer : AppColors.secondary,
      ),
    );
  }
}
