import '../models/course.dart';
import 'course_api.dart';
import 'course_cache_store.dart';

/// Error code [CachingCourseApi.switchCourse] throws when the device is
/// offline and the target course has never been cached.
const offlineNotCachedErrorCode = 'offline_not_cached';

/// Wraps a [CourseApi] with the offline rules of 010-multi-language-courses
/// (story 003, ADR-14):
///
/// - The course list is cached on every success and served from cache when
///   the network fails.
/// - Offline, a learner may switch only to a course whose skill tree is
///   cached; the choice is kept locally as "pending" and sent to the server
///   by [syncPendingSwitch] on the next successful contact.
/// - A failure that carries a backend `error_code` is a real rejection
///   (e.g. `course_not_available`), never treated as being offline.
class CachingCourseApi implements CourseApi {
  CachingCourseApi({required this._inner, required this._cache});

  final CourseApi _inner;
  final CourseCacheStore _cache;

  @override
  Future<List<Course>> getCatalog() => _inner.getCatalog();

  @override
  Future<CourseList> getCourses() async {
    await syncPendingSwitch();
    try {
      final list = await _inner.getCourses();
      await _cache.saveCourseList(list);
      await _cache.setActiveCourseId(list.activeCourseId);
      return list;
    } on CourseApiException catch (e) {
      if (e.errorCode != null) rethrow;
      final cached = await _cache.loadCourseList();
      if (cached == null) rethrow;
      final active = await _cache.activeCourseId();
      return active == null ? cached : cached.withActive(active);
    }
  }

  @override
  Future<Course> switchCourse(String courseId) async {
    try {
      final course = await _inner.switchCourse(courseId);
      await _cache.setActiveCourseId(courseId);
      return course;
    } on CourseApiException catch (e) {
      if (e.errorCode != null) rethrow;
      final cachedTree = await _cache.loadDashboard(courseId);
      if (cachedTree == null) {
        throw const CourseApiException(
          'This course has not been opened on this device yet',
          errorCode: offlineNotCachedErrorCode,
        );
      }
      await _cache.setActiveCourseId(courseId, pendingSync: true);
      final list = await _cache.loadCourseList();
      final course =
          _find(list, courseId) ??
          cachedTree.tree.course ??
          (throw const CourseApiException('Course unavailable offline'));
      return course.copyWith(isActive: true);
    }
  }

  @override
  Future<void> syncPendingSwitch() async {
    final pending = await _cache.pendingSwitchCourseId();
    if (pending == null) return;
    try {
      await _inner.switchCourse(pending);
      await _cache.clearPendingSwitch();
    } on CourseApiException catch (e) {
      // Still offline: keep it pending. A rejection from the server means
      // the offline choice can no longer be honoured, so drop it and let the
      // server's active course win.
      if (e.errorCode != null) await _cache.clearPendingSwitch();
    }
  }

  static Course? _find(CourseList? list, String id) {
    if (list == null) return null;
    for (final course in list.courses) {
      if (course.id == id) return course;
    }
    return null;
  }
}
