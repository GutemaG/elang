import 'package:flutter/material.dart';

import '../../../shared/models/stat_history.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_status.dart';

/// A month of days, marking those with a finished lesson
/// (013-stat-pill-interactions, bolt 061). Opens on [today]'s month; the
/// arrows go back [monthsBack] months and no further, and never past this
/// month.
///
/// Days are UTC calendar days, the rule the streak itself uses, so the
/// calendar always agrees with the streak number.
class StreakCalendar extends StatefulWidget {
  const StreakCalendar({
    super.key,
    required this.history,
    required this.today,
    this.monthsBack = 5,
  });

  final StreakHistory history;

  /// Today's UTC day.
  final DateTime today;
  final int monthsBack;

  /// The first day of the earliest month shown, for asking the server for
  /// exactly the days the calendar can show.
  static DateTime firstDayShown(DateTime today, {int monthsBack = 5}) =>
      DateTime.utc(today.year, today.month - monthsBack, 1);

  @override
  State<StreakCalendar> createState() => _StreakCalendarState();
}

/// How a day is drawn and read.
enum _DayKind { practised, missed, notYet, beforeJoining }

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _StreakCalendarState extends State<StreakCalendar> {
  /// Months before this one: 0 is [StreakCalendar.today]'s month.
  int _back = 0;

  DateTime get _month =>
      DateTime.utc(widget.today.year, widget.today.month - _back, 1);

  void _go(int back) => setState(() => _back = back);

  _DayKind _kindOf(DateTime day) {
    if (day.isAfter(widget.today)) return _DayKind.notYet;
    if (widget.history.practised(day)) return _DayKind.practised;
    if (day.isBefore(widget.history.joinedOn)) return _DayKind.beforeJoining;
    return _DayKind.missed;
  }

  @override
  Widget build(BuildContext context) {
    final month = _month;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    // Monday first: blanks before the 1st.
    final leading = month.weekday - DateTime.monday;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= days; d++) DateTime.utc(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Previous month',
              plain: true,
              onPressed: _back < widget.monthsBack
                  ? () => _go(_back + 1)
                  : null,
            ),
            Expanded(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                key: const ValueKey('streak-calendar-month'),
                textAlign: TextAlign.center,
                style: AppTypography.labelLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Next month',
              plain: true,
              onPressed: _back > 0 ? () => _go(_back - 1) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2xs),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final initial in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Text(
                    initial,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space2xs),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(
            children: [
              for (final day in cells.sublist(row * 7, row * 7 + 7))
                Expanded(
                  child: day == null
                      ? const SizedBox.shrink()
                      : _Day(
                          day: day,
                          kind: _kindOf(day),
                          isToday: day == widget.today,
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.day, required this.kind, required this.isToday});

  final DateTime day;
  final _DayKind kind;
  final bool isToday;

  String get _label {
    final name = '${day.day} ${_monthNames[day.month - 1]}';
    final state = switch (kind) {
      _DayKind.practised => 'practised',
      _DayKind.missed => 'not practised',
      _DayKind.notYet => 'not yet',
      _DayKind.beforeJoining => 'before you joined',
    };
    return isToday ? '$name, today, $state' : '$name, $state';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: CalendarDay(
          key: ValueKey('streak-day-${day.day}'),
          day: day.day,
          label: _label,
          filled: kind == _DayKind.practised,
          ringed: isToday,
          faded: kind == _DayKind.notYet || kind == _DayKind.beforeJoining,
        ),
      ),
    );
  }
}
