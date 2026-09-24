import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// A single-select, tactile-card list item shared by the language-selection
/// and daily-goal-selection screens (radio-style behavior: at most one
/// [SelectableOptionCard] in a group is selected at a time).
///
/// Handles three visual states: selected, unselected/selectable, and
/// disabled ("coming soon" style locked options). Built on [AppCard]
/// (018-mobile-design-system, story 006), so it presses like every other
/// card and a chosen option takes the primary tone's border and face.
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
    // Disabled options stay readable but visibly out of reach: dimmed, with
    // the lock in place of the radio indicator.
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: AppCard(
        tone: enabled && selected ? AppTone.primary : AppTone.neutral,
        selected: enabled && selected,
        onTap: enabled ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: AppTypography.forText(
                          AppTypography.headlineSm.copyWith(
                            color: enabled
                                ? (selected
                                      ? AppColors.primaryContainer
                                      : AppColors.onSurface)
                                : AppColors.onSurfaceVariant,
                          ),
                          title,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space2xs),
                      Text(
                        subtitle,
                        style: AppTypography.forText(
                          AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          subtitle,
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
              const SizedBox(
                height: 1,
                width: double.infinity,
                child: ColoredBox(color: AppColors.surfaceContainer),
              ),
              const SizedBox(height: AppSpacing.spaceXs),
              trailingAction!,
            ],
          ],
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
