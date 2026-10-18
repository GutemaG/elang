import '../../shared/models/course.dart';
import '../../shared/services/course_cache_store.dart';

/// Which courses belong on the dashboard's rail (011-dashboard-ui-polish,
/// ADR-15).
///
/// The backend has no notion of "courses I have joined" -- `GET /courses`
/// returns the whole catalog -- so membership is derived here: a course is on
/// the rail if the learner has opened it (it has a saved dashboard, written
/// after every successful load), if it is active, or if it reports progress.
/// The active course is always first, and always present even on a device
/// whose cache is empty.
///
/// Coming-soon courses are never on the rail; they live in the catalog behind
/// "+ Course".
Future<List<Course>> railCoursesFor(
  CourseList list, {
  CourseCacheStore? cache,
}) async {
  final opened = <String>{};
  if (cache != null) {
    try {
      opened.addAll(await cache.cachedCourseIds());
    } on Object {
      // A rail from the server alone beats no rail at all.
    }
  }

  // Built in two passes rather than sorted: `List.sort` is not stable, and
  // the catalog's order is meaningful for everything after the active course.
  final active = <Course>[];
  final rest = <Course>[];
  for (final course in list.courses) {
    if (!course.isAvailable) continue;
    final isActive = course.id == list.activeCourseId;
    if (!isActive &&
        !opened.contains(course.id) &&
        course.completedSkills == 0) {
      continue;
    }
    (isActive ? active : rest).add(course);
  }
  return [...active, ...rest];
}
