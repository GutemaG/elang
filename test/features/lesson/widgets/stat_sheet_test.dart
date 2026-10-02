// The stats sheet (013-stat-pill-interactions, bolt 060): four tabs that
// are the counters themselves, and a beans tab that counts down, adds the
// bean that arrives, and refills with Amole.

import 'dart:async';

import 'package:elang/features/lesson/widgets/amole_history.dart';
import 'package:elang/features/lesson/widgets/bean_timer_card.dart';
import 'package:elang/features/lesson/widgets/stat_sheet.dart';
import 'package:elang/features/lesson/widgets/streak_calendar.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/stat_history.dart';
import 'package:elang/shared/services/lesson_api_exception.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 9, 30, 12);

BeansStatus _beans({
  int beans = 2,
  Duration? nextIn = const Duration(seconds: 90),
  int amole = 400,
  int regen = 30,
  int cost = 350,
}) => BeansStatus(
  beans: beans,
  beansMax: 5,
  regenMinutesPerBean: regen,
  amoleBalance: amole,
  refillCostAmole: cost,
  nextBeanAt: nextIn == null ? null : _start.add(nextIn),
);

StreakHistory _streak({int longest = 9, List<int> septemberDays = const []}) =>
    StreakHistory(
      practisedDays: [for (final d in septemberDays) DateTime.utc(2026, 9, d)],
      currentStreak: 12,
      longestStreak: longest,
      joinedOn: DateTime.utc(2026, 1, 1),
    );

final _entries = [
  AmoleEntry(
    amount: 10,
    source: 'lesson_completion',
    createdAt: DateTime.utc(2026, 9, 30, 11),
  ),
  AmoleEntry(
    amount: -350,
    source: 'bean_refill',
    createdAt: DateTime.utc(2026, 9, 28, 11),
  ),
  AmoleEntry(
    amount: 7,
    source: 'something_new',
    createdAt: DateTime.utc(2026, 9, 27, 11),
  ),
];

class _Rig {
  _Rig({
    BeansStatus? beans,
    this.initial = StatKind.beans,
    this.offline = false,
    this.refillWith,
    this.streakCount = 12,
    StreakHistory? streak,
    List<AmoleEntry>? amole,
  }) : beans = beans ?? _beans(),
       streak = streak ?? _streak(),
       amole = amole ?? _entries;

  final int streakCount;
  StreakHistory streak;
  List<AmoleEntry> amole;
  Object? streakError;
  Object? amoleError;

  /// Holds a load until completed, to see the spinner.
  Completer<void>? gate;
  final streakCalls = <(DateTime, DateTime)>[];
  var amoleCalls = 0;

  final BeansStatus beans;
  final StatKind initial;
  final bool offline;
  final Future<RefillResult> Function()? refillWith;

  DateTime now = _start;
  final changes = <BeansStatus>[];
  var refills = 0;

  Widget build({double textScale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: StatSheet(
          initial: initial,
          streakCount: streakCount,
          totalXp: 1240,
          beans: beans,
          offline: offline,
          now: () => now,
          refill: () {
            refills++;
            return refillWith?.call() ??
                Future.value(
                  const RefillSuccess(newBeans: 5, newAmoleBalance: 50),
                );
          },
          onBeansChanged: changes.add,
          loadStreak: ({required from, required to}) async {
            streakCalls.add((from, to));
            await gate?.future;
            if (streakError != null) throw streakError!;
            return streak;
          },
          loadAmole: ({int limit = 20}) async {
            amoleCalls++;
            await gate?.future;
            if (amoleError != null) throw amoleError!;
            return amole;
          },
        ),
      ),
    ),
  );

  /// One second on the sheet's clock and the test's.
  Future<void> tick(WidgetTester tester, [int seconds = 1]) async {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }
}

Finder _tab(StatKind kind) =>
    find.byKey(ValueKey('stat-sheet-tab-${kind.name}'));

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void main() {
  group('tabs', () {
    testWidgets('opens on the counter tapped, chosen as its tab', (
      tester,
    ) async {
      await tester.pumpWidget(_Rig(initial: StatKind.xp).build());

      expect(find.text('1,240 XP'), findsOneWidget);
      expect(tester.widget<StatPill>(_tab(StatKind.xp)).selected, isTrue);
      expect(tester.widget<StatPill>(_tab(StatKind.beans)).selected, isFalse);
    });

    testWidgets('a tab switches the body', (tester) async {
      await tester.pumpWidget(_Rig(initial: StatKind.xp).build());

      await tester.tap(_tab(StatKind.streak));
      await tester.pump();
      expect(find.text('12 day streak'), findsOneWidget);
      expect(find.text('1,240 XP'), findsNothing);

      await tester.tap(_tab(StatKind.amole));
      await tester.pump();
      expect(find.text('400 Amole'), findsOneWidget);
      expect(find.textContaining('Spent on bean refills'), findsOneWidget);
      expect(tester.widget<StatPill>(_tab(StatKind.amole)).selected, isTrue);
    });

    testWidgets('each tab is 48 dp tall and a button', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_Rig().build());

      for (final kind in StatKind.values) {
        expect(tester.getSize(_tab(kind)).height, 48);
      }
      expect(
        tester.getSemantics(_tab(StatKind.beans)),
        isSemantics(
          label: '2 of 5 beans remaining',
          isButton: true,
          isSelected: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('each body has a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_Rig().build());
      expect(
        tester.getSemantics(find.text('Beans')),
        isSemantics(label: 'Beans', isHeader: true),
      );
      semantics.dispose();
    });
  });

  group('beans', () {
    testWidgets('counts down each second', (tester) async {
      final rig = _Rig();
      await tester.pumpWidget(rig.build());

      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);
      expect(find.text('Refills 1 bean every 30 minutes'), findsOneWidget);

      await rig.tick(tester);
      expect(find.text('01:29'), findsOneWidget);
    });

    testWidgets('at zero the bean arrives, here and on the dashboard', (
      tester,
    ) async {
      final rig = _Rig(beans: _beans(nextIn: const Duration(seconds: 2)));
      await tester.pumpWidget(rig.build());

      await rig.tick(tester, 2);
      expect(find.text('3 / 5'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
      expect(rig.changes.single.beans, 3);
      expect(tester.widget<StatPill>(_tab(StatKind.beans)).value, 3);
    });

    testWidgets('full beans say so, with no timer and no refill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Rig(beans: _beans(beans: 5, nextIn: null)).build(),
      );

      expect(find.text('Your beans are full'), findsOneWidget);
      expect(find.textContaining('one every 30 minutes'), findsOneWidget);
      expect(find.byType(BeanTimerCard), findsNothing);
      expect(find.textContaining('Refill'), findsNothing);
    });

    testWidgets('a bean that came while the dashboard sat still is caught '
        'up on opening', (tester) async {
      final rig = _Rig(beans: _beans(nextIn: const Duration(minutes: -1)));
      await tester.pumpWidget(rig.build());

      expect(find.text('3 / 5'), findsOneWidget);
      expect(rig.changes.single.beans, 3);
    });

    testWidgets('on another tab it stops counting, and catches up on '
        'coming back', (tester) async {
      final rig = _Rig(beans: _beans(nextIn: const Duration(seconds: 2)));
      await tester.pumpWidget(rig.build());

      await tester.tap(_tab(StatKind.xp));
      await tester.pump();
      await rig.tick(tester, 3);
      expect(rig.changes, isEmpty);

      await tester.tap(_tab(StatKind.beans));
      await tester.pump();
      expect(rig.changes.single.beans, 3);
      expect(find.text('3 / 5'), findsOneWidget);
    });

    testWidgets('the refill fills the beans and tells the dashboard', (
      tester,
    ) async {
      final rig = _Rig();
      await tester.pumpWidget(rig.build());

      expect(find.text('350 Amole'), findsOneWidget); // the price
      await tester.tap(find.text('Refill with Amole'));
      await tester.pump();

      expect(rig.refills, 1);
      expect(rig.changes.single.beans, 5);
      expect(rig.changes.single.amoleBalance, 50);
      expect(find.text('Your beans are full'), findsOneWidget);
      expect(tester.widget<StatPill>(_tab(StatKind.amole)).value, 50);
    });

    testWidgets('shows a spinner while the refill is sent', (tester) async {
      final reply = Completer<RefillResult>();
      final rig = _Rig(refillWith: () => reply.future);
      await tester.pumpWidget(rig.build());

      await tester.tap(find.text('Refill with Amole'));
      await tester.pump();
      expect(
        tester.widget<AppButton>(find.byType(AppButton).first).loading,
        isTrue,
      );

      reply.complete(const RefillSuccess(newBeans: 5, newAmoleBalance: 50));
      await tester.pump();
      expect(find.text('Your beans are full'), findsOneWidget);
    });

    testWidgets('cannot refill without enough Amole', (tester) async {
      final rig = _Rig(beans: _beans(amole: 100));
      await tester.pumpWidget(rig.build());

      expect(_button(tester, 'Not enough Amole').onPressed, isNull);
      await tester.tap(find.text('Not enough Amole'));
      expect(rig.refills, 0);
    });

    testWidgets('a refill the server refuses says so and changes nothing', (
      tester,
    ) async {
      final rig = _Rig(
        refillWith: () => Future.value(
          const RefillFailure(RefillFailureReason.insufficientAmole),
        ),
      );
      await tester.pumpWidget(rig.build());

      await tester.tap(find.text('Refill with Amole'));
      await tester.pump();
      expect(find.text('Not enough Amole for a refill.'), findsOneWidget);
      expect(rig.changes, isEmpty);
      expect(find.text('2 / 5'), findsOneWidget);
    });

    testWidgets('a refill that cannot be sent says so and changes nothing', (
      tester,
    ) async {
      final rig = _Rig(
        refillWith: () =>
            Future.error(const LessonApiException('Network request failed')),
      );
      await tester.pumpWidget(rig.build());

      await tester.tap(find.text('Refill with Amole'));
      await tester.pump();
      expect(find.textContaining("Couldn't refill"), findsOneWidget);
      expect(rig.changes, isEmpty);
      expect(_button(tester, 'Refill with Amole').loading, isFalse);
    });

    testWidgets('offline it still counts down, and the refill waits for a '
        'connection', (tester) async {
      final rig = _Rig(offline: true);
      await tester.pumpWidget(rig.build());

      expect(find.text('01:30'), findsOneWidget);
      expect(_button(tester, 'Refill needs a connection').onPressed, isNull);
      await rig.tick(tester);
      expect(find.text('01:29'), findsOneWidget);
    });

    testWidgets('an old offline copy with no timing shows the count only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Rig(
          beans: _beans(nextIn: null, regen: 0, cost: 0),
          offline: true,
        ).build(),
      );

      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.byType(BeanTimerCard), findsNothing);
      expect(find.text('0 Amole'), findsNothing); // no price badge
    });
  });

  group('streak', () {
    testWidgets('loads this month and the 5 before, once, and shows the '
        'calendar with the longest streak', (tester) async {
      final rig = _Rig(initial: StatKind.streak);
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(rig.streakCalls, [
        (DateTime.utc(2026, 4, 1), DateTime.utc(2026, 9, 30)),
      ]);
      expect(find.text('12 day streak'), findsOneWidget);
      expect(find.text('Longest: 9 days'), findsOneWidget);
      expect(find.byType(StreakCalendar), findsOneWidget);

      await tester.tap(_tab(StatKind.xp));
      await tester.pump();
      await tester.tap(_tab(StatKind.streak));
      await tester.pump();
      expect(rig.streakCalls, hasLength(1));
    });

    testWidgets('shows a spinner while loading', (tester) async {
      final rig = _Rig(initial: StatKind.streak)..gate = Completer();
      await tester.pumpWidget(rig.build());

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.byType(StreakCalendar), findsNothing);

      rig.gate!.complete();
      await tester.pump();
      expect(find.byType(StreakCalendar), findsOneWidget);
    });

    testWidgets('a failed load offers to try again', (tester) async {
      final rig = _Rig(initial: StatKind.streak)
        ..streakError = const LessonApiException('Network request failed');
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(find.text("Couldn't load the calendar"), findsOneWidget);
      rig.streakError = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(rig.streakCalls, hasLength(2));
      expect(find.byType(StreakCalendar), findsOneWidget);
    });

    testWidgets('offline it shows the streak and asks for a connection', (
      tester,
    ) async {
      final rig = _Rig(initial: StatKind.streak, offline: true);
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(rig.streakCalls, isEmpty);
      expect(find.text('12 day streak'), findsOneWidget);
      expect(
        find.textContaining('calendar needs a connection'),
        findsOneWidget,
      );
    });

    testWidgets('a learner with no lessons sees 0 and an empty calendar', (
      tester,
    ) async {
      final rig = _Rig(
        initial: StatKind.streak,
        streakCount: 0,
        streak: StreakHistory(
          practisedDays: const [],
          currentStreak: 0,
          longestStreak: 0,
          joinedOn: DateTime.utc(2026, 9, 30),
        ),
      );
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(find.text('0 day streak'), findsOneWidget);
      expect(find.text('Longest: 0 days'), findsOneWidget);
      expect(find.byType(StreakCalendar), findsOneWidget);
    });
  });

  group('Amole', () {
    testWidgets('lists the entries newest first, signed, with reasons', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final rig = _Rig(initial: StatKind.amole);
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(rig.amoleCalls, 1);
      expect(find.text('400 Amole'), findsOneWidget);
      final reasons = ['Lesson finished', 'Bean refill', 'Amole'];
      final ys = [
        for (final reason in reasons) tester.getTopLeft(find.text(reason)).dy,
      ];
      expect(ys, [...ys]..sort());
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('\u2212350'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Bean refill, minus 350 Amole, 2[78] September$'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('no entries says so', (tester) async {
      await tester.pumpWidget(
        _Rig(initial: StatKind.amole, amole: const []).build(),
      );
      await tester.pump();

      expect(find.text('No Amole yet'), findsOneWidget);
    });

    testWidgets('a failed load offers to try again', (tester) async {
      final rig = _Rig(initial: StatKind.amole)
        ..amoleError = const LessonApiException('Network request failed');
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(find.text("Couldn't load the list"), findsOneWidget);
      rig.amoleError = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AmoleHistoryList), findsOneWidget);
    });

    testWidgets('offline it shows the balance and asks for a connection', (
      tester,
    ) async {
      final rig = _Rig(initial: StatKind.amole, offline: true);
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(rig.amoleCalls, 0);
      expect(find.text('400 Amole'), findsOneWidget);
      expect(find.textContaining('list needs a connection'), findsOneWidget);
    });

    testWidgets('after a refill the list is fetched again', (tester) async {
      final rig = _Rig(initial: StatKind.amole);
      await tester.pumpWidget(rig.build());
      await tester.pump();
      expect(rig.amoleCalls, 1);

      await tester.tap(_tab(StatKind.beans));
      await tester.pump();
      await tester.ensureVisible(find.text('Refill with Amole'));
      await tester.tap(find.text('Refill with Amole'));
      await tester.pump();
      await tester.tap(_tab(StatKind.amole));
      await tester.pump();
      await tester.pump();

      expect(rig.amoleCalls, 2);
      expect(find.text('50 Amole'), findsOneWidget);
    });

    testWidgets('a long list scrolls in its own box, so the sheet stays '
        'short and closes with a tap above it', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final many = [
        for (var i = 0; i < 20; i++)
          AmoleEntry(
            amount: 10,
            source: 'lesson_completion',
            createdAt: DateTime.utc(2026, 9, 30 - i, 11),
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showStatSheet(
                    context,
                    initial: StatKind.amole,
                    streakCount: 1,
                    totalXp: 0,
                    beans: _beans(beans: 5, nextIn: null),
                    offline: false,
                    refill: () => Future.value(
                      const RefillFailure(
                        RefillFailureReason.insufficientAmole,
                      ),
                    ),
                    onBeansChanged: (_) {},
                    loadStreak: ({required from, required to}) async =>
                        _streak(),
                    loadAmole: ({int limit = 20}) async => many,
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      final list = find.byKey(const ValueKey('stat-sheet-amole-scroll'));
      expect(
        tester.getSize(list).height,
        lessThanOrEqualTo(640 * StatSheet.amoleListMaxHeightFraction),
      );
      // Close shows without scrolling the sheet, and the sheet leaves room
      // above it.
      expect(tester.getBottomLeft(find.text('Close')).dy, lessThan(640));
      expect(tester.getTopLeft(find.byType(StatSheet)).dy, greaterThan(80));

      // The list scrolls to its last entry.
      await tester.drag(list, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.byType(StatSheet), findsOneWidget);

      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(find.byType(StatSheet), findsNothing);
    });
  });

  group('XP', () {
    testWidgets('explains XP and lists no history', (tester) async {
      final rig = _Rig(initial: StatKind.xp);
      await tester.pumpWidget(rig.build());
      await tester.pump();

      expect(find.text('1,240 XP'), findsOneWidget);
      expect(find.textContaining('You earn XP'), findsOneWidget);
      expect(find.byType(AmoleHistoryList), findsNothing);
      expect(find.byType(StreakCalendar), findsNothing);
      expect(rig.streakCalls, isEmpty);
      expect(rig.amoleCalls, 0);
    });
  });

  group('the sheet', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showStatSheet(
                    context,
                    initial: StatKind.streak,
                    streakCount: 1,
                    totalXp: 0,
                    beans: _beans(beans: 5, nextIn: null),
                    offline: false,
                    refill: () => Future.value(
                      const RefillFailure(
                        RefillFailureReason.insufficientAmole,
                      ),
                    ),
                    onBeansChanged: (_) {},
                    loadStreak: ({required from, required to}) async =>
                        _streak(),
                    loadAmole: ({int limit = 20}) async => const [],
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('1 day streak'), findsOneWidget);
    }

    testWidgets('closes with its Close button', (tester) async {
      await open(tester);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(StatSheet), findsNothing);
    });

    testWidgets('closes with a tap outside it', (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(StatSheet), findsNothing);
    });

    for (final (width, scale) in [(320.0, 1.3), (360.0, 1.3)]) {
      testWidgets('fits $width dp at ${scale}x text', (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_Rig().build(textScale: scale));
        expect(find.text('Beans'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('countdowns under and over an hour', () {
    expect(formatCountdown(const Duration(minutes: 1, seconds: 5)), '01:05');
    expect(formatCountdown(const Duration(minutes: 30)), '30:00');
    expect(
      formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatCountdown(const Duration(seconds: -4)), '00:00');
  });
}
