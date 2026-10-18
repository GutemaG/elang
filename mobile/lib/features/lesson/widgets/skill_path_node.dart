import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/path_node.dart';
import '../../../shared/widgets/path_popover.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/app_language.dart';

/// One "Gamified Path Node" (`DESIGN.md` component 2) on the skill-tree
/// dashboard: locked, active (secondary ocean blue, a bobbing "Start" bubble) or
/// completed (Highland Green, crown-level badge). The path shows no titles;
/// a tap opens [showStopPopover], which names the lesson and starts it.
///
/// A bubble is one lesson (026-lesson-path-nodes), or a whole skill when
/// the tree has no lessons for it. Only a whole skill part-way through its
/// lessons gets a ring filled to how far through it is, and its bubble
/// says "Continue".
///
/// Drawn by the library's [PathNode]; this maps a [PathStop] onto it.
class SkillPathNode extends StatelessWidget {
  const SkillPathNode({super.key, required this.stop, this.onTap});

  final PathStop stop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final skill = stop.skill;
    return PathNode(
      state: _pathState(stop.state),
      semanticLabel: [
        stop.title,
        if (stop.isLesson) l.inSkill(skill.title),
        _stateLabel(stop.state, l),
        if (stop.isPartlyDone)
          l.lessonsDoneOfCount(skill.lessonsDone, skill.lessonCount),
      ].join(', '),
      progress: stop.isPartlyDone
          ? (skill.lessonCount == 0 ? 0 : skill.lessonsDone / skill.lessonCount)
          : null,
      // A skill's crown sits on its label when its lessons are bubbles.
      crownLevel: stop.isLesson ? 0 : skill.crownLevel,
      callout: stop.isPartlyDone ? l.continueButton : l.start,
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

/// A skill's title above its first lesson bubble (026-lesson-path-nodes),
/// read as a heading, with its crown level once it is completed.
class PathSkillLabel extends StatelessWidget {
  const PathSkillLabel({super.key, required this.skill});

  final SkillTreeNode skill;

  @override
  Widget build(BuildContext context) {
    final crowned =
        skill.state == SkillNodeState.completed && skill.crownLevel > 0;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.spaceSm),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.spaceXs,
          runSpacing: AppSpacing.space2xs,
          children: [
            Text(
              skill.title,
              textAlign: TextAlign.center,
              style: AppTypography.forText(
                AppTypography.labelLg.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                skill.title,
              ),
            ),
            if (crowned) PathCrownBadge(level: skill.crownLevel),
          ],
        ),
      ),
    );
  }
}

PathNodeState _pathState(SkillNodeState state) => switch (state) {
  SkillNodeState.locked => PathNodeState.locked,
  SkillNodeState.active => PathNodeState.active,
  SkillNodeState.completed => PathNodeState.completed,
};

/// Opens [stop]'s popover under [anchor] (the bubble's rectangle on
/// screen): its title, a line on where the learner is, and one button.
/// Returns `true` when the learner taps the button. A locked bubble only
/// says how to unlock it; a completed skill's says up front that a review
/// earns nothing and spends nothing, so nobody finds out at the end.
Future<bool?> showStopPopover(
  BuildContext context, {
  required PathStop stop,
  required Rect anchor,
  Widget? footer,
}) {
  if (!stop.isLesson) {
    return showSkillPopover(
      context,
      node: stop.skill,
      anchor: anchor,
      footer: footer,
    );
  }
  final l = context.l10n;
  final (body, action) = switch (stop.state) {
    SkillNodeState.locked when stop.skill.state == SkillNodeState.locked => (
      l.finishSkillsAbove,
      null,
    ),
    SkillNodeState.locked => (l.finishLessonAbove, null),
    SkillNodeState.active => (l.readyWhenYouAre, l.start),
    SkillNodeState.completed when stop.isReview => (
      l.skillCompletedNote,
      l.review,
    ),
    SkillNodeState.completed => (l.lessonDonePlayAgain, l.start),
  };
  return showPathPopover(
    context: context,
    anchor: anchor,
    state: _pathState(stop.state),
    title: stop.title,
    body: body,
    actionLabel: action,
    footer: footer,
  );
}

/// The popover of a whole-skill bubble, from a tree without lessons: its
/// title, where the learner is in it, and one button.
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
