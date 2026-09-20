import '../models/course.dart';

/// Thrown by a [CourseApi] on any backend/network failure. Same shape as
/// `LessonApiException`: one type, with the backend's `error_code` when the
/// failure was a parsed error response (e.g. `course_not_available`).
class CourseApiException implements Exception {
  const CourseApiException(this.message, {this.errorCode});

  final String message;
  final String? errorCode;

  @override
  String toString() => 'CourseApiException($errorCode: $message)';
}

/// The `010-multi-language-courses` boundary this UI needs: the public
/// catalog (onboarding, before sign-in), the signed-in course list, and
/// switching the active course.
abstract class CourseApi {
  /// Every course, available and coming soon, without a login -- so
  /// onboarding can offer the language pair. Throws [CourseApiException].
  Future<List<Course>> getCatalog();

  /// The signed-in learner's courses, with the active one marked and
  /// per-course skill progress. Throws [CourseApiException].
  Future<CourseList> getCourses();

  /// Makes [courseId] the learner's active course and returns it. Throws
  /// [CourseApiException] (e.g. `course_not_available`,
  /// `course_not_found`); the active course is unchanged on failure.
  Future<Course> switchCourse(String courseId);
}
