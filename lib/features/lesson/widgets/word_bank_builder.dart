import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../state/lesson_controller.dart';

/// Sentence-construction's "tap-to-build from a word bank" interaction
/// (FR-2): a built-sentence tray above a word bank; tapping a bank token
/// appends it and greys it out, tapping a built token removes it back to
/// the bank.
class WordBankBuilder extends StatelessWidget {
  const WordBankBuilder({
    super.key,
    required this.wordBank,
    required this.built,
    required this.feedback,
    required this.onToggle,
  });

  final List<String> wordBank;
  final List<String> built;
  final TileFeedback feedback;
  final ValueChanged<String> onToggle;

  bool get _locked => feedback != TileFeedback.none;

  @override
  Widget build(BuildContext context) {
    final Color trayBorder = switch (feedback) {
      TileFeedback.none => AppColors.cardBorderDefault,
      TileFeedback.correct => AppColors.primaryContainer,
      TileFeedback.incorrect => AppColors.tertiaryBrand,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(AppSpacing.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: trayBorder, width: 2),
          ),
          child: built.isEmpty
              ? Text(
                  'Tap words below to build your answer',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.spaceXs,
                  runSpacing: AppSpacing.spaceXs,
                  children: [
                    for (final token in built)
                      _WordChip(
                        label: token,
                        onTap: _locked ? null : () => onToggle(token),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        Wrap(
          spacing: AppSpacing.spaceXs,
          runSpacing: AppSpacing.spaceXs,
          children: [
            for (final token in wordBank)
              _WordChip(
                label: token,
                dimmed: built.contains(token),
                onTap: (_locked || built.contains(token))
                    ? null
                    : () => onToggle(token),
              ),
          ],
        ),
      ],
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.label, this.onTap, this.dimmed = false});

  final String label;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Opacity(
        opacity: dimmed ? 0.35 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(color: AppColors.cardBorderDefault, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardBevelDefault,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
          ),
        ),
      ),
    );
  }
}
