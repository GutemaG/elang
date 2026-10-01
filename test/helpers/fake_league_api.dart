import 'package:elang/features/league/league_api.dart';
import 'package:elang/features/league/league_models.dart';
import 'package:elang/shared/settings/account_settings_api.dart';

/// A league response as the backend sends it, for tests.
Map<String, Object?> leagueJson({
  String tier = 'light_roast',
  String status = 'joined',
  String weekEndsAt = '2026-10-05T00:00:00Z',
  int promote = 2,
  int demote = 2,
  int members = 8,
  int me = 3,
  Map<String, Object?>? lastResult,
}) => {
  'tier': tier,
  'status': status,
  'week_ends_at': weekEndsAt,
  'promote_count': promote,
  'demote_count': demote,
  'rewards': [100, 60, 40],
  'members': [
    for (var i = 1; i <= members; i++)
      {
        'name': i == me ? 'Abebe' : 'Learner ${1000 + i}',
        'initial': i == me ? 'A' : 'L',
        'avatar_colour': i % 8,
        'weekly_xp': 100 - i * 10,
        'rank': i,
        'is_me': i == me,
      },
  ],
  'last_result': lastResult,
};

CurrentLeague league({
  String status = 'joined',
  int promote = 2,
  int demote = 2,
  int members = 8,
  String tier = 'light_roast',
}) => CurrentLeague.fromJson(
  leagueJson(
    status: status,
    promote: promote,
    demote: demote,
    members: members,
    tier: tier,
  ),
)!;

/// Answers [current] with [next], or throws when [offline].
class FakeLeagueApi implements LeagueApi {
  FakeLeagueApi([CurrentLeague? next]) : next = next ?? league();

  CurrentLeague next;
  bool offline = false;
  int calls = 0;

  @override
  Future<CurrentLeague> current() async {
    calls++;
    if (offline) throw const LeagueApiException('offline');
    return next;
  }

  /// How often the last-week result was marked seen.
  int seenCalls = 0;

  @override
  Future<void> markResultSeen() async {
    seenCalls++;
    if (offline) throw const LeagueApiException('offline');
  }
}

/// Saves whatever it is given, or fails when [fail].
class FakeAccountSettingsApi implements AccountSettingsApi {
  final List<Map<String, Object?>> updates = [];
  final Map<String, Object?> stored = {'show_in_leagues': true};
  bool fail = false;

  @override
  Future<Map<String, Object?>> update(Map<String, Object?> changes) async {
    updates.add(changes);
    if (fail) throw const AccountSettingsException('offline');
    stored.addAll(changes);
    return Map.of(stored);
  }
}
