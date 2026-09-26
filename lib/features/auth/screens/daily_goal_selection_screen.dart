import 'package:flutter/material.dart';

import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/selectable_option_card.dart';
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
    return AppPage(
      bottomDock: [
        AppButton.primary(
          label: 'Continue',
          onPressed: _onContinuePressed,
          trailing: const Icon(Icons.arrow_forward, size: 20),
        ),
        Text(
          'You can change your goal anytime in Settings.',
          textAlign: TextAlign.center,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your daily goal',
            style: AppTypography.displayLgMobile.copyWith(
              color: AppColors.onSurface,
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
              padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
              child: SelectableOptionCard(
                leading: IconBadge(
                  icon: option.icon,
                  tone: _selectedMinutes == option.minutes
                      ? AppTone.primary
                      : AppTone.secondary,
                  size: 48,
                  square: true,
                ),
                title: '${option.title} · ${option.minutes} min/day',
                subtitle: '${option.description} · +${option.xpPerDay} XP/day',
                badgeLabel: option.minutes == _defaultGoalMinutes
                    ? 'RECOMMENDED'
                    : null,
                selected: _selectedMinutes == option.minutes,
                onTap: () => setState(() => _selectedMinutes = option.minutes),
              ),
            ),
          const SizedBox(height: AppSpacing.space2xs),
          const InfoBanner(
            icon: Icons.lightbulb_outline,
            message:
                'Tip: Studying during your morning Buna ritual boosts '
                'long-term recall.',
          ),
        ],
      ),
    );
  }
}
