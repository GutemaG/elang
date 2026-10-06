import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme_context.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'path_popover.dart';
import '../l10n/app_language.dart';

/// Where a skill stands on the path.
enum PathNodeState {
  /// Not reachable yet: grey and a lock. A tap only says what it is.
  locked,

  /// The next thing to learn: large, the secondary ocean blue, a star.
  active,

  /// Done: Highland Green with a check, tapped to review.
  completed,
}

/// DESIGN.md component 2, "Gamified Path Node", drawn the way the Duolingo
/// path draws it: a round node on a solid shelf and nothing else, no title
/// under it. A tap opens the node's popover ([showPathPopover]), which is
/// where the skill is named.
///
/// The learner's current node is larger, wears a [callout] bubble ("Start")
/// that bobs above it and a soft pulse around it, so it is the first thing
/// the eye finds on the path. Under reduced motion both stay still.
///
/// A [progress] draws a ring around the node, filled clockwise from the top,
/// for a skill part-way through its lessons. A completed node with a
/// [crownLevel] wears a small "Lv N" badge above it. The node is one tap target and one phrase for a
/// screen reader ([semanticLabel]); every state takes a tap, even locked,
/// so a learner can see what is coming.
class PathNode extends StatefulWidget {
  const PathNode({
    super.key,
    required this.state,
    required this.semanticLabel,
    this.progress,
    this.crownLevel = 0,
    this.callout,
    this.onTap,
  });

  final PathNodeState state;
  final String semanticLabel;

  /// From 0 to 1; `null` for no ring.
  final double? progress;
  final int crownLevel;

  /// The bubble over an active node, e.g. "Start"; ignored otherwise.
  final String? callout;

  final VoidCallback? onTap;

  static const double activeSize = 80;
  static const double size = 64;

  /// The node's shelf.
  static const double shelfDepth = 6;

  /// Finds the ring in tests.
  static const Key progressRingKey = ValueKey('skill-progress-ring');

  /// Finds the "Start" bubble and the pulse in tests.
  static const Key calloutKey = ValueKey('path-node-callout');
  static const Key pulseKey = ValueKey('path-node-pulse');

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: AppMotion.bob * 2,
  );

  bool get _active => widget.state == PathNodeState.active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(covariant PathNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoop();
  }

  void _syncLoop() {
    final run = _active && AppMotion.loops(context);
    if (run && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!run && _loop.isAnimating) {
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final active = _active;
    final diameter = active ? PathNode.activeSize : PathNode.size;
    final locked = state == PathNodeState.locked;
    final callout = widget.callout;

    final circle = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _face(context.colors),
        border: Border.all(
          color: locked
              ? context.colors.outline
              : context.colors.outlineVariant,
          width: active ? 4 : 2,
        ),
        boxShadow: [
          AppShadows.shelf(_shelf(context.colors), depth: PathNode.shelfDepth),
        ],
      ),
      child: Icon(
        _icon,
        color: _foreground(context.colors),
        size: active ? 40 : 30,
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space2xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == PathNodeState.completed && widget.crownLevel > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space2xs),
                  child: PathCrownBadge(level: widget.crownLevel),
                ),
              if (active && callout != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spaceXs),
                  child: _Callout(
                    key: PathNode.calloutKey,
                    label: callout,
                    loop: _loop,
                  ),
                ),
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (active && AppMotion.loops(context))
                    Positioned.fill(
                      key: PathNode.pulseKey,
                      child: _Pulse(
                        loop: _loop,
                        color: context.colors.secondaryContainer,
                      ),
                    ),
                  _ProgressRing(fraction: widget.progress, child: circle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _face(AppPalette colors) => switch (widget.state) {
    PathNodeState.locked => colors.surfaceDim,
    PathNodeState.active => colors.secondaryContainer,
    PathNodeState.completed => colors.primaryContainer,
  };

  Color _foreground(AppPalette colors) => switch (widget.state) {
    PathNodeState.locked => colors.outlineVariant,
    PathNodeState.active => colors.onSecondary,
    PathNodeState.completed => colors.onPrimary,
  };

  Color _shelf(AppPalette colors) => switch (widget.state) {
    PathNodeState.locked => colors.lockedNodeIcon,
    PathNodeState.active => colors.activeNodeShelf,
    PathNodeState.completed => colors.primaryShelf,
  };

  IconData get _icon => switch (widget.state) {
    PathNodeState.locked => Icons.lock_outline,
    PathNodeState.active => Icons.star_rounded,
    PathNodeState.completed => Icons.check_rounded,
  };
}

/// The "Start" bubble over the current node: white, edged in the node's
/// gold, pointing down at it and bobbing gently with [loop].
class _Callout extends StatelessWidget {
  const _Callout({super.key, required this.label, required this.loop});

  final String label;
  final Animation<double> loop;

  /// How far the bubble rises at the top of a bob.
  static const double _rise = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bubble = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceSm,
            vertical: AppSpacing.space2xs + 2,
          ),
          // Green with white letters: a white bubble barely stood out from
          // the cream page, and gold would melt into the gold node below.
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: colors.primaryShelf, width: 2),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.labelLg.copyWith(
              color: colors.onPrimary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        BubbleTail(
          color: colors.primaryContainer,
          border: colors.primaryShelf,
          width: 16,
          height: 8,
        ),
      ],
    );
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) => Transform.translate(
        // Up and back down once per loop, easing at both ends.
        offset: Offset(
          0,
          -_rise * (1 - math.cos(2 * math.pi * loop.value)) / 2,
        ),
        child: child,
      ),
      child: bubble,
    );
  }
}

/// A disc of the node's colour that grows out from behind it and fades,
/// once per [loop].
class _Pulse extends StatelessWidget {
  const _Pulse({required this.loop, required this.color});

  final Animation<double> loop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) {
          final t = Curves.easeOut.transform(loop.value);
          return Transform.scale(
            scale: 1 + 0.45 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.4 * (1 - t)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A ring around a node's circle, filled clockwise from the top to
/// [fraction]. With no [fraction] it lays out as the bare [child], so nodes
/// without partial progress keep their exact size and position.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.fraction, required this.child});

  final double? fraction;
  final Widget child;

  static const double _gap = 5;
  static const double _stroke = 5;

  @override
  Widget build(BuildContext context) {
    final fraction = this.fraction;
    if (fraction == null) return child;
    return CustomPaint(
      key: PathNode.progressRingKey,
      painter: _RingPainter(
        fraction: fraction.clamp(0, 1).toDouble(),
        track: context.colors.surfaceContainer,
        fill: context.colors.primaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.all(_gap + _stroke),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = _ProgressRing._stroke;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (math.min(size.width, size.height) - stroke) / 2,
    );
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.fill != fill;
}

/// The "Lv N" crown badge over a completed node, and beside a skill's
/// label when its lessons are bubbles of their own (026-lesson-path-nodes).
class PathCrownBadge extends StatelessWidget {
  const PathCrownBadge({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: context.colors.secondaryContainer),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: 12,
            color: context.colors.secondaryContainer,
          ),
          const SizedBox(width: 2),
          Text(
            context.l10n.levelShort(level),
            style: AppTypography.labelSm.copyWith(
              color: context.colors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
