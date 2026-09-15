import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A pill-shaped button with the Highland Pulse "3D extruded bevel" press
/// effect: a solid bottom shelf that flattens and shifts the button down by
/// [bevelThickness] while pressed, per `highland_pulse/DESIGN.md`'s
/// "Tactile Level 2" elevation model.
///
/// Used for every primary/secondary/provider call-to-action across the
/// auth/onboarding flow so the bevel-press behavior lives in one place.
class TactileButton extends StatefulWidget {
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
    this.bevelThickness = 4,
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
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final double translateY = _pressed ? widget.bevelThickness : 0;
    final double opacity = _enabled ? 1 : 0.6;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: widget.bevelThickness - translateY),
        transform: Matrix4.translationValues(0, translateY, 0),
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: widget.borderColor != null
              ? Border.all(color: widget.borderColor!, width: 2)
              : null,
          boxShadow: _pressed
              ? const []
              : [
                  BoxShadow(
                    color: widget.bevelColor,
                    offset: Offset(0, widget.bevelThickness),
                  ),
                ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: AppSpacing.spaceSm),
              ],
              Text(
                widget.label,
                style: AppTypography.labelLg.copyWith(
                  color: widget.foregroundColor,
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: AppSpacing.spaceSm),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
