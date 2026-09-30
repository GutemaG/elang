import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme_context.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Where a skill stands on the path.
enum PathNodeState {
  /// Not reachable yet: grey, a lock, and no tap.
  locked,

  /// The next thing to learn: large, Simien Gold, a play mark.
  active,

  /// Done: Highland Green with a check, tapped to review.
  completed,
}

/// DESIGN.md component 2, "Gamified Path Node", as the dashboard mockup
/// draws it (018-mobile-design-system, bolt 047): a round node on a solid
/// shelf, with its label in a pill underneath.
///
/// A [progress] draws a ring around the node, filled clockwise from the top,
/// for a skill part-way through its lessons. A completed node with a
/// [crownLevel] wears a small "Lv N" badge above it. The node and its label
/// are one tap target and one phrase for a screen reader ([semanticLabel]).
class PathNode extends StatelessWidget {
  const PathNode({
    super.key,
    required this.state,
    required this.label,
    required this.semanticLabel,
    this.progress,
    this.crownLevel = 0,
    this.onTap,
  });

  final PathNodeState state;

  /// What the pill says, e.g. "Numbers · 1/2".
  final String label;
  final String semanticLabel;

  /// From 0 to 1; `null` for no ring.
  final double? progress;
  final int crownLevel;

  /// Ignored for a locked node, which never takes a tap.
  final VoidCallback? onTap;

  static const double activeSize = 80;
  static const double size = 64;

  /// The node's shelf.
  static const double shelfDepth = 6;

  /// Finds the ring in tests.
  static const Key progressRingKey = ValueKey('skill-progress-ring');

  bool get _tappable => state != PathNodeState.locked;

  @override
  Widget build(BuildContext context) {
    final active = state == PathNodeState.active;
    final diameter = active ? activeSize : size;
    final locked = state == PathNodeState.locked;
    // One phrase: the label pill's text is already in [semanticLabel], so
    // it is not read a second time.
    return Semantics(
      button: true,
      enabled: _tappable,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: _tappable ? onTap : null,
      child: InkWell(
        onTap: _tappable ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space2xs),
          child: Column(
            children: [
              if (state == PathNodeState.completed && crownLevel > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space2xs),
                  child: _CrownBadge(level: crownLevel),
                ),
              _ProgressRing(
                fraction: progress,
                child: Container(
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
                      AppShadows.shelf(
                        _shelf(context.colors),
                        depth: shelfDepth,
                      ),
                    ],
                  ),
                  child: Icon(
                    _icon,
                    color: _foreground(context.colors),
                    size: active ? 34 : 28,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space2xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceXs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: locked
                      ? context.colors.surfaceContainer
                      : context.colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: context.colors.outlineVariant),
                ),
                child: Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: locked
                        ? context.colors.onSurfaceVariant
                        : context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _face(AppPalette colors) => switch (state) {
    PathNodeState.locked => colors.surfaceDim,
    PathNodeState.active => colors.secondaryContainer,
    PathNodeState.completed => colors.primaryContainer,
  };

  Color _foreground(AppPalette colors) => switch (state) {
    PathNodeState.locked => colors.outlineVariant,
    PathNodeState.active => colors.onSecondary,
    PathNodeState.completed => colors.onPrimary,
  };

  Color _shelf(AppPalette colors) => switch (state) {
    PathNodeState.locked => colors.lockedNodeIcon,
    PathNodeState.active => colors.activeNodeShelf,
    PathNodeState.completed => colors.primaryShelf,
  };

  IconData get _icon => switch (state) {
    PathNodeState.locked => Icons.lock_outline,
    PathNodeState.active => Icons.play_arrow,
    PathNodeState.completed => Icons.check,
  };
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

class _CrownBadge extends StatelessWidget {
  const _CrownBadge({required this.level});

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
            'Lv $level',
            style: AppTypography.labelSm.copyWith(
              color: context.colors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
