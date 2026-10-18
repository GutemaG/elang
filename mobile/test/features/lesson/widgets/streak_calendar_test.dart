// The streak calendar (013-stat-pill-interactions, bolt 061): a Monday-first
// month of UTC days, practised days filled, today ringed, days after today
// or before joining faded, and arrows limited to this month and 5 back.

import 'package:elang/features/lesson/widgets/streak_calendar.dart';
import 'package:elang/shared/models/stat_history.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime.utc(2026, 9, 17);

StreakHistory _history({
  List<int> septemberDays = const [3, 4, 16, 17],
  DateTime? joinedOn,
}) => StreakHistory(
  practisedDays: [for (final d in septemberDays) DateTime.utc(2026, 9, d)],
  currentStreak: 2,
  longestStreak: 2,
  joinedOn: joinedOn ?? DateTime.utc(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  StreakHistory? history,
  DateTime? today,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: StreakCalendar(
            history: history ?? _history(),
            today: today ?? _today,
          ),
        ),
      ),
    ),
  );
}

Finder _day(int n) => find.byKey(ValueKey('streak-day-$n'));

String _month(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('streak-calendar-month')))
    .data!;

Future<void> _tapArrow(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pump();
}

CalendarDay _look(WidgetTester tester, int n) =>
    tester.widget<CalendarDay>(_day(n));

void main() {
  testWidgets('opens on this month with every day', (tester) async {
    await _pump(tester);

    expect(_month(tester), 'September 2026');
    expect(_day(30), findsOneWidget);
    expect(_day(31), findsNothing);
  });

  testWidgets('weeks start on Monday, and the 1st sits in its weekday', (
    tester,
  ) async {
    for (final today in [
      DateTime.utc(2026, 9, 17), // the 1st is a Tuesday
      DateTime.utc(2026, 11, 17), // the 1st is a Sunday
      DateTime.utc(2026, 2, 17), // 28 days
    ]) {
      await _pump(tester, today: today);

      final first = tester.getCenter(_day(1));
      final weekLater = tester.getCenter(_day(8));
      expect(weekLater.dx, first.dx);
      expect(weekLater.dy, greaterThan(first.dy));

      // The month's first Monday is in the leftmost column.
      var monday = 1;
      while (DateTime.utc(today.year, today.month, monday).weekday !=
          DateTime.monday) {
        monday++;
      }
      final lefts = [
        for (var d = 1; d <= 28; d++) tester.getCenter(_day(d)).dx,
      ];
      expect(
        tester.getCenter(_day(monday)).dx,
        lefts.reduce((a, b) => a < b ? a : b),
      );
    }
    expect(_day(29), findsNothing); // February 2026
  });

  testWidgets('practised days are filled and today is ringed', (tester) async {
    await _pump(tester);

    expect(_look(tester, 3).filled, isTrue);
    expect(_look(tester, 5).filled, isFalse);
    expect(_look(tester, 17).ringed, isTrue); // today, practised
    expect(_look(tester, 16).ringed, isFalse);
    expect(_look(tester, 20).faded, isTrue); // after today
  });

  testWidgets('each day reads as one phrase', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      history: _history(
        septemberDays: const [10],
        joinedOn: DateTime.utc(2026, 9, 5),
      ),
    );

    expect(find.bySemanticsLabel('10 September, practised'), findsOneWidget);
    expect(
      find.bySemanticsLabel('11 September, not practised'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('17 September, today, not practised'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('18 September, not yet'), findsOneWidget);
    expect(
      find.bySemanticsLabel('4 September, before you joined'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the arrows go back 5 months and no further, and never past '
      'this month', (tester) async {
    await _pump(tester);

    AppIconButton arrow(String tooltip) => tester.widget<AppIconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(AppIconButton),
      ),
    );
    expect(arrow('Next month').onPressed, isNull);

    for (final month in ['August', 'July', 'June', 'May', 'April']) {
      await _tapArrow(tester, 'Previous month');
      expect(_month(tester), '$month 2026');
    }
    expect(arrow('Previous month').onPressed, isNull);

    await _tapArrow(tester, 'Next month');
    expect(_month(tester), 'May 2026');
  });

  testWidgets('a past month shows its practised days', (tester) async {
    await _pump(
      tester,
      history: StreakHistory(
        practisedDays: [DateTime.utc(2026, 8, 20)],
        currentStreak: 0,
        longestStreak: 1,
        joinedOn: DateTime.utc(2026, 1, 1),
      ),
    );

    await _tapArrow(tester, 'Previous month');
    expect(_look(tester, 20).filled, isTrue);
    expect(_look(tester, 21).filled, isFalse);
  });

  test('the first day shown is 5 months back, across a year end', () {
    expect(
      StreakCalendar.firstDayShown(DateTime.utc(2026, 9, 17)),
      DateTime.utc(2026, 4, 1),
    );
    expect(
      StreakCalendar.firstDayShown(DateTime.utc(2027, 2, 3)),
      DateTime.utc(2026, 9, 1),
    );
  });
}
