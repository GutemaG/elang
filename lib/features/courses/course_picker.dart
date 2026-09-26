import 'package:flutter/material.dart';

import '../../shared/models/course.dart';
import '../../shared/models/language_names.dart';
import '../../shared/services/caching_course_api.dart';
import '../../shared/services/course_api.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_tone.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_status.dart';
import '../../shared/widgets/course_glyph.dart';

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
  final picked = await showAppSheet<Course>(
    context: context,
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
/// [pickAndSwitchCourse]. Drawn inside the library's sheet, with a card per
/// course (018-mobile-design-system, bolt 047).
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
    // The sheet scrolls when the catalog is taller than the screen, so the
    // content here only needs to lay out at its natural height.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            AppIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        FutureBuilder<CourseList>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.spaceLg),
                child: Center(child: AppSpinner()),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                title: "Couldn't load your courses",
                onRetry: _retry,
                retryLabel: 'Retry',
              );
            }
            return _CourseGroups(courses: snapshot.data!.courses);
          },
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
  }
}

/// One catalog entry, an [AppCard]: chosen for the active course, faded when
/// coming soon. Deliberately leaner than `SelectableOptionCard`: the catalog
/// can be long, and progress reads better as a bar than as a count in a
/// sentence.
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final enabled = course.isAvailable;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: AppCard(
        tone: course.isActive ? AppTone.primary : AppTone.neutral,
        selected: course.isActive,
        padding: AppCardPadding.compact,
        onTap: enabled ? () => Navigator.of(context).pop(course) : null,
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
                    AppProgressBar(
                      value: course.completedSkills / course.totalSkills,
                      semanticLabel:
                          '${course.completedSkills} of '
                          '${course.totalSkills} skills',
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
