/// The streak calendar's and the Amole list's data
/// (013-stat-pill-interactions, bolt 061), from `GET /streak/history` and
/// `GET /amole/transactions` (bolt 059).
library;

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

  /// The ledger's own name for why, e.g. `bean_refill`; see [reason].
  final String source;
  final DateTime createdAt;

  /// What the learner reads for [source]. A source this app does not know
  /// yet (the server added one) reads as plain "Amole".
  String get reason => switch (source) {
    'wallet_created' => 'Welcome bonus',
    'migration_backfill' => 'Starting balance',
    'lesson_completion' => 'Lesson finished',
    'perfect_lesson' => 'Perfect lesson',
    'streak_milestone_7' => '7-day streak',
    'streak_milestone_30' => '30-day streak',
    'bean_refill' => 'Bean refill',
    'practice_session' => 'Practice session',
    'league_reward' => 'League reward',
    _ => 'Amole',
  };

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
