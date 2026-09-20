import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import 'pinned_header_sliver.dart';

/// The dashboard's one piece of permanent chrome (011-dashboard-ui-polish,
/// story 001): the course control on the left, the stat pills on the right.
///
/// Pinned to the top of the dashboard's scroll view, so the learner's streak,
/// beans, XP and Amole are readable at any scroll position. It is opaque and
/// has a bottom edge because skill nodes really do scroll underneath it.
///
/// The header owns its height: [extentOf] is the single source of truth and
/// [leading] is given exactly that much room. A leading widget that could be
/// taller must shrink itself (as the stat pills do) rather than push the
/// header, whose extent has to be known before layout.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.leading, required this.hud});

  /// The course control. Today the course chip and the icon buttons;
  /// 011's bolt 029 replaces it with the course badge.
  final Widget leading;

  /// The stat pills, right-aligned.
  final Widget hud;

  static const double _borderWidth = 1;

  /// How much of the header's width the leading control may claim before the
  /// stat pills start being scaled down.
  static const double _leadingWidthShare = 0.62;

  /// A stat pill's outer height: its vertical padding, the taller of its icon
  /// and its label, and its border.
  static double pillHeight(BuildContext context) =>
      AppSpacing.space2xs * 2 +
      _max(18, scaledLineHeight(context, AppTypography.labelMd)) +
      2;

  /// The height of the row inside the header's padding. Floored at a 48dp tap
  /// target so the course control is always comfortably tappable.
  static double contentHeight(BuildContext context) =>
      _max(48, pillHeight(context));

  /// What the pinned sliver must reserve for this header.
  static double extentOf(BuildContext context) =>
      AppSpacing.spaceXs * 2 + contentHeight(context) + _borderWidth;

  static double _max(double a, double b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorderDefault,
            width: _borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.spaceXs,
        ),
        child: SizedBox(
          height: contentHeight(context),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                // The leading control has rigid parts (tap targets) that
                // cannot ellipsise, so it is given a share of the width
                // outright. Splitting the row evenly would starve it at
                // 320dp; the pills, which scale themselves down, take
                // whatever is left.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * _leadingWidthShare,
                  ),
                  child: leading,
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: Align(alignment: Alignment.centerRight, child: hud),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
