import 'package:timezone/timezone.dart' as tz;

import '../../models/stat_history.dart';

/// The hour of the day, on the phone's own clock, a reminder goes off
/// (021-daily-reminder, D2).
const int reminderHour = 20;

/// How many days ahead reminders are kept scheduled, so a closed app still
/// reminds for a week and then stops (021-daily-reminder, D5).
const int reminderDays = 7;

/// One reminder the phone should show.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// The local date as a number (20261001), so each day has its own id.
  final int id;
  final tz.TZDateTime at;
  final String title;
  final String body;

  @override
  String toString() => 'PlannedReminder($id, $at, $title)';
}

/// The reminders for the next [reminderDays] days at [reminderHour] in
/// [now]'s time zone (021-daily-reminder, bolt 063).
///
/// - A time already past is left out.
/// - A day whose streak day (the UTC date of that evening's reminder, the
///   streak's own day rule) is [practisedDay] is left out.
/// - Only the first reminder names the streak: if that day passes without
///   a lesson the streak is gone, so naming it on later days would be
///   wrong.
List<PlannedReminder> planReminders({
  required tz.TZDateTime now,
  required int streakCount,
  DateTime? practisedDay,
}) {
  final practised = practisedDay == null ? null : utcDay(practisedDay);
  final reminders = <PlannedReminder>[];
  for (var i = 0; i < reminderDays; i++) {
    final at = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + i,
      reminderHour,
    );
    if (!at.isAfter(now)) continue;
    if (utcDay(at) == practised) continue;
    final (title, body) = reminders.isEmpty
        ? reminderMessage(streakCount)
        : reminderMessage(0);
    reminders.add(
      PlannedReminder(
        id: at.year * 10000 + at.month * 100 + at.day,
        at: at,
        title: title,
        body: body,
      ),
    );
  }
  return reminders;
}

/// The reminder's title and body for a streak of [streakCount] days.
(String, String) reminderMessage(int streakCount) {
  if (streakCount <= 0) {
    return ("Time for today's lesson", 'A quick lesson keeps you going.');
  }
  return (
    'Keep your $streakCount-day streak going',
    'A quick lesson is enough.',
  );
}
