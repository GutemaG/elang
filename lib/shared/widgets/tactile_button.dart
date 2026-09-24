import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'tactile_pressable.dart';

/// The original pill-shaped push button, whose colours each screen passes
/// in by hand.
///
/// **New code uses [AppButton]**, whose variants fix the colours so the same
/// kind of action looks the same everywhere. This widget stays, with the
/// same parameters, until every screen has moved to [AppButton]
/// (018-mobile-design-system, bolt 049). It presses exactly like
/// [AppButton] because both are built on [TactilePressable].
class TactileButton extends StatelessWidget {
  const TactileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.backgroundColor = AppColors.primaryContainer,
    this.bevelColor = AppColors.primaryBevel,
    this.foregroundColor = AppColors.onPrimary,
    this.borderColor,
    this.height = 56,
    this.bevelThickness = AppShadows.shelfDepth,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final Color backgroundColor;
  final Color bevelColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double height;
  final double bevelThickness;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return TactilePressable(
      onPressed: onPressed,
      faceColor: backgroundColor.withValues(alpha: enabled ? 1 : 0.6),
      borderColor: borderColor,
      borderRadius: BorderRadius.circular(AppRadii.full),
      height: height,
      shelfDepth: bevelThickness,
      shadows: (visible) => AppShadows.button(
        bevelColor,
        depth: bevelThickness,
        visible: visible,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.spaceSm),
            ],
            Text(
              label,
              style: AppTypography.labelLg.copyWith(color: foregroundColor),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.spaceSm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
