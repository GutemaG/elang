// The daily reminder's schedule (021-daily-reminder, bolt 063): 8 pm on the
// phone's clock for the next week, skipping the practised streak day, with
// only the next reminder naming the streak.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:elang/shared/services/reminders/reminder_plan.dart';

void main() {
  late tz.Location addis;
  late tz.Location newYork;
  late tz.Location london;

  setUpAll(() {
    tzdata.initializeTimeZones();
    addis = tz.getLocation('Africa/Addis_Ababa');
    newYork = tz.getLocation('America/New_York');
    london = tz.getLocation('Europe/London');
  });

  List<String> localTimes(List<PlannedReminder> reminders) => [
    for (final r in reminders)
      '${r.at.month}-${r.at.day} ${r.at.hour}:${r.at.minute}',
  ];

  test('one reminder at 8 pm local for each of the next 7 days', () {
    final now = tz.TZDateTime(addis, 2026, 9, 30, 9);

    final plan = planReminders(now: now, streakCount: 0);

    expect(localTimes(plan), [
      '9-30 20:0',
      '10-1 20:0',
      '10-2 20:0',
      '10-3 20:0',
      '10-4 20:0',
      '10-5 20:0',
      '10-6 20:0',
    ]);
    // 8 pm in Addis Ababa is 5 pm UTC.
    expect(plan.first.at.toUtc(), DateTime.utc(2026, 9, 30, 17));
    expect(
      [for (final r in plan) r.id],
      [20260930, 20261001, 20261002, 20261003, 20261004, 20261005, 20261006],
    );
  });

  test("after 8 pm, today's has passed and is left out", () {
    final now = tz.TZDateTime(addis, 2026, 9, 30, 20);

    final plan = planReminders(now: now, streakCount: 0);

    expect(plan, hasLength(6));
    expect(plan.first.id, 20261001);
  });

  test('a practised streak day is skipped; later days stay', () {
    final now = tz.TZDateTime(addis, 2026, 9, 30, 9);

    final plan = planReminders(
      now: now,
      streakCount: 4,
      practisedDay: DateTime.utc(2026, 9, 30),
    );

    expect(plan.first.id, 20261001);
    expect(plan, hasLength(6));
  });

  test('a lesson just after midnight in Addis counts for the day before', () {
    // 01:30 on 1 October in Addis Ababa is still 30 September in UTC, so
    // it skips the 30th's reminder (already past), not the 1st's.
    final now = tz.TZDateTime(addis, 2026, 10, 1, 1, 30);

    final plan = planReminders(now: now, streakCount: 4, practisedDay: now);

    expect(plan.first.id, 20261001);
  });

  test('west of UTC, 8 pm falls on the next UTC day', () {
    // 8 pm in New York (EDT) is midnight UTC: the reminder on the 30th
    // guards the streak day of 1 October.
    final now = tz.TZDateTime(newYork, 2026, 9, 30, 9);

    expect(
      planReminders(
        now: now,
        streakCount: 2,
        practisedDay: DateTime.utc(2026, 9, 30),
      ).first.id,
      20260930,
    );
    expect(
      planReminders(
        now: now,
        streakCount: 2,
        practisedDay: DateTime.utc(2026, 10, 1),
      ).first.id,
      20261001,
    );
  });

  test('stays at 8 pm across a daylight-saving change', () {
    // Britain moves its clocks back on 25 October 2026.
    final now = tz.TZDateTime(london, 2026, 10, 22, 9);

    final plan = planReminders(now: now, streakCount: 0);

    expect(plan.every((r) => r.at.hour == 20 && r.at.minute == 0), isTrue);
    expect(plan[1].at.toUtc().hour, 19); // 23 Oct, BST
    expect(plan[4].at.toUtc().hour, 20); // 26 Oct, GMT
  });

  test('only the next reminder names the streak', () {
    final now = tz.TZDateTime(addis, 2026, 9, 30, 9);

    final plan = planReminders(now: now, streakCount: 12);

    expect(plan.first.title, 'Keep your 12-day streak going');
    expect(plan.first.body, 'A quick lesson is enough.');
    for (final later in plan.skip(1)) {
      expect(later.title, "Time for today's lesson");
      expect(later.body, 'A quick lesson keeps you going.');
    }
  });

  test('the message for 1 day and for none', () {
    expect(reminderMessage(1).$1, 'Keep your 1-day streak going');
    expect(reminderMessage(0).$1, "Time for today's lesson");
    expect(reminderMessage(-1).$1, "Time for today's lesson");
  });

  test('ids are unique across a month and year end', () {
    final now = tz.TZDateTime(addis, 2026, 12, 29, 9);

    final plan = planReminders(now: now, streakCount: 0);

    expect(
      [for (final r in plan) r.id],
      [20261229, 20261230, 20261231, 20270101, 20270102, 20270103, 20270104],
    );
  });
}
