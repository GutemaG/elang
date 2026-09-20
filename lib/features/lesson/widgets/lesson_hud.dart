import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// The "Stat Badges & Floating HUD" component (`DESIGN.md` component 3):
/// streak, beans, XP, and (bolt 018-amole-ui) Amole pills.
///
/// 011-dashboard-ui-polish, story 001: these live in the dashboard's pinned
/// header now, sharing one row with the course control, so every pill is an
/// icon and a value. The streak's spelled-out "N Day Streak" would not fit
/// four pills and a course name at 320dp; it survives as the pill's semantic
/// label, so a screen reader still reads what it read before.
class LessonHud extends StatelessWidget {
  const LessonHud({
    super.key,
    required this.streakCount,
    required this.beans,
    required this.beansMax,
    required this.totalXp,
    required this.amoleBalance,
  });

  final int streakCount;
  final int beans;
  final int beansMax;
  final int totalXp;
  final int amoleBalance;

  @override
  Widget build(BuildContext context) {
    // Scales the whole row down rather than overflowing when the header is
    // narrow or the text is large.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HudPill(
            icon: Icons.local_fire_department,
            iconColor: AppColors.secondaryContainer,
            label: '$streakCount',
            textColor: AppColors.secondary,
            semanticLabel: '$streakCount day streak',
          ),
          const SizedBox(width: AppSpacing.spaceXs),
          _HudPill(
            icon: Icons.favorite,
            iconColor: AppColors.tertiaryBrand,
            label: '$beans',
            textColor: AppColors.tertiaryBrand,
            semanticLabel: '$beans of $beansMax beans remaining',
          ),
          const SizedBox(width: AppSpacing.spaceXs),
          _HudPill(
            icon: Icons.bolt,
            iconColor: AppColors.secondary,
            label: '$totalXp',
            textColor: AppColors.secondary,
            semanticLabel: '$totalXp total XP',
          ),
          const SizedBox(width: AppSpacing.spaceXs),
          _HudPill(
            // Distinct from XP's `Icons.bolt`, to avoid the two pills
            // reading as the same currency at a glance.
            icon: Icons.paid,
            iconColor: AppColors.primaryContainer,
            label: '$amoleBalance',
            textColor: AppColors.primaryContainer,
            semanticLabel: '$amoleBalance Amole',
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.textColor,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color textColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // One node per pill: the icon and the bare number mean nothing apart, so
    // the pill reads as its full label ("100 day streak") and nothing else.
    return Semantics(
      label: semanticLabel,
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceXs,
          vertical: AppSpacing.space2xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
