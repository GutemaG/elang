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

/// One lesson of a skill (026-lesson-path-nodes): [done] when it is in the
/// skill's current pass. The path draws a bubble for each.
class SkillLesson {
  const SkillLesson({
    required this.id,
    required this.title,
    required this.done,
  });

  final String id;
  final String title;
  final bool done;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  static SkillLesson fromJson(Map<String, dynamic> json) => SkillLesson(
    id: json['id'] as String,
    title: json['title'] as String,
    done: json['done'] == true,
  );

  /// The `lessons` of a skill-tree entry or a saved copy; empty when there
  /// are none, as from a backend older than 026-lesson-path-nodes.
  static List<SkillLesson> listFrom(Object? raw) => raw is List
      ? [for (final item in raw.cast<Map<String, dynamic>>()) fromJson(item)]
      : const [];
}

/// One skill on the skill-tree dashboard's serpentine path.
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
    this.lessonsDone = 0,
    this.lessonCount = 0,
    this.lessons = const [],
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

  /// How many of this skill's [lessonCount] lessons are done in the current
  /// pass. A skill only becomes [SkillNodeState.completed] once all of them
  /// are, so an unfinished node shows this to make a finished lesson count.
  /// Both are 0 for an older backend that does not send them.
  final int lessonsDone;
  final int lessonCount;

  /// The skill's lessons in order (026-lesson-path-nodes), each a bubble
  /// on the path. Empty from an older backend: the skill is then one
  /// bubble, as before.
  final List<SkillLesson> lessons;

  /// True when the skill is part-way through: at least one lesson done,
  /// but not yet all of them.
  bool get isPartlyDone =>
      state == SkillNodeState.active &&
      lessonCount > 1 &&
      lessonsDone > 0 &&
      lessonsDone < lessonCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'lesson_id': lessonId,
    'title': title,
    'subtitle': subtitle,
    'state': state.name,
    'category_id': categoryId,
    'crown_level': crownLevel,
    'content_version': contentVersion?.toUtc().toIso8601String(),
    'lessons_done': lessonsDone,
    'lesson_count': lessonCount,
    'lessons': [for (final lesson in lessons) lesson.toJson()],
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
    lessonsDone: json['lessons_done'] as int? ?? 0,
    lessonCount: json['lesson_count'] as int? ?? 0,
    lessons: SkillLesson.listFrom(json['lessons']),
  );

  SkillTreeNode copyWith({
    SkillNodeState? state,
    int? crownLevel,
    int? lessonsDone,
    List<SkillLesson>? lessons,
  }) {
    return SkillTreeNode(
      id: id,
      lessonId: lessonId,
      title: title,
      subtitle: subtitle,
      state: state ?? this.state,
      categoryId: categoryId,
      crownLevel: crownLevel ?? this.crownLevel,
      contentVersion: contentVersion,
      lessonsDone: lessonsDone ?? this.lessonsDone,
      lessonCount: lessonCount,
      lessons: lessons ?? this.lessons,
    );
  }
}

/// One bubble on the path (026-lesson-path-nodes): a lesson of [skill], or
/// the whole skill when the tree has no lessons for it (an older backend),
/// drawn as before.
class PathStop {
  const PathStop._({
    required this.skill,
    required this.lessonId,
    required this.title,
    required this.state,
    required this.isLesson,
    required this.isFirstOfSkill,
  });

  /// The whole skill as one bubble, as before lessons had their own.
  factory PathStop.ofSkill(SkillTreeNode skill) => PathStop._(
    skill: skill,
    lessonId: skill.lessonId,
    title: skill.title,
    state: skill.state,
    isLesson: false,
    isFirstOfSkill: true,
  );

  /// One stop per lesson of [skill], or one for the skill when it has
  /// none. A locked skill's lessons are locked and a completed skill's
  /// completed; in an active skill the done ones are completed, the first
  /// not done is active and the ones after it wait for it.
  static List<PathStop> ofLessons(SkillTreeNode skill) {
    final lessons = skill.lessons;
    if (lessons.isEmpty) return [PathStop.ofSkill(skill)];
    final current = lessons.indexWhere((l) => !l.done);
    return [
      for (var i = 0; i < lessons.length; i++)
        PathStop._(
          skill: skill,
          lessonId: lessons[i].id,
          title: lessons[i].title,
          state: switch (skill.state) {
            SkillNodeState.locked => SkillNodeState.locked,
            SkillNodeState.completed => SkillNodeState.completed,
            SkillNodeState.active when lessons[i].done =>
              SkillNodeState.completed,
            SkillNodeState.active when i == current => SkillNodeState.active,
            SkillNodeState.active => SkillNodeState.locked,
          },
          isLesson: true,
          isFirstOfSkill: i == 0,
        ),
    ];
  }

  final SkillTreeNode skill;

  /// The lesson a tap starts.
  final String lessonId;
  final String title;
  final SkillNodeState state;

  /// False for a whole-skill bubble.
  final bool isLesson;

  /// The skill's first bubble, which carries the skill's label.
  final bool isFirstOfSkill;

  /// Unique on the path.
  String get id => isLesson ? '${skill.id}/$lessonId' : skill.id;

  /// Playing it is a review: its skill is already completed, so it earns
  /// and spends nothing.
  bool get isReview => skill.state == SkillNodeState.completed;

  /// A lesson already done in a skill not yet finished: played again, it
  /// counts as before.
  bool get isDoneInUnfinishedSkill =>
      isLesson &&
      state == SkillNodeState.completed &&
      skill.state == SkillNodeState.active;

  /// The ring of a skill part-way through its lessons; only a whole-skill
  /// bubble has one.
  bool get isPartlyDone => !isLesson && skill.isPartlyDone;
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
    this.practisedToday = false,
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

  /// A lesson that counts for the streak was finished on today's UTC date
  /// (021-daily-reminder). Kept in the saved copy, but only trusted fresh
  /// from the server: a saved copy may be from another day.
  final bool practisedToday;

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
    'practised_today': practisedToday,
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
        practisedToday: raw['practised_today'] == true,
      );
    } on Object {
      return null;
    }
  }

  /// The nodes belonging to [category], in path order.
  List<SkillTreeNode> nodesIn(SkillCategory category) =>
      nodes.where((n) => n.categoryId == category.id).toList();

  /// The bubbles of [category]'s path: one per lesson, or one per skill
  /// the tree has no lessons for (026-lesson-path-nodes).
  List<PathStop> stopsIn(SkillCategory category) => [
    for (final node in nodesIn(category)) ...PathStop.ofLessons(node),
  ];
}
