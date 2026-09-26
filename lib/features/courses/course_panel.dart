import 'package:flutter/material.dart';

import '../../shared/models/course.dart';
import '../../shared/models/language_names.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_status.dart';
import '../../shared/widgets/course_glyph.dart';

/// The panel that drops from the dashboard's course badge
/// (011-dashboard-ui-polish, stories 003 and 004).
///
/// Holds everything to do with courses in one place: the rail of courses the
/// learner has opened, a tile to add another, and the two screens that used to
/// be icon buttons competing with the skill path.
///
/// Its surface is an [AppCard] and its entries are [ListRow]s
/// (018-mobile-design-system, bolt 047).
class CoursePanel extends StatelessWidget {
  const CoursePanel({
    super.key,
    required this.courses,
    required this.activeCourseId,
    required this.onCourseSelected,
    required this.onAddCourse,
    required this.onSettings,
    required this.onDownloads,
    this.loading = false,
    this.onRetry,
  });

  /// The rail, active course first. Empty while [loading] or after a failure.
  final List<Course> courses;
  final String? activeCourseId;
  final ValueChanged<Course> onCourseSelected;
  final VoidCallback onAddCourse;
  final VoidCallback onSettings;
  final VoidCallback onDownloads;
  final bool loading;

  /// Non-null when the course list failed to load.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.spaceSm,
        AppSpacing.spaceXs,
        AppSpacing.spaceSm,
        0,
      ),
      child: AppCard(
        padding: AppCardPadding.none,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.spaceSm),
            _rail(context),
            const SizedBox(height: AppSpacing.spaceXs),
            const SizedBox(
              height: 1,
              child: ColoredBox(color: AppColors.cardBorderDefault),
            ),
            ListRow(
              icon: Icons.settings_outlined,
              title: 'Course settings',
              onTap: onSettings,
            ),
            ListRow(
              icon: Icons.folder_outlined,
              title: 'Manage downloads',
              onTap: onDownloads,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rail(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: _CourseTile.height,
        child: Center(child: AppSpinner()),
      );
    }
    if (onRetry != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceMd),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Couldn't load your courses",
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.spaceXs),
            AppButton.secondary(
              label: 'Retry',
              onPressed: onRetry,
              expand: false,
              size: AppButtonSize.compact,
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: _CourseTile.height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXs),
        children: [
          for (final course in courses)
            _CourseTile(
              course: course,
              selected: course.id == activeCourseId,
              onTap: () => onCourseSelected(course),
            ),
          _AddCourseTile(onTap: onAddCourse),
        ],
      ),
    );
  }
}

/// One course in the rail: its glyph, the language it teaches, and the
/// language it teaches from. The active one wears the ring.
class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.selected,
    required this.onTap,
  });

  static const double height = 92;
  static const double width = 84;

  final Course course;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // One node per tile: the glyph and the two lines mean nothing apart, so
    // the tile announces itself as a whole and nothing else.
    return Semantics(
      button: true,
      selected: selected,
      container: true,
      excludeSemantics: true,
      label: selected
          ? '${languageName(course.learningLanguage)}, current course'
          : 'Switch to ${languageName(course.learningLanguage)} from '
                '${languageName(course.fromLanguage)}',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CourseGlyph(
                languageCode: course.learningLanguage,
                size: 44,
                selected: selected,
              ),
              const SizedBox(height: AppSpacing.space2xs),
              Text(
                languageName(course.learningLanguage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSm.copyWith(
                  color: selected
                      ? AppColors.primaryContainer
                      : AppColors.onSurface,
                ),
              ),
              Text(
                'from ${languageName(course.fromLanguage)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCourseTile extends StatelessWidget {
  const _AddCourseTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Add a course',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _CourseTile.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const IconBadge(icon: Icons.add, size: 44, square: true),
              const SizedBox(height: AppSpacing.space2xs),
              Text(
                'Course',
                maxLines: 1,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
