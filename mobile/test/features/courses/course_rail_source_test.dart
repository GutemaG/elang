// Course rail membership (011-dashboard-ui-polish, bolt 029, ADR-15).
//
// The backend returns the whole catalog, so the rail is derived: a course is
// on it if the learner has opened it (it has a cached dashboard), if it is
// active, or if it reports progress. Coming-soon courses never are, and the
// active course is always first and always present.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/courses/course_rail_source.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/course_cache_store.dart';

const _amharic = Course(
  id: 'c-en-am',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
);
const _oromo = Course(
  id: 'c-en-om',
  learningLanguage: 'om',
  fromLanguage: 'en',
  title: 'English to Afaan Oromo',
);
const _oromoFromAmharic = Course(
  id: 'c-am-om',
  learningLanguage: 'om',
  fromLanguage: 'am',
  title: 'Amharic to Afaan Oromo',
);
const _comingSoon = Course(
  id: 'c-om-am',
  learningLanguage: 'am',
  fromLanguage: 'om',
  title: 'Afaan Oromo to Amharic',
  status: CourseStatus.comingSoon,
);

CourseList _list(String active, [List<Course>? courses]) => CourseList(
  activeCourseId: active,
  courses: [
    for (final c in courses ?? const [_amharic, _oromo, _oromoFromAmharic])
      c.copyWith(isActive: c.id == active),
  ],
);

SkillTreeResponse _tree() => const SkillTreeResponse(
  categories: [],
  nodes: [],
  streakCount: 0,
  beans: 5,
  beansMax: 5,
  totalXp: 0,
);

Future<CourseCacheStore> _cacheWith(List<String> openedCourseIds) async {
  final cache = InMemoryCourseCacheStore();
  for (final id in openedCourseIds) {
    await cache.saveDashboard(id, _tree(), amoleBalance: 0);
  }
  return cache;
}

/// A cache whose every read throws, to prove the rail degrades rather than
/// failing with it.
class _BrokenCache extends InMemoryCourseCacheStore {
  @override
  Future<List<String>> cachedCourseIds() async => throw StateError('broken');
}

List<String> _ids(List<Course> courses) => [for (final c in courses) c.id];

void main() {
  test('with an empty cache the rail is the active course alone', () async {
    final rail = await railCoursesFor(
      _list('c-en-am'),
      cache: await _cacheWith([]),
    );

    expect(_ids(rail), ['c-en-am']);
  });

  test('with no cache at all the rail is still the active course', () async {
    final rail = await railCoursesFor(_list('c-en-am'));

    expect(_ids(rail), ['c-en-am']);
  });

  test('a course the learner has opened joins the rail', () async {
    final rail = await railCoursesFor(
      _list('c-en-am'),
      cache: await _cacheWith(['c-en-am', 'c-en-om']),
    );

    expect(_ids(rail), ['c-en-am', 'c-en-om']);
  });

  test('a course with progress joins the rail even if never cached', () async {
    final list = CourseList(
      activeCourseId: 'c-en-am',
      courses: [
        _amharic.copyWith(isActive: true),
        const Course(
          id: 'c-en-om',
          learningLanguage: 'om',
          fromLanguage: 'en',
          title: 'English to Afaan Oromo',
          completedSkills: 2,
          totalSkills: 4,
        ),
      ],
    );

    final rail = await railCoursesFor(list, cache: await _cacheWith([]));

    expect(_ids(rail), ['c-en-am', 'c-en-om']);
  });

  test('a course neither opened nor progressed stays off the rail', () async {
    final rail = await railCoursesFor(
      _list('c-en-am'),
      cache: await _cacheWith(['c-en-am', 'c-en-om']),
    );

    expect(_ids(rail), isNot(contains('c-am-om')));
  });

  test('the active course is first, whatever the catalog order', () async {
    final rail = await railCoursesFor(
      _list('c-am-om'),
      cache: await _cacheWith(['c-en-am', 'c-en-om', 'c-am-om']),
    );

    expect(rail.first.id, 'c-am-om');
    expect(_ids(rail), ['c-am-om', 'c-en-am', 'c-en-om']);
  });

  test('a coming-soon course is never on the rail, even if cached', () async {
    final rail = await railCoursesFor(
      _list('c-en-am', const [_amharic, _comingSoon]),
      cache: await _cacheWith(['c-en-am', 'c-om-am']),
    );

    expect(_ids(rail), ['c-en-am']);
  });

  test('a cache that cannot be read leaves the server list working', () async {
    final rail = await railCoursesFor(_list('c-en-am'), cache: _BrokenCache());

    expect(_ids(rail), ['c-en-am']);
  });

  test('the rail carries each course, not just its id', () async {
    final rail = await railCoursesFor(
      _list('c-en-am'),
      cache: await _cacheWith(['c-en-am', 'c-en-om']),
    );

    expect(rail.first.isActive, isTrue);
    expect(rail.last.learningLanguage, 'om');
    expect(rail.last.fromLanguage, 'en');
  });
}
