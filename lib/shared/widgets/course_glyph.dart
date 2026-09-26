import 'package:flutter/material.dart';

import '../models/language_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A course as a glyph tile: the first character of the language's own name
/// on a green rounded square (011-dashboard-ui-polish, story 003; moved into
/// the library by 018-mobile-design-system, bolt 047).
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
