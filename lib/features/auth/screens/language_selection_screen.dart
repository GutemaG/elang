import 'package:flutter/material.dart';

import '../../../shared/models/course.dart';
import '../../../shared/models/language_names.dart';
import '../../../shared/services/course_api.dart';
import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/selectable_option_card.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../auth_routes.dart';

/// Language-selection screen — maps to
/// `stich-screens/.../3._language_selection/`.
///
/// Asks two things (010-multi-language-courses): "I speak" and "I want to
/// learn". Both come from the public course catalog
/// ([CourseApi.getCatalog]) rather than a hardcoded list: "I speak" offers
/// every language some available course is taught from, and "I want to learn"
/// lists the courses taught from that language, with coming-soon ones
/// disabled. So an Amharic speaker can start on Afaan Oromo and the reverse,
/// with no English involved, and a pair with no available course can never be
/// continued. If the catalog cannot be loaded the screen says so and offers
/// Retry — there is no silent default.
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.onboardingRepository,
    required this.courseApi,
  });

  final OnboardingRepository onboardingRepository;
  final CourseApi courseApi;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  List<Course>? _catalog;
  bool _loading = true;
  String? _fromCode;
  String? _learningCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _catalog = null;
    });
    try {
      final catalog = await widget.courseApi.getCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
        _fromCode = _defaultFrom(catalog);
        _learningCode = _firstAvailableLearning(catalog, _fromCode);
      });
    } on CourseApiException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Languages some available course is taught from, English first when
  /// present (the most common starting point).
  List<String> _fromOptions(List<Course> catalog) {
    final codes = <String>[];
    for (final course in catalog) {
      if (course.isAvailable && !codes.contains(course.fromLanguage)) {
        codes.add(course.fromLanguage);
      }
    }
    if (codes.remove('en')) codes.insert(0, 'en');
    return codes;
  }

  String? _defaultFrom(List<Course> catalog) {
    final options = _fromOptions(catalog);
    return options.isEmpty ? null : options.first;
  }

  String? _firstAvailableLearning(List<Course> catalog, String? from) {
    for (final course in catalog) {
      if (course.fromLanguage == from && course.isAvailable) {
        return course.learningLanguage;
      }
    }
    return null;
  }

  void _selectFrom(List<Course> catalog, String code) {
    setState(() {
      _fromCode = code;
      _learningCode = _firstAvailableLearning(catalog, code);
    });
  }

  Future<void> _onContinuePressed() async {
    final learning = _learningCode;
    final from = _fromCode;
    if (learning == null || from == null) return;
    await widget.onboardingRepository.selectLanguage(
      learning,
      fromLanguageCode: from,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AuthRoutes.dailyGoalSelection);
  }

  void _onJoinWaitlistPressed(Course course) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "You're on the waitlist for ${languageName(course.learningLanguage)}.",
        ),
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
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile,
                AppSpacing.spaceSm,
                AppSpacing.marginMobile,
                AppSpacing.spaceLg,
              ),
              child: TactileButton(
                label: 'Continue',
                onPressed: _learningCode == null ? null : _onContinuePressed,
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final catalog = _catalog;
    if (catalog == null || _fromOptions(catalog).isEmpty) {
      return _LoadError(
        message: catalog == null
            ? "Couldn't load the courses."
            : 'No courses are available yet.',
        onRetry: _load,
      );
    }
    final coursesFromHere = [
      for (final course in catalog)
        if (course.fromLanguage == _fromCode) course,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            'I speak',
            style: AppTypography.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Wrap(
            spacing: AppSpacing.spaceXs,
            runSpacing: AppSpacing.spaceXs,
            children: [
              for (final code in _fromOptions(catalog))
                ChoiceChip(
                  label: Text(languageNativeName(code)),
                  selected: _fromCode == code,
                  onSelected: (_) => _selectFrom(catalog, code),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceLg),
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
          const SizedBox(height: AppSpacing.spaceMd),
          for (final course in coursesFromHere)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
              child: SelectableOptionCard(
                leading: _FlagBadge(available: course.isAvailable),
                title:
                    '${languageName(course.learningLanguage)} · '
                    '${languageNativeName(course.learningLanguage)}',
                subtitle: course.title,
                badgeLabel: course.isAvailable ? null : 'COMING SOON',
                selected: _learningCode == course.learningLanguage,
                enabled: course.isAvailable,
                onTap: course.isAvailable
                    ? () => setState(
                        () => _learningCode = course.learningLanguage,
                      )
                    : null,
                trailingAction: course.isAvailable
                    ? null
                    : Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _onJoinWaitlistPressed(course),
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
          Text(
            'You can always switch courses anytime from the home screen or '
            'your settings.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            TactileButton(label: 'Retry', onPressed: onRetry),
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
