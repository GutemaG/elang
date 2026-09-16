import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';

/// One "Gamified Path Node" (`DESIGN.md` component 2) on the skill-tree
/// dashboard: locked (rigid, non-interactive), active (Simien Gold,
/// tappable, starts a lesson), or completed (Highland Green, crown-level
/// badge, tappable to replay).
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
      label: '${node.title}, ${_stateLabel(node.state)}',
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
              Container(
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
                  node.title,
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
