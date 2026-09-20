/// Whether a [Course] can be studied or selected yet.
enum CourseStatus { available, comingSoon }

/// A course (010-multi-language-courses): one language taught from another,
/// e.g. Amharic from English or Afaan Oromo from Amharic.
///
/// The same type serves the public catalog (no per-user fields), the signed-in
/// course list ([isActive], [completedSkills], [totalSkills]) and the `course`
/// object embedded in the skill tree, so absent per-user fields default to
/// "not active, no progress".
class Course {
  const Course({
    required this.id,
    required this.learningLanguage,
    required this.fromLanguage,
    required this.title,
    this.status = CourseStatus.available,
    this.isActive = false,
    this.completedSkills = 0,
    this.totalSkills = 0,
  });

  final String id;

  /// Language code being learned, e.g. `om`.
  final String learningLanguage;

  /// Language code the learner speaks, e.g. `en`.
  final String fromLanguage;
  final String title;
  final CourseStatus status;
  final bool isActive;
  final int completedSkills;
  final int totalSkills;

  bool get isAvailable => status == CourseStatus.available;

  /// The same shape [fromJson] reads, so a course round-trips through the
  /// offline cache.
  Map<String, dynamic> toJson() => {
    'id': id,
    'learning_language': learningLanguage,
    'from_language': fromLanguage,
    'title': title,
    'status': status == CourseStatus.comingSoon ? 'coming_soon' : 'available',
    'is_active': isActive,
    'completed_skills': completedSkills,
    'total_skills': totalSkills,
  };

  Course copyWith({bool? isActive}) => Course(
    id: id,
    learningLanguage: learningLanguage,
    fromLanguage: fromLanguage,
    title: title,
    status: status,
    isActive: isActive ?? this.isActive,
    completedSkills: completedSkills,
    totalSkills: totalSkills,
  );

  /// Parses a backend course object (catalog entry, list entry or the
  /// skill tree's `course`). Returns `null` if a required field is missing
  /// or of the wrong type, so a caller can treat that as a malformed
  /// response rather than crash.
  static Course? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final learning = json['learning_language'];
    final from = json['from_language'];
    final title = json['title'];
    if (id is! String ||
        learning is! String ||
        from is! String ||
        title is! String) {
      return null;
    }
    final rawStatus = json['status'];
    return Course(
      id: id,
      learningLanguage: learning,
      fromLanguage: from,
      title: title,
      status: rawStatus == 'coming_soon'
          ? CourseStatus.comingSoon
          : CourseStatus.available,
      isActive: json['is_active'] == true,
      completedSkills: json['completed_skills'] is int
          ? json['completed_skills'] as int
          : 0,
      totalSkills: json['total_skills'] is int
          ? json['total_skills'] as int
          : 0,
    );
  }
}

/// The signed-in learner's course list plus which one is active.
class CourseList {
  const CourseList({required this.activeCourseId, required this.courses});

  final String activeCourseId;
  final List<Course> courses;

  /// The same list with [courseId] marked active (and only it).
  CourseList withActive(String courseId) => CourseList(
    activeCourseId: courseId,
    courses: [
      for (final c in courses) c.copyWith(isActive: c.id == courseId),
    ],
  );

  Map<String, dynamic> toJson() => {
    'active_course_id': activeCourseId,
    'courses': [for (final c in courses) c.toJson()],
  };

  /// Reads what [toJson] wrote; `null` if it is malformed.
  static CourseList? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final active = raw['active_course_id'];
    final list = raw['courses'];
    if (active is! String || list is! List) return null;
    final courses = <Course>[];
    for (final item in list) {
      final course = item is Map<String, dynamic> ? Course.fromJson(item) : null;
      if (course == null) return null;
      courses.add(course);
    }
    return CourseList(activeCourseId: active, courses: courses);
  }

  Course? get activeCourse {
    for (final course in courses) {
      if (course.id == activeCourseId) return course;
    }
    return null;
  }
}
