// Tests for the offline rules in `CachingCourseApi` (010-multi-language-
// courses, bolt 027, story 003 / ADR-14).

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/caching_course_api.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/fake_course_api.dart';

const _offline = CourseApiException('Network request failed');

SkillTreeResponse _tree(String courseId) => SkillTreeResponse(
  course: Course(
    id: courseId,
    learningLanguage: 'om',
    fromLanguage: 'en',
    title: 'Tree of $courseId',
  ),
  categories: const [],
  nodes: const [],
  streakCount: 0,
  beans: 5,
  beansMax: 5,
  totalXp: 0,
);

void main() {
  late FakeCourseApi inner;
  late InMemoryCourseCacheStore cache;
  late CachingCourseApi api;

  setUp(() {
    inner = FakeCourseApi(); // c-en-am active; c-en-om, c-am-om available
    cache = InMemoryCourseCacheStore();
    api = CachingCourseApi(inner: inner, cache: cache);
  });

  group('getCourses', () {
    test('online: returns the list and caches it with the active id', () async {
      final list = await api.getCourses();

      expect(list.activeCourseId, 'c-en-am');
      expect((await cache.loadCourseList())!.courses.length, 4);
      expect(await cache.activeCourseId(), 'c-en-am');
    });

    test('offline: serves the cached list', () async {
      await api.getCourses();
      inner.failWith = _offline;

      final list = await api.getCourses();

      expect(list.courses.length, 4);
      expect(list.activeCourse?.id, 'c-en-am');
    });

    test('offline: shows the course chosen offline as active', () async {
      await api.getCourses();
      await cache.saveDashboard('c-en-om', _tree('c-en-om'), amoleBalance: 0);
      inner.failWith = _offline;
      await api.switchCourse('c-en-om');

      final list = await api.getCourses();

      expect(list.activeCourseId, 'c-en-om');
      expect(list.courses.where((c) => c.isActive).map((c) => c.id), [
        'c-en-om',
      ]);
    });

    test('offline with nothing cached: fails', () async {
      inner.failWith = _offline;

      expect(api.getCourses(), throwsA(isA<CourseApiException>()));
    });

    test('a backend rejection is not treated as offline', () async {
      await api.getCourses();
      inner.failWith = const CourseApiException(
        'nope',
        errorCode: 'missing_credentials',
      );

      await expectLater(
        api.getCourses(),
        throwsA(
          isA<CourseApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'missing_credentials',
          ),
        ),
      );
    });
  });

  group('switchCourse', () {
    test('online: switches on the server and records it', () async {
      final course = await api.switchCourse('c-en-om');

      expect(course.isActive, isTrue);
      expect(inner.activeCourseId, 'c-en-om');
      expect(await cache.activeCourseId(), 'c-en-om');
      expect(await cache.pendingSwitchCourseId(), isNull);
    });

    test(
      'offline to a cached course: switches locally and stays pending',
      () async {
        await api.getCourses();
        await cache.saveDashboard('c-en-om', _tree('c-en-om'), amoleBalance: 0);
        inner.failWith = _offline;

        final course = await api.switchCourse('c-en-om');

        expect(course.id, 'c-en-om');
        expect(course.isActive, isTrue);
        expect(await cache.activeCourseId(), 'c-en-om');
        expect(await cache.pendingSwitchCourseId(), 'c-en-om');
        expect(inner.activeCourseId, 'c-en-am'); // the server has not heard yet
      },
    );

    test(
      'offline to a never-cached course: refused, current course stays',
      () async {
        await api.getCourses();
        inner.failWith = _offline;

        await expectLater(
          api.switchCourse('c-en-om'),
          throwsA(
            isA<CourseApiException>().having(
              (e) => e.errorCode,
              'errorCode',
              offlineNotCachedErrorCode,
            ),
          ),
        );
        expect(await cache.activeCourseId(), 'c-en-am');
        expect(await cache.pendingSwitchCourseId(), isNull);
      },
    );

    test('a server rejection is surfaced, never switched locally', () async {
      await cache.saveDashboard('c-om-am', _tree('c-om-am'), amoleBalance: 0);

      await expectLater(
        api.switchCourse('c-om-am'), // coming soon in the fake
        throwsA(
          isA<CourseApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'course_not_available',
          ),
        ),
      );
      expect(await cache.pendingSwitchCourseId(), isNull);
    });
  });

  group('syncPendingSwitch', () {
    Future<void> chooseOffline() async {
      await api.getCourses();
      await cache.saveDashboard('c-en-om', _tree('c-en-om'), amoleBalance: 0);
      inner.failWith = _offline;
      await api.switchCourse('c-en-om');
      inner.switchCalls.clear();
    }

    test('does nothing when nothing is pending', () async {
      await api.syncPendingSwitch();

      expect(inner.switchCalls, isEmpty);
    });

    test('sends the offline choice once the network is back', () async {
      await chooseOffline();
      inner.failWith = null;

      await api.syncPendingSwitch();

      expect(inner.switchCalls, ['c-en-om']);
      expect(inner.activeCourseId, 'c-en-om');
      expect(await cache.pendingSwitchCourseId(), isNull);

      await api.syncPendingSwitch();
      expect(inner.switchCalls, ['c-en-om']); // not sent twice
    });

    test('stays pending while still offline, and never throws', () async {
      await chooseOffline();

      await api.syncPendingSwitch();

      expect(await cache.pendingSwitchCourseId(), 'c-en-om');
    });

    test('drops the choice if the server rejects it', () async {
      await chooseOffline();
      inner.failWith = null;
      inner.switchFailure = const CourseApiException(
        'gone',
        errorCode: 'course_not_available',
      );

      await api.syncPendingSwitch();

      expect(await cache.pendingSwitchCourseId(), isNull);
      expect(inner.activeCourseId, 'c-en-am');
    });

    test('getCourses sends a pending choice before listing', () async {
      await chooseOffline();
      inner.failWith = null;

      final list = await api.getCourses();

      expect(list.activeCourseId, 'c-en-om');
    });
  });
}
