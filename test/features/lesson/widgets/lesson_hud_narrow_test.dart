// The stat pills survive a narrow screen with large values, and each pill
// still announces itself to a screen reader (011-dashboard-ui-polish, bolt
// 028: the streak's spelled-out text became a semantic label so four pills
// and a course control fit one header row).

import 'package:elang/features/lesson/widgets/lesson_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not overflow on a narrow screen with large values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: LessonHud(
              streakCount: 100,
              beans: 5,
              beansMax: 5,
              totalXp: 123456,
              amoleBalance: 10300,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('10300'), findsOneWidget);
  });

  testWidgets('every pill carries the label a screen reader reads', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonHud(
            streakCount: 100,
            beans: 3,
            beansMax: 5,
            totalXp: 123456,
            amoleBalance: 10300,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('100 day streak'), findsOneWidget);
    expect(find.bySemanticsLabel('3 of 5 beans remaining'), findsOneWidget);
    expect(find.bySemanticsLabel('123456 total XP'), findsOneWidget);
    expect(find.bySemanticsLabel('10300 Amole'), findsOneWidget);

    handle.dispose();
  });
}
