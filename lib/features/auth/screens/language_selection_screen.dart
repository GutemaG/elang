import 'package:flutter/material.dart';

import '../../../shared/l10n/app_language.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/language_names.dart';
import '../../../shared/services/course_api.dart';
import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/selectable_option_card.dart';
import '../auth_routes.dart';
import '../../../shared/models/learn_prompts.dart';

/// Language-selection screen — maps to
/// `stich-screens/.../3._language_selection/`.
///
/// Asks two things (010-multi-language-courses): the language the learner
/// speaks and the course they want. Both come from the public course
/// catalog ([CourseApi.getCatalog]) rather than a hardcoded list: one
/// section per language some available course is taught from ("For English
/// speakers", each in its own language), English first and open, the rest
/// closed so the list stays short however many languages there are (after
/// Duolingo's course list). Opening one closes the others and chooses its
/// first course; the heading follows, in that language ([LearnPrompts]).
/// Coming-soon courses are disabled. So an Amharic speaker can start on Afaan Oromo and the reverse,
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

  /// The section that is open; null once the learner closes it. The choice
  /// ([_fromCode], [_learningCode]) stays when it closes.
  String? _openFrom;

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
        _openFrom = _fromCode;
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

  /// Opens [code]'s section, closing the others, and chooses its first
  /// course unless a course from it is already chosen. Toggling the open
  /// section closes it.
  void _toggleFrom(List<Course> catalog, String code) {
    setState(() {
      if (_openFrom == code) {
        _openFrom = null;
        return;
      }
      _openFrom = code;
      if (_fromCode != code) {
        _fromCode = code;
        _learningCode = _firstAvailableLearning(catalog, code);
      }
    });
  }

  Future<void> _onContinuePressed() async {
    final learning = _learningCode;
    final from = _fromCode;
    if (learning == null || from == null) return;
    // The app's own words switch to the language spoken, if the app has
    // it and none is chosen yet (024-app-localization, story 005).
    await AppLanguageScope.maybeOf(context)?.adoptSignUpLanguage(from);
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
          context.l10n.onWaitlist(languageName(course.learningLanguage)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final ready =
        !_loading && catalog != null && _fromOptions(catalog).isNotEmpty;
    return AppPage(
      // Loading and errors fill the page themselves; the choices scroll.
      scrollable: ready,
      bottomDock: [
        AppButton.primary(
          label: context.l10n.continueButton,
          onPressed: _learningCode == null ? null : _onContinuePressed,
          trailing: const Icon(Icons.arrow_forward, size: 20),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingState();
    }
    final catalog = _catalog;
    if (catalog == null || _fromOptions(catalog).isEmpty) {
      return ErrorState(
        title: catalog == null
            ? context.l10n.coursesLoadFailed
            : context.l10n.noCoursesYet,
        onRetry: _load,
        retryLabel: context.l10n.retry,
      );
    }
    final prompts = LearnPrompts.of(_fromCode ?? 'en');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            prompts.question,
            style: AppTypography.forText(
              AppTypography.headlineSm.copyWith(
                color: context.colors.onSurface,
              ),
              prompts.question,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space2xs),
        Text(
          prompts.subtitle,
          style: AppTypography.forText(
            AppTypography.bodySm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            prompts.subtitle,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        for (final from in _fromOptions(catalog))
          ExpandableSection(
            title: LearnPrompts.of(from).forSpeakers,
            expanded: _openFrom == from,
            onToggle: () => _toggleFrom(catalog, from),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final course in catalog)
                  if (course.fromLanguage == from)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.spaceSm),
                      child: _courseCard(course),
                    ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.spaceLg),
        Text(
          context.l10n.switchCoursesAnytime,
          style: AppTypography.bodySm.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _courseCard(Course course) {
    return SelectableOptionCard(
      leading: _FlagBadge(available: course.isAvailable),
      title:
          '${languageName(course.learningLanguage)} · '
          '${languageNativeName(course.learningLanguage)}',
      subtitle: course.title,
      badgeLabel: course.isAvailable ? null : context.l10n.comingSoonBadge,
      selected:
          _fromCode == course.fromLanguage &&
          _learningCode == course.learningLanguage,
      enabled: course.isAvailable,
      onTap: course.isAvailable
          ? () => setState(() {
              _fromCode = course.fromLanguage;
              _learningCode = course.learningLanguage;
            })
          : null,
      trailingAction: course.isAvailable
          ? null
          : Align(
              alignment: Alignment.centerRight,
              child: AppButton.text(
                label: context.l10n.joinWaitlist,
                onPressed: () => _onJoinWaitlistPressed(course),
              ),
            ),
    );
  }
}

/// The course's flag, in the rounded-square badge.
class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return IconBadge(
      icon: available ? Icons.flag : Icons.park,
      tone: available ? AppTone.primary : AppTone.neutral,
      square: true,
    );
  }
}
