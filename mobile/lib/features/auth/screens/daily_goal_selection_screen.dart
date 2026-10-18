import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/app_language.dart';
import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';
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

/// The four presets, in the app language [l].
List<GoalOption> _goalOptions(AppLocalizations l) => [
  GoalOption(
    minutes: 5,
    title: l.goalCasual,
    description: l.goalCasualDescription,
    xpPerDay: 10,
    icon: Icons.eco,
  ),
  GoalOption(
    minutes: 10,
    title: l.goalRegular,
    description: l.goalRegularDescription,
    xpPerDay: 20,
    icon: Icons.local_cafe,
  ),
  GoalOption(
    minutes: 15,
    title: l.goalSerious,
    description: l.goalSeriousDescription,
    xpPerDay: 30,
    icon: Icons.coffee,
  ),
  GoalOption(
    minutes: 20,
    title: l.goalIntense,
    description: l.goalIntenseDescription,
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

  /// Back to the course choice: the screen below, or a fresh one when the
  /// app opened here.
  void _onBackPressed() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AuthRoutes.languageSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppPage(
      topBar: AppTopBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          tooltip: l.back,
          onPressed: _onBackPressed,
        ),
      ),
      bottomDock: [
        AppButton.primary(
          label: l.continueButton,
          onPressed: _onContinuePressed,
          trailing: const Icon(Icons.arrow_forward, size: 20),
        ),
        Text(
          l.changeGoalAnytime,
          textAlign: TextAlign.center,
          style: AppTypography.labelSm.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.chooseDailyGoal,
            style: AppTypography.displayLgMobile.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.space2xs),
          Text(
            l.dailyGoalQuestion,
            style: AppTypography.bodySm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          for (final option in _goalOptions(l))
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
                title: '${option.title} · ${l.minutesPerDay(option.minutes)}',
                subtitle:
                    '${option.description} · ${l.xpPerDay(option.xpPerDay)}',
                badgeLabel: option.minutes == _defaultGoalMinutes
                    ? l.recommendedBadge
                    : null,
                selected: _selectedMinutes == option.minutes,
                onTap: () => setState(() => _selectedMinutes = option.minutes),
              ),
            ),
          const SizedBox(height: AppSpacing.space2xs),
          InfoBanner(icon: Icons.lightbulb_outline, message: l.dailyGoalTip),
        ],
      ),
    );
  }
}
