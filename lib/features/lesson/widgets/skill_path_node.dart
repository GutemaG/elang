import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/widgets/path_node.dart';
import '../../../shared/widgets/path_popover.dart';

/// One "Gamified Path Node" (`DESIGN.md` component 2) on the skill-tree
/// dashboard: locked, active (Simien Gold, a bobbing "Start" bubble) or
/// completed (Highland Green, crown-level badge). The path shows no titles;
/// a tap opens [showSkillPopover], which names the skill and starts it.
/// An active skill part-way through its lessons gets a ring filled to how
/// far through it is, and its bubble says "Continue".
///
/// Drawn by the library's [PathNode]; this maps a [SkillTreeNode] onto it.
class SkillPathNode extends StatelessWidget {
  const SkillPathNode({super.key, required this.node, this.onTap});

  final SkillTreeNode node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PathNode(
      state: _pathState(node.state),
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
      callout: node.isPartlyDone ? 'Continue' : 'Start',
      onTap: onTap,
    );
  }

  static String _stateLabel(SkillNodeState state) => switch (state) {
    SkillNodeState.locked => 'locked',
    SkillNodeState.active => 'active, tap to start',
    SkillNodeState.completed => 'completed, tap to review',
  };
}

PathNodeState _pathState(SkillNodeState state) => switch (state) {
  SkillNodeState.locked => PathNodeState.locked,
  SkillNodeState.active => PathNodeState.active,
  SkillNodeState.completed => PathNodeState.completed,
};

/// Opens [node]'s popover under [anchor] (the node's rectangle on screen):
/// its title, where the learner is in it, and one button. Returns `true`
/// when the learner taps Start, Continue or Review; a locked skill only
/// says how to unlock it. A completed skill says up front that a review
/// earns nothing and spends nothing, so nobody finds out at the end.
Future<bool?> showSkillPopover(
  BuildContext context, {
  required SkillTreeNode node,
  required Rect anchor,
  Widget? footer,
}) {
  final lessons = node.lessonCount;
  final (body, action) = switch (node.state) {
    SkillNodeState.locked => (
      'Finish the skills above to unlock this one.',
      null,
    ),
    SkillNodeState.active when node.isPartlyDone => (
      'Lesson ${node.lessonsDone + 1} of $lessons',
      'Continue',
    ),
    SkillNodeState.active => (
      lessons > 1 ? 'Lesson 1 of $lessons' : 'Ready when you are.',
      'Start',
    ),
    SkillNodeState.completed => (
      "You've completed this skill. Reviews don't earn XP or use beans.",
      'Review',
    ),
  };
  return showPathPopover(
    context: context,
    anchor: anchor,
    state: _pathState(node.state),
    title: node.title,
    body: body,
    actionLabel: action,
    footer: footer,
  );
}
