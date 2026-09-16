/// A single skill node's progress state on the skill-tree dashboard.
enum SkillNodeState {
  /// Not yet reachable — the prior skill hasn't been fully completed.
  locked,

  /// The next skill to learn — tappable, starts a lesson.
  active,

  /// Fully completed at least once — tappable (replay, raises crown level),
  /// shows a crown-level badge (1-5).
  completed,
}

/// One node on the skill-tree dashboard's serpentine path.
///
/// [lessonId] is the lesson started when an active/completed node is
/// tapped. For this bolt's fake curriculum there is one representative
/// lesson per node; a real curriculum (`001-lesson-service`) may have many
/// lessons per skill, which is a detail `FakeLessonApi`'s contract doesn't
/// need to model for the UI to be built and tested.
class SkillTreeNode {
  const SkillTreeNode({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.subtitle,
    required this.state,
    this.crownLevel = 0,
    this.contentVersion,
  });

  final String id;
  final String lessonId;
  final String title;
  final String subtitle;
  final SkillNodeState state;

  /// 0 when never completed; 1-5 once completed (see FR-6's crown-level cap).
  final int crownLevel;

  /// Offline-caching staleness signal (009-offline-caching-and-sync-ui,
  /// FR-1) -- the most recent content edit across this skill's lessons/
  /// exercises. `null` for a fake/older API implementation that doesn't
  /// supply one; a `null` value simply means "no staleness comparison
  /// possible yet", never a crash.
  final DateTime? contentVersion;

  SkillTreeNode copyWith({SkillNodeState? state, int? crownLevel}) {
    return SkillTreeNode(
      id: id,
      lessonId: lessonId,
      title: title,
      subtitle: subtitle,
      state: state ?? this.state,
      crownLevel: crownLevel ?? this.crownLevel,
      contentVersion: contentVersion,
    );
  }
}

/// The full skill-tree dashboard payload: the current unit banner, its
/// nodes in path order, and the HUD stats (streak/beans/XP) shown at the
/// top of the dashboard.
class SkillTreeResponse {
  const SkillTreeResponse({
    required this.unitTitle,
    required this.unitSubtitle,
    required this.nodes,
    required this.streakCount,
    required this.beans,
    required this.beansMax,
    required this.totalXp,
  });

  final String unitTitle;
  final String unitSubtitle;
  final List<SkillTreeNode> nodes;
  final int streakCount;
  final int beans;
  final int beansMax;
  final int totalXp;

  int get completedCount =>
      nodes.where((n) => n.state == SkillNodeState.completed).length;
}
