import 'course.dart';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'lesson_id': lessonId,
    'title': title,
    'subtitle': subtitle,
    'state': state.name,
    'category_id': categoryId,
    'crown_level': crownLevel,
    'content_version': contentVersion?.toUtc().toIso8601String(),
  };

  static SkillTreeNode fromJson(Map<String, dynamic> json) => SkillTreeNode(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    state: SkillNodeState.values.byName(json['state'] as String),
    categoryId: json['category_id'] as String,
    crownLevel: json['crown_level'] as int,
    contentVersion: json['content_version'] is String
        ? DateTime.tryParse(json['content_version'] as String)
        : null,
  );

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
  };

  static SkillCategory fromJson(Map<String, dynamic> json) => SkillCategory(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
  );
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
    this.course,
  });

  /// The course this tree belongs to -- the learner's active course
  /// (010-multi-language-courses). `null` only for an older backend that
  /// does not send one.
  final Course? course;

  final List<SkillCategory> categories;
  final List<SkillTreeNode> nodes;
  final int streakCount;
  final int beans;
  final int beansMax;
  final int totalXp;

  int get completedCount =>
      nodes.where((n) => n.state == SkillNodeState.completed).length;

  /// A local snapshot for the offline cache (010, story 003); read back by
  /// [fromJson]. Not the backend's response shape.
  Map<String, dynamic> toJson() => {
    'course': course?.toJson(),
    'categories': [for (final c in categories) c.toJson()],
    'nodes': [for (final n in nodes) n.toJson()],
    'streak_count': streakCount,
    'beans': beans,
    'beans_max': beansMax,
    'total_xp': totalXp,
  };

  /// Reads what [toJson] wrote; `null` if it is malformed, so a damaged
  /// cache is ignored rather than crashing the dashboard.
  static SkillTreeResponse? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      final rawCourse = raw['course'];
      return SkillTreeResponse(
        course: rawCourse is Map<String, dynamic>
            ? Course.fromJson(rawCourse)
            : null,
        categories: (raw['categories'] as List)
            .cast<Map<String, dynamic>>()
            .map(SkillCategory.fromJson)
            .toList(),
        nodes: (raw['nodes'] as List)
            .cast<Map<String, dynamic>>()
            .map(SkillTreeNode.fromJson)
            .toList(),
        streakCount: raw['streak_count'] as int,
        beans: raw['beans'] as int,
        beansMax: raw['beans_max'] as int,
        totalXp: raw['total_xp'] as int,
      );
    } on Object {
      return null;
    }
  }

  /// The nodes belonging to [category], in path order.
  List<SkillTreeNode> nodesIn(SkillCategory category) =>
      nodes.where((n) => n.categoryId == category.id).toList();
}
