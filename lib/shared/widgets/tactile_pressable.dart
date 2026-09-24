import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// The one press behaviour behind every tactile element (buttons now; cards,
/// answer tiles and the audio button in later bolts), so they all feel the
/// same under a finger.
///
/// The face rests on a shelf drawn by [shadows]. Pressed, it sinks by
/// [travel] and the shelf flattens, almost at once ([AppMotion.pressIn]).
/// Released, it springs back and slightly past rest ([AppMotion.pressOut]).
/// The space for the shelf is reserved below the face, so pressing never
/// moves anything around it. When the system asks for less motion the face
/// only darkens while pressed.
class TactilePressable extends StatefulWidget {
  const TactilePressable({
    super.key,
    required this.onPressed,
    required this.faceColor,
    required this.borderRadius,
    required this.child,
    this.borderColor,
    this.borderWidth = 2,
    this.shadows,
    this.shelfDepth = 0,
    this.travel,
    this.height,
  });

  /// `null` disables the element: no press, no tap.
  final VoidCallback? onPressed;
  final Color faceColor;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final double borderWidth;

  /// The shelf and any soft shadow, given how much of the shelf shows
  /// (1 at rest, 0 pressed, a little over 1 while springing back).
  final List<BoxShadow> Function(double visible)? shadows;

  /// Space reserved under the face for the shelf.
  final double shelfDepth;

  /// How far the face sinks when pressed; defaults to [shelfDepth].
  final double? travel;

  /// A fixed face height; otherwise the face sizes to [child].
  final double? height;
  final Widget child;

  @override
  State<TactilePressable> createState() => _TactilePressableState();
}

class _TactilePressableState extends State<TactilePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.pressIn,
    reverseDuration: AppMotion.pressOut,
  );
  late final CurvedAnimation _press = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.pressInCurve,
    reverseCurve: AppMotion.pressOutCurve.flipped,
  );
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  void didUpdateWidget(covariant TactilePressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _pressed) _setPressed(false);
  }

  @override
  void dispose() {
    _press.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (value && !_enabled) return;
    if (value == _pressed) return;
    setState(() => _pressed = value);
    if (value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final travel = widget.travel ?? widget.shelfDepth;
    final face = reduced && _pressed
        ? Color.alphaBlend(
            AppColors.shadowInk.withValues(alpha: 0.08),
            widget.faceColor,
          )
        : widget.faceColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapUp: _enabled ? (_) => _setPressed(false) : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      onTap: widget.onPressed,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.shelfDepth),
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final pressed = reduced ? 0.0 : _press.value;
            return Transform.translate(
              offset: Offset(0, travel * pressed),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: face,
                  borderRadius: widget.borderRadius,
                  border: widget.borderColor == null
                      ? null
                      : Border.all(
                          color: widget.borderColor!,
                          width: widget.borderWidth,
                        ),
                  boxShadow: widget.shadows?.call(1 - pressed),
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
