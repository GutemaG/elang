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
    expect(find.text('100 Day Streak'), findsOneWidget);
    expect(find.text('10300'), findsOneWidget);
  });
}
