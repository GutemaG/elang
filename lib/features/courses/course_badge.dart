import 'package:flutter/material.dart';

import '../../shared/models/course.dart';
import '../../shared/models/language_names.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/course_glyph.dart';

export '../../shared/widgets/course_glyph.dart' show CourseGlyph;

/// The dashboard header's course control (011-dashboard-ui-polish, story
/// 003): the active course's glyph and language, tapped to open the course
/// panel.
///
/// Replaces the course chip and the two icon buttons that shared the header
/// before, which is what gives the language name room to stop truncating.
class CourseBadge extends StatelessWidget {
  const CourseBadge({
    super.key,
    required this.course,
    required this.expanded,
    required this.onTap,
  });

  /// `null` when the backend sent no course, which reads as "Courses".
  final Course? course;

  /// Whether the panel is open, so the chevron can point at it.
  final bool expanded;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final course = this.course;
    final label = course == null
        ? 'Courses'
        : languageName(course.learningLanguage);
    return Semantics(
      button: true,
      expanded: expanded,
      label: 'Course: $label',
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space2xs,
            vertical: AppSpacing.space2xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (course != null)
                CourseGlyph(languageCode: course.learningLanguage)
              else
                const Icon(
                  Icons.translate,
                  size: 24,
                  color: AppColors.primaryContainer,
                ),
              const SizedBox(width: AppSpacing.spaceXs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.expand_more,
                  size: 20,
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
