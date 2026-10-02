import 'package:flutter/material.dart';

import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_tone.dart';
import '../../l10n/app_localizations.dart';

/// The five league tiers (023-weekly-leagues), lowest first, as the
/// backend names them (`backend/app/domain/league.py`). The names, icons
/// and tones are the app's own.
enum LeagueTier {
  greenBean('green_bean', 'Green Bean', Icons.eco, AppTone.primary),
  lightRoast('light_roast', 'Light Roast', Icons.local_cafe, AppTone.secondary),
  mediumRoast('medium_roast', 'Medium Roast', Icons.coffee, AppTone.tertiary),
  darkRoast('dark_roast', 'Dark Roast', Icons.coffee_maker, AppTone.neutral),
  goldenCup('golden_cup', 'Golden Cup', Icons.emoji_events, AppTone.secondary);

  const LeagueTier(this.key, this.title, this.icon, this.tone);

  final String key;

  /// The name in English; [titleIn] gives it in the app language.
  final String title;
  final IconData icon;
  final AppTone tone;

  /// The name in the app language [l].
  String titleIn(AppLocalizations l) => switch (this) {
    LeagueTier.greenBean => l.tierGreenBean,
    LeagueTier.lightRoast => l.tierLightRoast,
    LeagueTier.mediumRoast => l.tierMediumRoast,
    LeagueTier.darkRoast => l.tierDarkRoast,
    LeagueTier.goldenCup => l.tierGoldenCup,
  };

  /// The tier [key] names; an unknown one (a newer backend) reads as the
  /// lowest.
  static LeagueTier fromKey(Object? key) => LeagueTier.values.firstWhere(
    (t) => t.key == key,
    orElse: () => LeagueTier.greenBean,
  );
}

/// Whether the learner is in this week's league, and why not.
enum LeagueStatus {
  joined,

  /// No XP yet this week.
  notJoined,

  /// "Show me in leagues" is off.
  hidden;

  static LeagueStatus fromKey(Object? key) => switch (key) {
    'joined' => LeagueStatus.joined,
    'hidden' => LeagueStatus.hidden,
    _ => LeagueStatus.notJoined,
  };
}

/// One member of the learner's group, as the backend sends them: a name and
/// an initial, never an id or an email.
@immutable
class LeagueMember {
  const LeagueMember({
    required this.name,
    required this.initial,
    required this.avatarColour,
    required this.weeklyXp,
    required this.rank,
    required this.isMe,
  });

  final String name;
  final String initial;

  /// 0 to 7; [leagueAvatarColours] turns it into colours.
  final int avatarColour;
  final int weeklyXp;
  final int rank;
  final bool isMe;

  Map<String, Object?> toJson() => {
    'name': name,
    'initial': initial,
    'avatar_colour': avatarColour,
    'weekly_xp': weeklyXp,
    'rank': rank,
    'is_me': isMe,
  };

  static LeagueMember? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final name = raw['name'];
    final rank = raw['rank'];
    if (name is! String || rank is! int) return null;
    final initial = raw['initial'];
    final colour = raw['avatar_colour'];
    final xp = raw['weekly_xp'];
    return LeagueMember(
      name: name,
      initial: initial is String && initial.isNotEmpty
          ? initial
          : (name.isEmpty ? '?' : name.characters.first.toUpperCase()),
      avatarColour: colour is int ? colour : 0,
      weeklyXp: xp is int ? xp : 0,
      rank: rank,
      isMe: raw['is_me'] == true,
    );
  }
}

/// How the learner's last closed week went (shown by bolt 076).
@immutable
class LeagueResult {
  const LeagueResult({
    required this.tier,
    required this.tierAfter,
    required this.rank,
    required this.groupSize,
    required this.weeklyXp,
    required this.rewardAmole,
  });

  final LeagueTier tier;
  final LeagueTier tierAfter;

  /// `null` if the learner had switched leagues off by the time it closed.
  final int? rank;
  final int groupSize;
  final int weeklyXp;
  final int rewardAmole;

  Map<String, Object?> toJson() => {
    'tier': tier.key,
    'tier_after': tierAfter.key,
    'rank': rank,
    'group_size': groupSize,
    'weekly_xp': weeklyXp,
    'reward_amole': rewardAmole,
  };

  static LeagueResult? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    int number(String key) => raw[key] is int ? raw[key] as int : 0;
    final rank = raw['rank'];
    return LeagueResult(
      tier: LeagueTier.fromKey(raw['tier']),
      tierAfter: LeagueTier.fromKey(raw['tier_after']),
      rank: rank is int ? rank : null,
      groupSize: number('group_size'),
      weeklyXp: number('weekly_xp'),
      rewardAmole: number('reward_amole'),
    );
  }
}

/// `GET /api/v1/leagues/current`: the learner's tier, whether they are in
/// this week's league, and their group in rank order.
@immutable
class CurrentLeague {
  const CurrentLeague({
    required this.tier,
    required this.status,
    required this.weekEndsAt,
    required this.promoteCount,
    required this.demoteCount,
    required this.rewards,
    required this.members,
    this.lastResult,
  });

  final LeagueTier tier;
  final LeagueStatus status;
  final DateTime weekEndsAt;

  /// How many places at the top move up, and at the bottom move down.
  final int promoteCount;
  final int demoteCount;

  /// Amole for 1st, 2nd and 3rd when the week closes.
  final List<int> rewards;
  final List<LeagueMember> members;
  final LeagueResult? lastResult;

  /// The Amole the member in [rank] earns if the week ends now, or 0.
  int rewardFor(int rank) =>
      rank >= 1 && rank <= rewards.length ? rewards[rank - 1] : 0;

  /// The same shape [fromJson] reads, for the copy saved on the phone.
  Map<String, Object?> toJson() => {
    'tier': tier.key,
    'status': switch (status) {
      LeagueStatus.joined => 'joined',
      LeagueStatus.notJoined => 'not_joined',
      LeagueStatus.hidden => 'hidden',
    },
    'week_ends_at': weekEndsAt.toIso8601String(),
    'promote_count': promoteCount,
    'demote_count': demoteCount,
    'rewards': rewards,
    'members': [for (final m in members) m.toJson()],
    'last_result': lastResult?.toJson(),
  };

  /// `null` when [raw] isn't a league: no tier and end time to show.
  /// Anything else missing or unexpected reads as nothing, so a newer
  /// backend never breaks an older app.
  static CurrentLeague? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final endsAt = raw['week_ends_at'];
    final parsedEnd = endsAt is String ? DateTime.tryParse(endsAt) : null;
    if (raw['tier'] is! String || parsedEnd == null) return null;
    int count(String key) => raw[key] is int ? raw[key] as int : 0;
    final rewards = raw['rewards'];
    final members = raw['members'];
    return CurrentLeague(
      tier: LeagueTier.fromKey(raw['tier']),
      status: LeagueStatus.fromKey(raw['status']),
      weekEndsAt: parsedEnd.toUtc(),
      promoteCount: count('promote_count'),
      demoteCount: count('demote_count'),
      rewards: rewards is List ? rewards.whereType<int>().toList() : const [],
      members: members is List
          ? (members.map(LeagueMember.fromJson).nonNulls.toList()
              ..sort((a, b) => a.rank.compareTo(b.rank)))
          : const [],
      lastResult: LeagueResult.fromJson(raw['last_result']),
    );
  }
}

/// An avatar's circle and letter colours.
typedef AvatarColours = ({Color face, Color letter});

/// The eight avatar colours in [p], one per index the backend sends:
/// each tone's filled badge and its light face, so both themes are covered
/// with no colours of their own. `palette_contrast` style checks keep the
/// letter readable (league tests).
List<AvatarColours> leagueAvatarColours(AppPalette p) => [
  for (final tone in AppTone.values)
    (face: tone.colorsIn(p).fill, letter: tone.colorsIn(p).onFill),
  for (final tone in AppTone.values)
    (face: tone.colorsIn(p).surface, letter: tone.colorsIn(p).ink),
];
