import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'tactile_pressable.dart';

/// A round icon action (close, back, more): a 40 px circle on a soft
/// surface, as in the out-of-beans mockup, inside a 48×48 tap target.
///
/// [tooltip] is required: it is also what a screen reader announces.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.plain = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// No surface behind the icon, for top bars that sit on a busy background.
  final bool plain;

  static const double faceSize = 40;
  static const double tapTarget = 48;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: tapTarget,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.6,
              child: TactilePressable(
                onPressed: onPressed,
                faceColor: plain
                    ? AppColors.surfaceContainerLowest.withValues(alpha: 0)
                    : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadii.full),
                travel: 2,
                height: faceSize,
                child: SizedBox.square(
                  dimension: faceSize,
                  child: Icon(
                    icon,
                    size: 22,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
