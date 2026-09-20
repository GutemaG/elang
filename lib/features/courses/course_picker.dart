import 'package:flutter/material.dart';

import '../../shared/models/course.dart';
import '../../shared/models/language_names.dart';
import '../../shared/services/caching_course_api.dart';
import '../../shared/services/course_api.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/selectable_option_card.dart';
import '../../shared/widgets/tactile_button.dart';

/// Opens the course picker and, if the learner chooses a different course,
/// switches to it. Shared by the dashboard's course chip and Settings.
///
/// Returns the newly active course, or `null` if the learner dismissed the
/// picker, chose the course that is already active, or the switch failed (in
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
    if (context.mounted) {
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
    return null;
  }
}

/// The course list: grouped by the language to learn, with the language the
/// learner speaks on each row, the active course marked, and courses that are
/// coming soon disabled. Everything comes from [CourseApi.getCourses].
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
              Text(
                'Choose a course',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
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
    // Grouped by learning language, in the order each first appears.
    final groups = <String, List<Course>>{};
    for (final course in courses) {
      groups.putIfAbsent(course.learningLanguage, () => []).add(course);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in groups.entries) ...[
            Text(
              'Learn ${languageName(entry.key)}',
              style: AppTypography.labelLg.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceXs),
            for (final course in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                child: SelectableOptionCard(
                  leading: Icon(
                    course.isAvailable ? Icons.flag : Icons.lock_outline,
                    color: AppColors.primaryContainer,
                  ),
                  title: 'From ${languageName(course.fromLanguage)}',
                  subtitle: _subtitle(course),
                  selected: course.isActive,
                  enabled: course.isAvailable,
                  onTap: course.isAvailable
                      ? () => Navigator.of(context).pop(course)
                      : null,
                ),
              ),
            const SizedBox(height: AppSpacing.spaceSm),
          ],
        ],
      ),
    );
  }

  String _subtitle(Course course) {
    if (!course.isAvailable) return 'Coming soon';
    if (course.totalSkills == 0) return course.title;
    return '${course.title} · ${course.completedSkills}/${course.totalSkills} skills';
  }
}
