import 'package:flutter/material.dart';

import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/selectable_option_card.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../auth_routes.dart';

/// A single course option shown on [LanguageSelectionScreen].
///
/// Modeled as data (not a hardcoded widget) precisely so a second live
/// course is a data change later, not a layout rewrite — see this bolt's
/// acceptance criteria.
class CourseOption {
  const CourseOption({
    required this.code,
    required this.displayName,
    required this.nativeName,
    required this.subtitle,
    required this.badgeLabel,
    required this.isAvailable,
  });

  final String code;
  final String displayName;
  final String nativeName;
  final String subtitle;
  final String badgeLabel;
  final bool isAvailable;
}

const List<CourseOption> _courseOptions = [
  CourseOption(
    code: 'am',
    displayName: 'Amharic',
    nativeName: 'አማርኛ',
    subtitle: 'Core Fidel alphabet: ሀ ሁ ሂ ሃ ሄ ህ ሆ · Over 120k learners',
    badgeLabel: 'OFFICIAL LAUNCH',
    isAvailable: true,
  ),
  CourseOption(
    code: 'om',
    displayName: 'Afaan Oromo',
    nativeName: 'Afaan Oromoo',
    subtitle: 'Qubee script curriculum in progress',
    badgeLabel: 'NEXT RELEASE',
    isAvailable: false,
  ),
];

/// Language-selection screen — maps to
/// `stich-screens/.../3._language_selection/`.
///
/// Renders course options from [_courseOptions] as a list, not a single
/// hardcoded widget, so Amharic being the only live course today doesn't
/// bake that assumption into the layout.
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.onboardingRepository,
  });

  final OnboardingRepository onboardingRepository;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  // Amharic is the only available course, so it's selected by default —
  // there's nothing else the user could pick today.
  String? _selectedCode = _courseOptions.firstWhere((c) => c.isAvailable).code;

  Future<void> _onContinuePressed() async {
    final selected = _selectedCode;
    if (selected == null) return;
    await widget.onboardingRepository.selectLanguage(selected);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AuthRoutes.dailyGoalSelection);
  }

  void _onJoinWaitlistPressed(CourseOption option) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("You're on the waitlist for ${option.displayName}."),
      ),
    );
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
                      'What do you want to learn?',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2xs),
                    Text(
                      'Choose your journey to connect with heritage & family.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceLg),
                    for (final option in _courseOptions)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.spaceMd,
                        ),
                        child: SelectableOptionCard(
                          leading: _FlagBadge(available: option.isAvailable),
                          title: '${option.displayName} · ${option.nativeName}',
                          subtitle: option.subtitle,
                          badgeLabel: option.badgeLabel,
                          selected: _selectedCode == option.code,
                          enabled: option.isAvailable,
                          onTap: option.isAvailable
                              ? () =>
                                    setState(() => _selectedCode = option.code)
                              : null,
                          trailingAction: option.isAvailable
                              ? null
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        _onJoinWaitlistPressed(option),
                                    child: Text(
                                      'Join Waitlist',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'You can always add more languages anytime in your settings.',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
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
              child: TactileButton(
                label: 'Continue',
                onPressed: _selectedCode == null ? null : _onContinuePressed,
                trailing: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 28,
      decoration: BoxDecoration(
        color: available
            ? AppColors.primaryContainer.withValues(alpha: 0.15)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(
        available ? Icons.flag : Icons.park,
        size: 18,
        color: available
            ? AppColors.primaryContainer
            : AppColors.onSurfaceVariant,
      ),
    );
  }
}
