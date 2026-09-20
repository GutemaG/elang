import 'package:flutter/material.dart';

import '../../shared/models/course.dart';
import '../../shared/models/language_names.dart';
import '../../shared/services/caching_course_api.dart';
import '../../shared/services/course_api.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/tactile_button.dart';
import 'course_badge.dart';

/// Tells the learner why a switch did not happen. Shared by the catalog and
/// the dashboard's course rail so the two never drift apart.
void showCourseSwitchError(BuildContext context, CourseApiException e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        e.errorCode == offlineNotCachedErrorCode
            ? 'Connect to the internet to open this course for the first time.'
            : "Couldn't switch course. Please try again.",
      ),
    ),
  );
}

/// Opens the course catalog and, if the learner chooses a different course,
/// switches to it. Shared by the dashboard's "+ Course" tile and Settings.
///
/// Returns the newly active course, or `null` if the learner dismissed the
/// catalog, chose the course that is already active, or the switch failed (in
/// which case the current course stays active and a message is shown).
Future<Course?> pickAndSwitchCourse(
  BuildContext context, {
  required CourseApi courseApi,
}) async {
  final picked = await showModalBottomSheet<Course>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CoursePickerSheet(courseApi: courseApi),
  );
  if (picked == null || picked.isActive) return null;
  try {
    return await courseApi.switchCourse(picked.id);
  } on CourseApiException catch (e) {
    if (context.mounted) showCourseSwitchError(context, e);
    return null;
  }
}

/// The course catalog: every course grouped by the language the learner
/// speaks ("For English speakers"), because that is the axis a learner
/// chooses along -- they know what they speak and are shopping for what to
/// learn. The active course is marked and coming-soon courses are disabled.
///
/// Pops with the tapped [Course] (not yet switched to); see
/// [pickAndSwitchCourse].
class CoursePickerSheet extends StatefulWidget {
  const CoursePickerSheet({super.key, required this.courseApi});

  final CourseApi courseApi;

  @override
  State<CoursePickerSheet> createState() => _CoursePickerSheetState();
}

class _CoursePickerSheetState extends State<CoursePickerSheet> {
  late Future<CourseList> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.courseApi.getCourses();
  }

  void _retry() {
    setState(() {
      _future = widget.courseApi.getCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose a course',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: AppColors.onSurfaceVariant,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceXs),
              Flexible(
                child: FutureBuilder<CourseList>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.spaceLg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _LoadError(onRetry: _retry);
                    }
                    return _CourseGroups(courses: snapshot.data!.courses);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Couldn't load your courses",
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        TactileButton(label: 'Retry', onPressed: onRetry),
      ],
    );
  }
}

class _CourseGroups extends StatelessWidget {
  const _CourseGroups({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    // Grouped by the language the learner speaks, in the order each first
    // appears, so the catalog reads "I speak X -- what can I learn?".
    final groups = <String, List<Course>>{};
    for (final course in courses) {
      groups.putIfAbsent(course.fromLanguage, () => []).add(course);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.spaceXs),
              child: Text(
                'For ${languageName(entry.key)} speakers',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            for (final course in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.spaceXs),
                child: _CatalogRow(course: course),
              ),
            const SizedBox(height: AppSpacing.spaceMd),
          ],
        ],
      ),
    );
  }
}

/// One catalog entry. Deliberately leaner than `SelectableOptionCard`: the
/// catalog can be long, and progress reads better as a bar than as a count in
/// a sentence.
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final enabled = course.isAvailable;
    return Semantics(
      button: true,
      selected: course.isActive,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? () => Navigator.of(context).pop(course) : null,
        borderRadius: BorderRadius.circular(AppRadii.base),
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(AppSpacing.spaceSm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.base),
              border: Border.all(
                color: course.isActive
                    ? AppColors.primaryContainer
                    : AppColors.cardBorderDefault,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                CourseGlyph(languageCode: course.learningLanguage, size: 36),
                const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        languageName(course.learningLanguage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLg.copyWith(
                          color: course.isActive
                              ? AppColors.primaryContainer
                              : AppColors.onSurface,
                        ),
                      ),
                      Text(
                        enabled ? course.title : '${course.title} · Coming soon',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (enabled && course.totalSkills > 0) ...[
                        const SizedBox(height: AppSpacing.space2xs),
                        _ProgressBar(
                          completed: course.completedSkills,
                          total: course.totalSkills,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceXs),
                _indicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicator() {
    if (!course.isAvailable) {
      return const Icon(
        Icons.lock_outline,
        size: 20,
        color: AppColors.onSurfaceVariant,
      );
    }
    if (course.isActive) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: AppColors.onPrimary, size: 16),
      );
    }
    return const Icon(
      Icons.chevron_right,
      size: 20,
      color: AppColors.onSurfaceVariant,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    // One node: a bare progress value means nothing without the count, and
    // `LinearProgressIndicator` would otherwise announce itself separately.
    return Semantics(
      label: '$completed of $total skills',
      container: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : completed / total,
          minHeight: 6,
          backgroundColor: AppColors.surfaceContainer,
          valueColor: const AlwaysStoppedAnimation(
            AppColors.primaryContainer,
          ),
        ),
      ),
    );
  }
}
