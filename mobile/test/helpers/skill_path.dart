import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/widgets/skill_path_node.dart';
import 'package:elang/shared/widgets/path_popover.dart';

/// The path node of the skill titled [title]. The path shows no titles, so
/// tests find a skill by its node.
Finder findSkill(String title) => find.byWidgetPredicate(
  (w) => w is SkillPathNode && w.stop.title == title,
  description: 'the path node of "$title"',
);

/// Taps [title]'s node, which opens its popover.
Future<void> openSkill(WidgetTester tester, String title) async {
  await tester.tap(findSkill(title));
  await tester.pumpAndSettle();
}

/// Taps [title]'s node and then its popover's Start, Continue or Review.
Future<void> startSkill(WidgetTester tester, String title) async {
  await openSkill(tester, title);
  await tester.tap(find.byKey(PathPopover.actionKey));
  await tester.pumpAndSettle();
}
