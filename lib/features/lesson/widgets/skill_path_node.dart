import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// One "Gamified Path Node" (`DESIGN.md` component 2) on the skill-tree
/// dashboard: locked (rigid, non-interactive), active (Simien Gold,
/// tappable, starts a lesson), or completed (Highland Green, crown-level
/// badge, tappable to replay). An active skill that is part-way through
/// its lessons gets a ring filled to how far through it is, and its label
/// reads e.g. "Numbers · 1/2", so a finished lesson visibly counts even
/// though the skill is not done yet.
class SkillPathNode extends StatelessWidget {
  const SkillPathNode({super.key, required this.node, this.onTap});

  final SkillTreeNode node;

  /// Null for locked nodes — the caller shouldn't wire a tap handler for
  /// them, but this widget also refuses to invoke it even if one sneaks
  /// through, so "locked nodes aren't tappable" holds regardless of the
  /// caller.
  final VoidCallback? onTap;

  bool get _tappable => node.state != SkillNodeState.locked;

  @override
  Widget build(BuildContext context) {
    // The whole node — icon circle *and* its title label — is one tap
    // target, not just the circle, so the larger, more forgiving hit area
    // matches what a learner expects to be able to tap.
    return Semantics(
      button: true,
      enabled: _tappable,
      label: [
        node.title,
        _stateLabel(node.state),
        if (node.isPartlyDone)
          '${node.lessonsDone} of ${node.lessonCount} lessons done',
      ].join(', '),
      child: InkWell(
        onTap: _tappable ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space2xs),
          child: Column(
            children: [
              if (node.state == SkillNodeState.completed && node.crownLevel > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _CrownBadge(level: node.crownLevel),
                ),
              _ProgressRing(
                show: node.isPartlyDone,
                fraction: node.lessonCount == 0
                    ? 0
                    : node.lessonsDone / node.lessonCount,
                child: Container(
                  width: node.state == SkillNodeState.active ? 80 : 64,
                  height: node.state == SkillNodeState.active ? 80 : 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _backgroundColor(node.state),
                    border: Border.all(
                      color: node.state == SkillNodeState.locked
                          ? AppColors.outline
                          : AppColors.outlineVariant,
                      width: node.state == SkillNodeState.active ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _bevelColor(node.state),
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _icon(node.state),
                    color: _foregroundColor(node.state),
                    size: node.state == SkillNodeState.active ? 34 : 28,
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
                  color: node.state == SkillNodeState.locked
                      ? AppColors.surfaceContainer
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(
                  node.isPartlyDone
                      ? '${node.title} · ${node.lessonsDone}/${node.lessonCount}'
                      : node.title,
                  style: AppTypography.labelMd.copyWith(
                    color: node.state == SkillNodeState.locked
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

  static String _stateLabel(SkillNodeState state) => switch (state) {
    SkillNodeState.locked => 'locked',
    SkillNodeState.active => 'active, tap to start',
    SkillNodeState.completed => 'completed, tap to replay',
  };

  static Color _backgroundColor(SkillNodeState state) => switch (state) {
    SkillNodeState.locked => AppColors.surfaceDim,
    SkillNodeState.active => AppColors.secondaryContainer,
    SkillNodeState.completed => AppColors.primaryContainer,
  };

  static Color _foregroundColor(SkillNodeState state) => switch (state) {
    SkillNodeState.locked => AppColors.outlineVariant,
    SkillNodeState.active => AppColors.onSecondary,
    SkillNodeState.completed => AppColors.onPrimary,
  };

  static Color _bevelColor(SkillNodeState state) => switch (state) {
    SkillNodeState.locked => const Color(0xFFBAAFA1),
    SkillNodeState.active => const Color(0xFFC47318),
    SkillNodeState.completed => AppColors.primaryBevel,
  };

  static IconData _icon(SkillNodeState state) => switch (state) {
    SkillNodeState.locked => Icons.lock_outline,
    SkillNodeState.active => Icons.play_arrow,
    SkillNodeState.completed => Icons.check,
  };
}

/// A ring around a node's circle, filled clockwise from the top to
/// [fraction]. With [show] false it lays out as the bare [child], so nodes
/// without partial progress keep their exact size and position.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.show,
    required this.fraction,
    required this.child,
  });

  final bool show;
  final double fraction;
  final Widget child;

  static const double _gap = 5;
  static const double _stroke = 5;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return CustomPaint(
      key: const ValueKey('skill-progress-ring'),
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
