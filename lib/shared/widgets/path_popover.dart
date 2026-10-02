import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_context.dart';
import '../theme/app_typography.dart';
import 'app_status.dart';
import 'path_node.dart';
import 'tactile_pressable.dart';
import '../l10n/app_language.dart';

/// The bubble a tapped path node opens (the Duolingo path's popover): it
/// floats just under the node with a pointer at it, in the node's own
/// colour, and says what the skill is and what tapping on will do. The path
/// itself shows no titles, so this is where a skill is named.
///
/// It grows out of the node and closes on a tap anywhere else or on back.
/// Pops `true` when [actionLabel] is tapped, `null` otherwise. A locked node
/// gets no action: its button shows "Locked" and does nothing.
///
/// [anchor] is the node's rectangle in global coordinates. When there is
/// not enough room below it the bubble opens above, pointing down.
Future<bool?> showPathPopover({
  required BuildContext context,
  required Rect anchor,
  required PathNodeState state,
  required String title,
  required String body,
  String? actionLabel,
  Widget? footer,
}) {
  return Navigator.of(context).push<bool>(
    _PathPopoverRoute(
      anchor: anchor,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      child: PathPopover(
        state: state,
        title: title,
        body: body,
        actionLabel: actionLabel,
        footer: footer,
      ),
    ),
  );
}

/// The bubble's content, without the pointer or the placement; see
/// [showPathPopover].
class PathPopover extends StatelessWidget {
  const PathPopover({
    super.key,
    required this.state,
    required this.title,
    required this.body,
    this.actionLabel,
    this.footer,
  });

  final PathNodeState state;
  final String title;
  final String body;

  /// `null` for a locked node.
  final String? actionLabel;

  /// A quiet line under the button, such as a [PathPopoverNote].
  final Widget? footer;

  static const double maxWidth = 360;

  /// Finds the bubble in tests.
  static const Key bubbleKey = ValueKey('path-popover');

  /// Finds the bubble's button in tests.
  static const Key actionKey = ValueKey('path-popover-action');

  @override
  Widget build(BuildContext context) {
    final tone = PathPopoverTone.of(state, context.colors);
    final actionLabel = this.actionLabel;
    return Material(
      key: bubbleKey,
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.face,
          borderRadius: BorderRadius.circular(AppRadii.base),
          border: tone.border == null
              ? null
              : Border.all(color: tone.border!, width: 2),
          boxShadow: [AppShadows.shelf(tone.shelf), ...context.shadows.overlay],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceMd),
          child: IconTheme.merge(
            data: IconThemeData(color: tone.ink, size: 18),
            child: DefaultTextStyle.merge(
              style: AppTypography.bodyMd.copyWith(color: tone.ink),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: AppTypography.forText(
                      AppTypography.headlineSm.copyWith(color: tone.ink),
                      title,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2xs),
                  Text(
                    body,
                    style: AppTypography.forText(
                      AppTypography.bodyMd.copyWith(
                        color: tone.ink.withValues(alpha: 0.85),
                      ),
                      body,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  _PopoverButton(
                    key: actionKey,
                    label: actionLabel ?? context.l10n.locked,
                    tone: tone,
                    onPressed: actionLabel == null
                        ? null
                        : () => Navigator.of(context).pop(true),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.spaceXs),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small tappable line at the foot of a [PathPopover] ("Download for
/// offline use"), in the bubble's ink. [busy] swaps the icon for a spinner.
class PathPopoverNote extends StatelessWidget {
  const PathPopoverNote({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ink = IconTheme.of(context).color;
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) AppSpinner.small(color: ink) else Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.spaceXs),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: ink,
                    decoration: onTap == null ? null : TextDecoration.underline,
                    decorationColor: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colours of a bubble for a node in [PathNodeState]: the node's own
/// face, so the bubble reads as coming out of it.
class PathPopoverTone {
  const PathPopoverTone({
    required this.face,
    required this.shelf,
    required this.ink,
    required this.buttonInk,
    this.border,
  });

  factory PathPopoverTone.of(PathNodeState state, AppPalette colors) =>
      switch (state) {
        PathNodeState.active => PathPopoverTone(
          face: colors.secondaryContainer,
          shelf: colors.activeNodeShelf,
          ink: colors.onSecondaryContainer,
          buttonInk: colors.onSecondaryContainer,
        ),
        PathNodeState.completed => PathPopoverTone(
          face: colors.primaryContainer,
          shelf: colors.primaryShelf,
          ink: colors.onPrimary,
          buttonInk: colors.primaryContainer,
        ),
        PathNodeState.locked => PathPopoverTone(
          face: colors.surfaceContainerHigh,
          border: colors.outlineVariant,
          shelf: colors.lockedNodeIcon,
          ink: colors.onSurface,
          buttonInk: colors.onSurfaceVariant,
        ),
      };

  final Color face;
  final Color? border;
  final Color shelf;
  final Color ink;

  /// The text on the bubble's white button.
  final Color buttonInk;
}

/// The bubble's one button: white on the bubble's colour, its text in the
/// bubble's hue (the Duolingo "START" button). Disabled, it greys out.
class _PopoverButton extends StatelessWidget {
  const _PopoverButton({
    super.key,
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final PathPopoverTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppShadows.shelfDepth),
        child: TactilePressable(
          onPressed: onPressed,
          faceColor: enabled ? colors.onPrimary : colors.surfaceDim,
          borderRadius: BorderRadius.circular(AppRadii.full),
          shelfDepth: AppShadows.shelfDepth,
          shadows: (visible) => AppShadows.button(
            enabled ? tone.shelf : colors.lockedNodeIcon,
            visible: visible,
          ),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!enabled) ...[
                  Icon(Icons.lock_outline, size: 18, color: tone.buttonInk),
                  const SizedBox(width: AppSpacing.spaceXs),
                ],
                Text(
                  label,
                  style: AppTypography.labelLg.copyWith(color: tone.buttonInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small triangle pointing at what a bubble belongs to, in the bubble's
/// [color] and, if it has one, edged in [border]. Used under the path's
/// "Start" bubble and on the popover.
class BubbleTail extends StatelessWidget {
  const BubbleTail({
    super.key,
    required this.color,
    this.border,
    this.pointsUp = false,
    this.width = 20,
    this.height = 10,
  });

  final Color color;
  final Color? border;
  final bool pointsUp;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _TailPainter(color: color, border: border, pointsUp: pointsUp),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({
    required this.color,
    required this.border,
    required this.pointsUp,
  });

  final Color color;
  final Color? border;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final base = pointsUp ? size.height : 0.0;
    final tip = pointsUp ? 0.0 : size.height;
    // The base overlaps the bubble by a pixel, so no seam shows.
    final overlap = pointsUp ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(0, base + overlap)
      ..lineTo(size.width / 2, tip)
      ..lineTo(size.width, base + overlap)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final border = this.border;
    if (border != null) {
      canvas.drawPath(
        Path()
          ..moveTo(0, base)
          ..lineTo(size.width / 2, tip)
          ..lineTo(size.width, base),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.color != color || old.border != border || old.pointsUp != pointsUp;
}

/// Places the bubble under (or over) [anchor] with its pointer at the
/// anchor's centre, and grows it out of the pointer.
class _PathPopoverRoute extends PopupRoute<bool> {
  _PathPopoverRoute({
    required this.anchor,
    required this.barrierLabel,
    required this.child,
  });

  final Rect anchor;
  final PathPopover child;

  @override
  final String barrierLabel;

  // No scrim: the path stays in full view, like the Duolingo bubble.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => AppMotion.popover;

  @override
  Duration get reverseTransitionDuration => AppMotion.state;

  /// The gap between the node and the pointer's tip.
  static const double _gap = 4;
  static const double _tailHeight = 12;
  static const double _tailWidth = 24;

  /// Below this much room under the node, the bubble opens above it.
  static const double _roomNeeded = 240;

  _Placement _place(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    const margin = AppSpacing.marginMobile;
    final width = math.min(screen.width - 2 * margin, PathPopover.maxWidth);
    final left = (anchor.center.dx - width / 2)
        .clamp(margin, math.max(margin, screen.width - margin - width))
        .toDouble();
    final below =
        screen.height - media.padding.bottom - anchor.bottom >= _roomNeeded ||
        anchor.top - media.padding.top < _roomNeeded;
    final tailX = (anchor.center.dx - left)
        .clamp(
          AppRadii.base + _tailWidth / 2,
          width - AppRadii.base - _tailWidth / 2,
        )
        .toDouble();
    return _Placement(
      left: left,
      width: width,
      below: below,
      top: anchor.bottom + _gap,
      bottom: screen.height - anchor.top + _gap,
      tailX: tailX,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final place = _place(context);
    final tone = PathPopoverTone.of(child.state, context.colors);
    final tail = Padding(
      padding: EdgeInsets.only(left: place.tailX - _tailWidth / 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: BubbleTail(
          color: tone.face,
          border: tone.border,
          pointsUp: place.below,
          width: _tailWidth,
          height: _tailHeight,
        ),
      ),
    );
    final bubble = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [if (place.below) tail, child, if (!place.below) tail],
    );
    return Stack(
      children: [
        Positioned(
          left: place.left,
          width: place.width,
          top: place.below ? place.top : null,
          bottom: place.below ? null : place.bottom,
          child: _grow(context, animation, place, bubble),
        ),
      ],
    );
  }

  Widget _grow(
    BuildContext context,
    Animation<double> animation,
    _Placement place,
    Widget bubble,
  ) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    if (AppMotion.reduced(context)) {
      return FadeTransition(opacity: fade, child: bubble);
    }
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        alignment: Alignment(
          place.tailX / place.width * 2 - 1,
          place.below ? -1 : 1,
        ),
        scale: Tween<double>(begin: 0.6, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: AppMotion.popoverCurve,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: bubble,
      ),
    );
  }
}

class _Placement {
  const _Placement({
    required this.left,
    required this.width,
    required this.below,
    required this.top,
    required this.bottom,
    required this.tailX,
  });

  final double left;
  final double width;
  final bool below;
  final double top;
  final double bottom;
  final double tailX;
}
