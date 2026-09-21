// Tests for the per-course offline cache (010-multi-language-courses, bolt 027,
// story 003): trees are kept per course and never mixed, the course list and
// the active/pending course survive, and a damaged cache reads as empty.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/course_cache_store.dart';

SkillTreeResponse _tree(String courseId, String skillTitle, {int xp = 10}) =>
    SkillTreeResponse(
      course: Course(
        id: courseId,
        learningLanguage: 'om',
        fromLanguage: 'en',
        title: 'Course $courseId',
      ),
      categories: const [
        SkillCategory(id: 'cat', title: 'Nagaa', subtitle: 's'),
      ],
      nodes: [
        SkillTreeNode(
          id: 'n-$courseId',
          lessonId: 'l-$courseId',
          title: skillTitle,
          subtitle: 'sub',
          state: SkillNodeState.completed,
          categoryId: 'cat',
          crownLevel: 2,
          contentVersion: DateTime.utc(2026, 9, 1, 12),
        ),
      ],
      streakCount: 3,
      beans: 4,
      beansMax: 5,
      totalXp: xp,
    );

void main() {
  test('a tree round-trips with its course, nodes and stats', () async {
    final store = InMemoryCourseCacheStore();
    await store.saveDashboard('a', _tree('a', 'Akkam'), amoleBalance: 120);

    final cached = (await store.loadDashboard('a'))!;

    expect(cached.amoleBalance, 120);
    expect(cached.tree.course?.id, 'a');
    expect(cached.tree.categories.single.title, 'Nagaa');
    final node = cached.tree.nodes.single;
    expect(node.title, 'Akkam');
    expect(node.state, SkillNodeState.completed);
    expect(node.crownLevel, 2);
    expect(node.contentVersion, DateTime.utc(2026, 9, 1, 12));
    expect(cached.tree.totalXp, 10);
    expect(cached.tree.streakCount, 3);
  });

  test('two courses are kept apart and never mixed', () async {
    final store = InMemoryCourseCacheStore();
    await store.saveDashboard('a', _tree('a', 'Akkam'), amoleBalance: 1);
    await store.saveDashboard('b', _tree('b', 'Hello'), amoleBalance: 2);

    expect((await store.loadDashboard('a'))!.tree.nodes.single.title, 'Akkam');
    expect((await store.loadDashboard('b'))!.tree.nodes.single.title, 'Hello');
    expect(await store.loadDashboard('never-cached'), isNull);
  });

  test('saving one course leaves the other untouched', () async {
    final store = InMemoryCourseCacheStore();
    await store.saveDashboard('a', _tree('a', 'Akkam'), amoleBalance: 1);
    await store.saveDashboard('b', _tree('b', 'Hello'), amoleBalance: 2);
    await store.saveDashboard(
      'a',
      _tree('a', 'Akkam', xp: 99),
      amoleBalance: 1,
    );

    expect((await store.loadDashboard('a'))!.tree.totalXp, 99);
    expect((await store.loadDashboard('b'))!.tree.totalXp, 10);
  });

  test('the course list round-trips and can be re-marked active', () async {
    final store = InMemoryCourseCacheStore();
    const list = CourseList(
      activeCourseId: 'a',
      courses: [
        Course(
          id: 'a',
          learningLanguage: 'am',
          fromLanguage: 'en',
          title: 'A',
          isActive: true,
          completedSkills: 3,
          totalSkills: 10,
        ),
        Course(
          id: 'b',
          learningLanguage: 'om',
          fromLanguage: 'en',
          title: 'B',
          status: CourseStatus.comingSoon,
        ),
      ],
    );
    await store.saveCourseList(list);

    final loaded = (await store.loadCourseList())!;
    expect(loaded.courses.map((c) => c.id), ['a', 'b']);
    expect(loaded.courses.first.completedSkills, 3);
    expect(loaded.courses.last.status, CourseStatus.comingSoon);

    final moved = loaded.withActive('b');
    expect(moved.activeCourseId, 'b');
    expect(moved.courses.map((c) => c.isActive), [false, true]);
  });

  test('the active course and a pending offline switch are tracked', () async {
    final store = InMemoryCourseCacheStore();
    expect(await store.activeCourseId(), isNull);
    expect(await store.pendingSwitchCourseId(), isNull);

    await store.setActiveCourseId('a');
    expect(await store.activeCourseId(), 'a');
    expect(await store.pendingSwitchCourseId(), isNull);

    await store.setActiveCourseId('b', pendingSync: true);
    expect(await store.activeCourseId(), 'b');
    expect(await store.pendingSwitchCourseId(), 'b');

    await store.clearPendingSwitch();
    expect(await store.pendingSwitchCourseId(), isNull);
    expect(await store.activeCourseId(), 'b');

    // A later online choice replaces an old pending one.
    await store.setActiveCourseId('c', pendingSync: true);
    await store.setActiveCourseId('a');
    expect(await store.pendingSwitchCourseId(), isNull);
  });

  test('overlapping writes do not lose each other', () async {
    final store = InMemoryCourseCacheStore();
    await Future.wait([
      store.saveDashboard('a', _tree('a', 'Akkam'), amoleBalance: 1),
      store.setActiveCourseId('a'),
      store.saveDashboard('b', _tree('b', 'Hello'), amoleBalance: 1),
    ]);

    expect(await store.loadDashboard('a'), isNotNull);
    expect(await store.loadDashboard('b'), isNotNull);
    expect(await store.activeCourseId(), 'a');
  });

  test('a corrupt cache reads as empty, not as an error', () async {
    final store = InMemoryCourseCacheStore()..rawJson = '{not json';

    expect(await store.loadDashboard('a'), isNull);
    expect(await store.loadCourseList(), isNull);
    expect(await store.activeCourseId(), isNull);

    // And it recovers on the next write.
    await store.setActiveCourseId('a');
    expect(await store.activeCourseId(), 'a');
  });

  test('a damaged tree entry is ignored', () async {
    final store = InMemoryCourseCacheStore()
      ..rawJson =
          '{"dashboards":{"a":{"tree":{"nodes":"x"},"amole_balance":1}}}';

    expect(await store.loadDashboard('a'), isNull);
  });

  test('cachedCourseIds lists every course that has been opened', () async {
    final store = InMemoryCourseCacheStore();
    expect(await store.cachedCourseIds(), isEmpty);

    await store.saveDashboard('a', _tree('a', 'Akkam'), amoleBalance: 1);
    await store.saveDashboard('b', _tree('b', 'Hello'), amoleBalance: 2);

    expect(await store.cachedCourseIds()..sort(), ['a', 'b']);
  });

  test('cachedCourseIds reads a corrupt cache as nothing opened', () async {
    final store = InMemoryCourseCacheStore()..rawJson = 'not json at all';

    expect(await store.cachedCourseIds(), isEmpty);
  });

  test('the Practice due count is kept with the dashboard', () async {
    final store = InMemoryCourseCacheStore();

    await store.saveDashboard('a', _tree('a', 'x'), amoleBalance: 1, dueCount: 7);

    expect((await store.loadDashboard('a'))?.dueCount, 7);
  });

  group('lessons', () {
    const lesson = LessonContent(
      lessonId: 'l-1',
      skillId: 's-1',
      title: 'Greetings',
      beansAtStart: 3,
      beansMax: 5,
      unrenderableCount: 1,
      exercises: [
        MultipleChoiceExercise(
          id: 'mc-1',
          prompt: 'ሰላም',
          promptTranslation: 'Hello?',
          options: ['hello', 'bye'],
          correctOptionIndex: 0,
        ),
      ],
    );
    final v1 = DateTime.utc(2026, 9, 1);
    final v2 = DateTime.utc(2026, 9, 2);

    test('a lesson round-trips with its skill version', () async {
      final store = InMemoryCourseCacheStore();

      await store.saveLesson(lesson, skillVersion: v1);
      final cached = await store.loadLesson('l-1');

      expect(cached!.content.title, 'Greetings');
      expect(cached.content.unrenderableCount, 1);
      expect(cached.content.exercises.single, isA<MultipleChoiceExercise>());
      expect(cached.skillVersion, v1);
    });

    test('a lesson never fetched is a miss', () async {
      expect(await InMemoryCourseCacheStore().loadLesson('nope'), isNull);
    });

    test('a copy is fresh only for the skill version it was saved at', () async {
      final store = InMemoryCourseCacheStore();
      await store.saveLesson(lesson, skillVersion: v1);
      final cached = await store.loadLesson('l-1');

      expect(cached!.isFreshFor(v1), isTrue);
      expect(cached.isFreshFor(v2), isFalse);
      expect(cached.isFreshFor(null), isTrue);
    });

    test('lessons do not disturb the dashboards beside them', () async {
      final store = InMemoryCourseCacheStore();
      await store.saveDashboard('a', _tree('a', 'Akkam'), amoleBalance: 1);

      await store.saveLesson(lesson);

      expect((await store.loadDashboard('a'))?.tree.nodes.single.title, 'Akkam');
      expect(await store.cachedCourseIds(), ['a']);
    });
  });
}
