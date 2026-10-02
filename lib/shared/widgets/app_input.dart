import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_context.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';

/// Several lines of free text (027-learner-feedback): a cream field with
/// the card border, green when focused, and a character count under it
/// when [maxLength] is set. Corners are a choice tile's.
class AppTextArea extends StatelessWidget {
  const AppTextArea({
    super.key,
    required this.controller,
    this.hint,
    this.maxLength,
    this.minLines = 5,
    this.maxLines = 10,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: BorderSide(color: color, width: 2),
    );
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.sentences,
      style: AppTypography.bodyLg.copyWith(color: context.colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintMaxLines: 3,
        hintStyle: AppTypography.bodyMd.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
        filled: true,
        fillColor: context.colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.all(AppSpacing.spaceMd),
        enabledBorder: border(context.colors.cardBorder),
        focusedBorder: border(context.colors.primary),
      ),
    );
  }
}

/// Five stars, gold up to [rating], none at first. Tapping the chosen star
/// again clears it, so a rating can stay optional. Each star's tooltip,
/// "Rate 3 out of 5", is what a screen reader announces.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, required this.onChanged});

  final int? rating;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final gold = context.tone(AppTone.secondary).icon;
    final chosen = rating ?? 0;
    // Wraps, so the "4 / 5" goes under the stars on a narrow phone.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var n = 1; n <= 5; n++)
          IconButton(
            tooltip: 'Rate $n out of 5',
            isSelected: rating == n,
            iconSize: 32,
            onPressed: () => onChanged(rating == n ? null : n),
            icon: Icon(
              n <= chosen ? Icons.star_rounded : Icons.star_outline_rounded,
              color: n <= chosen ? gold : context.colors.outline,
            ),
          ),
        if (rating != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXs),
            child: Text(
              '$rating / 5',
              style: AppTypography.labelLg.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
