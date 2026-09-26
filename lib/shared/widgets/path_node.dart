import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
                    color: _face,
                    border: Border.all(
                      color: locked
                          ? AppColors.outline
                          : AppColors.outlineVariant,
                      width: active ? 4 : 2,
                    ),
                    boxShadow: [AppShadows.shelf(_shelf, depth: shelfDepth)],
                  ),
                  child: Icon(
                    _icon,
                    color: _foreground,
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
                      ? AppColors.surfaceContainer
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: locked
                        ? AppColors.onSurfaceVariant
                        : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _face => switch (state) {
    PathNodeState.locked => AppColors.surfaceDim,
    PathNodeState.active => AppColors.secondaryContainer,
    PathNodeState.completed => AppColors.primaryContainer,
  };

  Color get _foreground => switch (state) {
    PathNodeState.locked => AppColors.outlineVariant,
    PathNodeState.active => AppColors.onSecondary,
    PathNodeState.completed => AppColors.onPrimary,
  };

  Color get _shelf => switch (state) {
    PathNodeState.locked => AppColors.lockedNodeIcon,
    PathNodeState.active => AppColors.activeNodeShelf,
    PathNodeState.completed => AppColors.primaryBevel,
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
      painter: _RingPainter(fraction: fraction.clamp(0, 1).toDouble()),
      child: Padding(
        padding: const EdgeInsets.all(_gap + _stroke),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = _ProgressRing._stroke;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (math.min(size.width, size.height) - stroke) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.surfaceContainer;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryContainer;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

class _CrownBadge extends StatelessWidget {
  const _CrownBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.secondaryContainer),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium,
            size: 12,
            color: AppColors.secondaryContainer,
          ),
          const SizedBox(width: 2),
          Text(
            'Lv $level',
            style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
