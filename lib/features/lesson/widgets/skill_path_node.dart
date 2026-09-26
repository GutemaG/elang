import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/widgets/path_node.dart';

/// One "Gamified Path Node" (`DESIGN.md` component 2) on the skill-tree
/// dashboard: locked (rigid, non-interactive), active (Simien Gold,
/// tappable, starts a lesson), or completed (Highland Green, crown-level
/// badge, tappable to replay). An active skill that is part-way through
/// its lessons gets a ring filled to how far through it is, and its label
/// reads e.g. "Numbers · 1/2", so a finished lesson visibly counts even
/// though the skill is not done yet.
///
/// Drawn by the library's [PathNode] (018-mobile-design-system, bolt 047);
/// this maps a [SkillTreeNode] onto it.
class SkillPathNode extends StatelessWidget {
  const SkillPathNode({super.key, required this.node, this.onTap});

  final SkillTreeNode node;

  /// Null for locked nodes — the caller shouldn't wire a tap handler for
  /// them, but this widget also refuses to invoke it even if one sneaks
  /// through, so "locked nodes aren't tappable" holds regardless of the
  /// caller.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PathNode(
      state: switch (node.state) {
        SkillNodeState.locked => PathNodeState.locked,
        SkillNodeState.active => PathNodeState.active,
        SkillNodeState.completed => PathNodeState.completed,
      },
      label: node.isPartlyDone
          ? '${node.title} · ${node.lessonsDone}/${node.lessonCount}'
          : node.title,
      semanticLabel: [
        node.title,
        _stateLabel(node.state),
        if (node.isPartlyDone)
          '${node.lessonsDone} of ${node.lessonCount} lessons done',
      ].join(', '),
      progress: node.isPartlyDone
          ? (node.lessonCount == 0 ? 0 : node.lessonsDone / node.lessonCount)
          : null,
      crownLevel: node.crownLevel,
      onTap: onTap,
    );
  }

  static String _stateLabel(SkillNodeState state) => switch (state) {
    SkillNodeState.locked => 'locked',
    SkillNodeState.active => 'active, tap to start',
    SkillNodeState.completed => 'completed, tap to replay',
  };
}
