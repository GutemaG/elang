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
    required this.categoryId,
    this.crownLevel = 0,
    this.contentVersion,
  });

  final String id;
  final String lessonId;
  final String title;
  final String subtitle;
  final SkillNodeState state;

  /// The [SkillCategory] this skill belongs to (009-course-categories).
  final String categoryId;

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
      categoryId: categoryId,
      crownLevel: crownLevel ?? this.crownLevel,
      contentVersion: contentVersion,
    );
  }
}

/// A course category (009-course-categories): a banner on the dashboard
/// owning its own skill path.
class SkillCategory {
  const SkillCategory({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

/// The full skill-tree dashboard payload: the course categories in display
/// order, every skill node (flat, in path order), and the HUD stats
/// (streak/beans/XP) shown at the top of the dashboard.
class SkillTreeResponse {
  const SkillTreeResponse({
    required this.categories,
    required this.nodes,
    required this.streakCount,
    required this.beans,
    required this.beansMax,
    required this.totalXp,
  });

  final List<SkillCategory> categories;
  final List<SkillTreeNode> nodes;
  final int streakCount;
  final int beans;
  final int beansMax;
  final int totalXp;

  int get completedCount =>
      nodes.where((n) => n.state == SkillNodeState.completed).length;

  /// The nodes belonging to [category], in path order.
  List<SkillTreeNode> nodesIn(SkillCategory category) =>
      nodes.where((n) => n.categoryId == category.id).toList();
}
