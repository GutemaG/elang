import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/widgets/path_node.dart';
import '../../../shared/widgets/path_popover.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/app_language.dart';

/// One "Gamified Path Node" (`DESIGN.md` component 2) on the skill-tree
/// dashboard: locked, active (secondary ocean blue, a bobbing "Start" bubble) or
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
    final l = context.l10n;
    return PathNode(
      state: _pathState(node.state),
      semanticLabel: [
        node.title,
        _stateLabel(node.state, l),
        if (node.isPartlyDone)
          l.lessonsDoneOfCount(node.lessonsDone, node.lessonCount),
      ].join(', '),
      progress: node.isPartlyDone
          ? (node.lessonCount == 0 ? 0 : node.lessonsDone / node.lessonCount)
          : null,
      crownLevel: node.crownLevel,
      callout: node.isPartlyDone ? l.continueButton : l.start,
      onTap: onTap,
    );
  }

  static String _stateLabel(SkillNodeState state, AppLocalizations l) =>
      switch (state) {
        SkillNodeState.locked => l.nodeLocked,
        SkillNodeState.active => l.nodeActive,
        SkillNodeState.completed => l.nodeCompleted,
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
  final l = context.l10n;
  final lessons = node.lessonCount;
  final (body, action) = switch (node.state) {
    SkillNodeState.locked => (l.finishSkillsAbove, null),
    SkillNodeState.active when node.isPartlyDone => (
      l.lessonNofM(node.lessonsDone + 1, lessons),
      l.continueButton,
    ),
    SkillNodeState.active => (
      lessons > 1 ? l.lessonNofM(1, lessons) : l.readyWhenYouAre,
      l.start,
    ),
    SkillNodeState.completed => (l.skillCompletedNote, l.review),
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
