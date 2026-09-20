import 'package:flutter/material.dart';

import '../../shared/models/course.dart';
import '../../shared/models/language_names.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';

/// A course as a glyph tile: the first character of the language's own name
/// on a rounded square (011-dashboard-ui-polish, story 003).
///
/// Stands in for the flag the app has no artwork for, and carries the script
/// as information: Amharic reads as Fidel, Afaan Oromo as Latin.
class CourseGlyph extends StatelessWidget {
  const CourseGlyph({
    super.key,
    required this.languageCode,
    this.size = 32,
    this.selected = false,
  });

  final String languageCode;

  /// Edge length of the tile.
  final double size;

  /// Draws the active-course ring.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: selected
            ? Border.all(color: AppColors.secondaryContainer, width: 3)
            : Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        languageGlyph(languageCode),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: AppTypography.labelLg.copyWith(
          color: AppColors.onPrimary,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(AppRadii.base),
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
