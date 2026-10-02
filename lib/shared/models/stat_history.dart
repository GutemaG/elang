/// The streak calendar's and the Amole list's data
/// (013-stat-pill-interactions, bolt 061), from `GET /streak/history` and
/// `GET /amole/transactions` (bolt 059).
library;

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';

/// The practised days in a range, with the streak as the dashboard shows
/// it. Every date is a UTC calendar day, the rule the streak itself uses.
class StreakHistory {
  StreakHistory({
    required Iterable<DateTime> practisedDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.joinedOn,
  }) : practisedDays = {for (final day in practisedDays) utcDay(day)};

  /// Days (UTC midnight) with a finished lesson that was not a replay.
  final Set<DateTime> practisedDays;
  final int currentStreak;
  final int longestStreak;

  /// The UTC day the account was made; days before it were not possible.
  final DateTime joinedOn;

  bool practised(DateTime day) => practisedDays.contains(utcDay(day));

  /// `null` for anything that is not the endpoint's shape.
  static StreakHistory? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final days = raw['practised_days'];
    final current = raw['current_streak'];
    final longest = raw['longest_streak'];
    final joined = _parseDay(raw['joined_on']);
    if (days is! List || current is! int || longest is! int || joined == null) {
      return null;
    }
    return StreakHistory(
      practisedDays: [for (final day in days) ?_parseDay(day)],
      currentStreak: current,
      longestStreak: longest,
      joinedOn: joined,
    );
  }
}

/// [moment]'s UTC calendar day, as UTC midnight.
DateTime utcDay(DateTime moment) {
  final utc = moment.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

DateTime? _parseDay(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed == null
      ? null
      : DateTime.utc(parsed.year, parsed.month, parsed.day);
}

/// One Amole ledger entry: earned (positive) or spent (negative).
class AmoleEntry {
  const AmoleEntry({
    required this.amount,
    required this.source,
    required this.createdAt,
  });

  final int amount;

  /// The ledger's own name for why, e.g. `bean_refill`; see [reasonIn].
  final String source;
  final DateTime createdAt;

  /// What the learner reads for [source], in the app language [l]. A
  /// source this app does not know yet (the server added one) reads as
  /// plain "Amole".
  String reasonIn(AppLocalizations l) => switch (source) {
    'wallet_created' => l.reasonWelcome,
    'migration_backfill' => l.reasonStartingBalance,
    'lesson_completion' => l.reasonLessonFinished,
    'perfect_lesson' => l.reasonPerfectLesson,
    'streak_milestone_7' => l.reasonStreak7,
    'streak_milestone_30' => l.reasonStreak30,
    'bean_refill' => l.reasonBeanRefill,
    'practice_session' => l.reasonPractice,
    'league_reward' => l.reasonLeagueReward,
    _ => l.amole,
  };

  /// [reasonIn] English.
  String get reason => reasonIn(AppLocalizationsEn());

  /// `null` for anything that is not one entry.
  static AmoleEntry? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final amount = raw['amount'];
    final source = raw['source'];
    final created = raw['created_at'];
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    if (amount is! int || source is! String || createdAt == null) return null;
    return AmoleEntry(amount: amount, source: source, createdAt: createdAt);
  }
}
