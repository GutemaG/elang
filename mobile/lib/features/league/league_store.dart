import 'dart:convert';

import '../../shared/services/secure_storage_service.dart';
import 'league_models.dart';

/// The last league fetched, kept on the phone so the league screen works
/// offline (023-weekly-leagues, story 006), and whether the learner has
/// seen the note that others see their first name (story 007).
///
/// Both belong to one account: [forget] runs when the signed-in account
/// changes, so one learner's league is never shown to another.
class LeagueStore {
  LeagueStore({required this._storage});

  static const String _leagueKey = 'league_current';
  static const String _noticeKey = 'league_notice_seen';

  final SecureStorageService _storage;

  /// The saved league and when it was fetched; `null` when nothing is
  /// saved or the copy can't be read back.
  Future<({CurrentLeague league, DateTime savedAt})?> read() async {
    try {
      final raw = await _storage.read(_leagueKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final savedAt = decoded['saved_at'];
      final league = CurrentLeague.fromJson(decoded['league']);
      final parsed = savedAt is String ? DateTime.tryParse(savedAt) : null;
      if (league == null || parsed == null) return null;
      return (league: league, savedAt: parsed);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(CurrentLeague league, DateTime savedAt) => _storage.write(
    _leagueKey,
    jsonEncode({
      'saved_at': savedAt.toUtc().toIso8601String(),
      'league': league.toJson(),
    }),
  );

  Future<bool> noticeSeen() async => await _storage.read(_noticeKey) == '1';

  Future<void> markNoticeSeen() => _storage.write(_noticeKey, '1');

  Future<void> forget() async {
    await _storage.delete(_leagueKey);
    await _storage.delete(_noticeKey);
  }
}
