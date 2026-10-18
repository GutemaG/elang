// 026-lesson-path-nodes: a skill's lessons on the tree, kept in saved
// copies, and the path's stops built from them.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/skill_tree.dart';

SkillTreeNode _skill(
  SkillNodeState state, {
  List<SkillLesson> lessons = const [
    SkillLesson(id: 'l1', title: 'One', done: false),
    SkillLesson(id: 'l2', title: 'Two', done: false),
    SkillLesson(id: 'l3', title: 'Three', done: false),
  ],
}) => SkillTreeNode(
  id: 's1',
  lessonId: 'l1',
  title: 'Greetings',
  subtitle: '',
  state: state,
  categoryId: 'c1',
  lessonCount: lessons.length,
  lessons: lessons,
);

List<SkillNodeState> _states(SkillTreeNode skill) => [
  for (final stop in PathStop.ofLessons(skill)) stop.state,
];

void main() {
  group('lessons on the tree', () {
    test('are read, saved and read back with the tree', () {
      final node = SkillTreeNode.fromJson({
        'id': 's1',
        'lesson_id': 'l2',
        'title': 'Greetings',
        'subtitle': '',
        'state': 'active',
        'category_id': 'c1',
        'crown_level': 0,
        'lessons': [
          {'id': 'l1', 'title': 'Hello', 'done': true},
          {'id': 'l2', 'title': 'Goodbye', 'done': false},
        ],
      });
      expect(node.lessons.map((l) => (l.id, l.title, l.done)), [
        ('l1', 'Hello', true),
        ('l2', 'Goodbye', false),
      ]);

      final tree = SkillTreeResponse(
        categories: const [SkillCategory(id: 'c1', title: 'S1', subtitle: '')],
        nodes: [node],
        streakCount: 0,
        beans: 5,
        beansMax: 5,
        totalXp: 0,
      );
      final back = SkillTreeResponse.fromJson(tree.toJson())!;
      expect(back.nodes.single.lessons.map((l) => l.title), [
        'Hello',
        'Goodbye',
      ]);
      expect(back.nodes.single.lessons.first.done, isTrue);
    });

    test('are none from an older backend or saved copy', () {
      final node = SkillTreeNode.fromJson({
        'id': 's1',
        'lesson_id': 'l1',
        'title': 'Greetings',
        'subtitle': '',
        'state': 'active',
        'category_id': 'c1',
        'crown_level': 0,
      });
      expect(node.lessons, isEmpty);
    });
  });

  group('the path’s stops', () {
    test('are one per lesson, in order, the first carrying the label', () {
      final stops = PathStop.ofLessons(_skill(SkillNodeState.active));

      expect(stops.map((s) => s.lessonId), ['l1', 'l2', 'l3']);
      expect(stops.map((s) => s.title), ['One', 'Two', 'Three']);
      expect(stops.map((s) => s.isFirstOfSkill), [true, false, false]);
      expect(stops.every((s) => s.isLesson), isTrue);
      expect(stops.map((s) => s.id).toSet(), hasLength(3));
    });

    test('of a locked skill are locked; of a completed one, completed', () {
      expect(_states(_skill(SkillNodeState.locked)), [
        SkillNodeState.locked,
        SkillNodeState.locked,
        SkillNodeState.locked,
      ]);
      final completed = PathStop.ofLessons(_skill(SkillNodeState.completed));
      expect(completed.map((s) => s.state).toSet(), {SkillNodeState.completed});
      expect(completed.every((s) => s.isReview), isTrue);
      expect(completed.any((s) => s.isDoneInUnfinishedSkill), isFalse);
    });

    test('of an active skill: done, then the current one, then waiting', () {
      final skill = _skill(
        SkillNodeState.active,
        lessons: const [
          SkillLesson(id: 'l1', title: 'One', done: true),
          SkillLesson(id: 'l2', title: 'Two', done: false),
          SkillLesson(id: 'l3', title: 'Three', done: false),
        ],
      );
      final stops = PathStop.ofLessons(skill);

      expect(stops.map((s) => s.state), [
        SkillNodeState.completed,
        SkillNodeState.active,
        SkillNodeState.locked,
      ]);
      expect(stops.first.isDoneInUnfinishedSkill, isTrue);
      expect(stops.first.isReview, isFalse);
      expect(stops.any((s) => s.isPartlyDone), isFalse);
    });

    test('of an active skill keep a later lesson done out of order', () {
      final skill = _skill(
        SkillNodeState.active,
        lessons: const [
          SkillLesson(id: 'l1', title: 'One', done: false),
          SkillLesson(id: 'l2', title: 'Two', done: true),
          SkillLesson(id: 'l3', title: 'Three', done: false),
        ],
      );

      expect(_states(skill), [
        SkillNodeState.active,
        SkillNodeState.completed,
        SkillNodeState.locked,
      ]);
    });

    test('are the whole skill when it has no lessons, as before', () {
      final skill = SkillTreeNode(
        id: 's1',
        lessonId: 'l2',
        title: 'Greetings',
        subtitle: '',
        state: SkillNodeState.active,
        categoryId: 'c1',
        lessonsDone: 1,
        lessonCount: 3,
      );
      final stops = PathStop.ofLessons(skill);

      expect(stops, hasLength(1));
      expect(stops.single.isLesson, isFalse);
      expect(stops.single.lessonId, 'l2');
      expect(stops.single.title, 'Greetings');
      expect(stops.single.isPartlyDone, isTrue);
    });
  });
}
