import '../models/course.dart';
import 'course_api.dart';

/// In-memory [CourseApi] for tests (and for running the app without a
/// backend). Holds the course list and the active course; [failWith] makes
/// every call throw, and [switchFailure] makes only [switchCourse] throw.
class FakeCourseApi implements CourseApi {
  FakeCourseApi({List<Course>? courses, String? activeCourseId})
    : _courses = courses ?? defaultCourses,
      _activeCourseId = activeCourseId ?? (courses ?? defaultCourses).first.id;

  /// English to Amharic, English to Afaan Oromo, Amharic to Afaan Oromo, and
  /// Afaan Oromo to Amharic (coming soon), mirroring a plausible catalog.
  static const List<Course> defaultCourses = [
    Course(
      id: 'c-en-am',
      learningLanguage: 'am',
      fromLanguage: 'en',
      title: 'English to Amharic',
      completedSkills: 3,
      totalSkills: 10,
    ),
    Course(
      id: 'c-en-om',
      learningLanguage: 'om',
      fromLanguage: 'en',
      title: 'English to Afaan Oromo',
      totalSkills: 2,
    ),
    Course(
      id: 'c-am-om',
      learningLanguage: 'om',
      fromLanguage: 'am',
      title: 'Amharic to Afaan Oromo',
      totalSkills: 2,
    ),
    Course(
      id: 'c-om-am',
      learningLanguage: 'am',
      fromLanguage: 'om',
      title: 'Afaan Oromo to Amharic',
      status: CourseStatus.comingSoon,
    ),
  ];

  final List<Course> _courses;
  String _activeCourseId;

  /// When set, every call throws it.
  CourseApiException? failWith;

  /// When set, only [switchCourse] throws it.
  CourseApiException? switchFailure;

  int catalogCalls = 0;
  int courseListCalls = 0;
  final List<String> switchCalls = [];

  String get activeCourseId => _activeCourseId;

  @override
  Future<List<Course>> getCatalog() async {
    catalogCalls++;
    _maybeFail();
    return _courses
        .map(
          (c) => Course(
            id: c.id,
            learningLanguage: c.learningLanguage,
            fromLanguage: c.fromLanguage,
            title: c.title,
            status: c.status,
          ),
        )
        .toList();
  }

  @override
  Future<CourseList> getCourses() async {
    courseListCalls++;
    _maybeFail();
    return CourseList(
      activeCourseId: _activeCourseId,
      courses: _courses
          .map(
            (c) => Course(
              id: c.id,
              learningLanguage: c.learningLanguage,
              fromLanguage: c.fromLanguage,
              title: c.title,
              status: c.status,
              isActive: c.id == _activeCourseId,
              completedSkills: c.completedSkills,
              totalSkills: c.totalSkills,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<Course> switchCourse(String courseId) async {
    switchCalls.add(courseId);
    _maybeFail();
    final failure = switchFailure;
    if (failure != null) throw failure;
    final course = _courses.where((c) => c.id == courseId).firstOrNull;
    if (course == null) {
      throw const CourseApiException(
        'No course found',
        errorCode: 'course_not_found',
      );
    }
    if (!course.isAvailable) {
      throw const CourseApiException(
        'Course is not available yet',
        errorCode: 'course_not_available',
      );
    }
    _activeCourseId = courseId;
    return course.copyWith(isActive: true);
  }

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }
}
