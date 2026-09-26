import 'package:flutter/material.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/app_status.dart';

/// The "Stat Badges & Floating HUD" component (`DESIGN.md` component 3):
/// streak, beans, XP, and (bolt 018-amole-ui) Amole pills.
///
/// 011-dashboard-ui-polish, story 001: these live in the dashboard's pinned
/// header now, sharing one row with the course control, so every pill is an
/// icon and a value. The streak's spelled-out "N Day Streak" would not fit
/// four pills and a course name at 320dp; it survives as the pill's semantic
/// label, so a screen reader still reads what it read before.
///
/// Each pill is the library's [StatPill] (018-mobile-design-system, bolt
/// 047).
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
          StatPill(kind: StatKind.streak, value: streakCount),
          const SizedBox(width: AppSpacing.spaceXs),
          StatPill(kind: StatKind.beans, value: beans, max: beansMax),
          const SizedBox(width: AppSpacing.spaceXs),
          StatPill(kind: StatKind.xp, value: totalXp),
          const SizedBox(width: AppSpacing.spaceXs),
          StatPill(kind: StatKind.amole, value: amoleBalance),
        ],
      ),
    );
  }
}
