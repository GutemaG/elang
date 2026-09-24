import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A single-select, tactile-card list item shared by the language-selection
/// and daily-goal-selection screens (radio-style behavior: at most one
/// [SelectableOptionCard] in a group is selected at a time).
///
/// Handles three visual states: selected, unselected/selectable, and
/// disabled ("coming soon" style locked options).
class SelectableOptionCard extends StatelessWidget {
  const SelectableOptionCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.badgeLabel,
    this.trailingAction,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? badgeLabel;
  final Widget? trailingAction;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = !enabled
        ? AppColors.outlineVariant
        : selected
        ? AppColors.primaryContainer
        : AppColors.cardBorderDefault;
    final Color background = !enabled
        ? AppColors.surfaceContainerLowest.withValues(alpha: 0.6)
        : selected
        ? AppColors.optionChosen
        : AppColors.surfaceContainerLowest;

    return Opacity(
      opacity: enabled ? 1 : 0.8,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.spaceMd),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leading,
                          const SizedBox(width: AppSpacing.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (badgeLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.space2xs,
                                    ),
                                    child: Text(
                                      badgeLabel!,
                                      style: AppTypography.labelSm.copyWith(
                                        color: enabled
                                            ? AppColors.primaryContainer
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                Text(
                                  title,
                                  style: AppTypography.headlineSm.copyWith(
                                    color: enabled
                                        ? (selected
                                              ? AppColors.primaryContainer
                                              : AppColors.onSurface)
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space2xs),
                                Text(
                                  subtitle,
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    _buildIndicator(),
                  ],
                ),
                if (trailingAction != null) ...[
                  const SizedBox(height: AppSpacing.spaceSm),
                  Divider(height: 1, color: AppColors.surfaceContainer),
                  const SizedBox(height: AppSpacing.spaceXs),
                  trailingAction!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    if (!enabled) {
      return const Icon(
        Icons.lock_outline,
        color: AppColors.onSurfaceVariant,
        size: 20,
      );
    }
    if (selected) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: AppColors.onPrimary, size: 18),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.outlineVariant, width: 2),
      ),
    );
  }
}
