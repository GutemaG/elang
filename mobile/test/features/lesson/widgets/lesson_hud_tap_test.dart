// The dashboard's counters as buttons (013-stat-pill-interactions, bolt
// 060): the row is scaled down and the pills are tiny, so the whole space
// the row is given takes taps, each going to the nearest pill.

import 'package:elang/features/courses/course_badge.dart';
import 'package:elang/features/lesson/widgets/dashboard_header.dart';
import 'package:elang/features/lesson/widgets/lesson_hud.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const _course = Course(
  id: 'c',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
);

Future<List<StatKind>> _pumpHeader(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <StatKind>[];
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: DashboardHeader.extentOf(context),
              child: DashboardHeader(
                leading: CourseBadge(
                  course: _course,
                  expanded: false,
                  onTap: () {},
                ),
                hud: LessonHud(
                  streakCount: 12,
                  beans: 3,
                  beansMax: 5,
                  totalXp: 1240,
                  amoleBalance: 85,
                  onOpen: opened.add,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return opened;
}

Finder _pill(StatKind kind) =>
    find.byWidgetPredicate((w) => w is StatPill && w.kind == kind);

void main() {
  testWidgets('a tap on each pill opens that pill', (tester) async {
    final opened = await _pumpHeader(tester);
    for (final kind in StatKind.values) {
      await tester.tap(_pill(kind));
    }
    expect(opened, StatKind.values);
  });

  testWidgets('the tap area is the header row\'s full height', (tester) async {
    final opened = await _pumpHeader(tester);
    final area = tester.getRect(
      find.byKey(const ValueKey('lesson-hud-tap-area')),
    );
    expect(area.height, greaterThanOrEqualTo(48));
    expect(tester.getRect(_pill(StatKind.xp)).height, lessThan(48));

    for (final kind in StatKind.values) {
      final x = tester.getCenter(_pill(kind)).dx;
      await tester.tapAt(Offset(x, area.top + 1));
      await tester.tapAt(Offset(x, area.bottom - 1));
    }
    expect(opened, [
      for (final kind in StatKind.values) ...[kind, kind],
    ]);
  });

  testWidgets('a tap between two pills goes to the nearer one', (tester) async {
    final opened = await _pumpHeader(tester);
    final beans = tester.getRect(_pill(StatKind.beans));
    final xp = tester.getRect(_pill(StatKind.xp));
    final y = beans.center.dy;
    final gap = xp.left - beans.right;
    expect(gap, greaterThan(0));

    await tester.tapAt(Offset(beans.right + gap * 0.25, y));
    await tester.tapAt(Offset(xp.left - gap * 0.25, y));
    expect(opened, [StatKind.beans, StatKind.xp]);
  });

  testWidgets('the space left of the pills goes to the first', (tester) async {
    // Wide enough that the row is not scaled down and leaves room.
    final opened = await _pumpHeader(tester, width: 1000);
    final area = tester.getRect(
      find.byKey(const ValueKey('lesson-hud-tap-area')),
    );
    expect(area.left, lessThan(tester.getRect(_pill(StatKind.streak)).left));

    await tester.tapAt(Offset(area.left + 1, area.center.dy));
    expect(opened, [StatKind.streak]);
  });

  testWidgets('a finger down shows the pill it will open as pressed', (
    tester,
  ) async {
    await _pumpHeader(tester);
    final area = tester.getRect(
      find.byKey(const ValueKey('lesson-hud-tap-area')),
    );
    final gesture = await tester.startGesture(
      Offset(tester.getCenter(_pill(StatKind.amole)).dx, area.top + 1),
    );
    await tester.pump();

    expect(tester.widget<StatPill>(_pill(StatKind.amole)).pressed, isTrue);
    expect(tester.widget<StatPill>(_pill(StatKind.xp)).pressed, isFalse);
    await gesture.up();
    await tester.pump();
    expect(tester.widget<StatPill>(_pill(StatKind.amole)).pressed, isFalse);
  });

  testWidgets('each pill is one button for a screen reader, and the tap '
      'area adds none', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = await _pumpHeader(tester);

    for (final (kind, label) in [
      (StatKind.streak, '12 day streak'),
      (StatKind.beans, '3 of 5 beans remaining'),
      (StatKind.xp, '1240 total XP'),
      (StatKind.amole, '85 Amole'),
    ]) {
      expect(
        tester.getSemantics(_pill(kind)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
      tester.semantics.tap(find.semantics.byLabel(label));
    }
    expect(opened, StatKind.values);
    // Every tappable node has a label: the pills and the course badge.
    expect(
      find.semantics.byPredicate((node) {
        final data = node.getSemanticsData();
        return data.hasAction(SemanticsAction.tap) && data.label.isEmpty;
      }),
      findsNothing,
    );
    semantics.dispose();
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits $width dp at 1.3x text', (tester) async {
      await _pumpHeader(tester, width: width, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without onOpen the pills are the plain counters', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonHud(
            streakCount: 1,
            beans: 1,
            beansMax: 5,
            totalXp: 1,
            amoleBalance: 1,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('lesson-hud-tap-area')), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });
}
