import 'package:flutter/foundation.dart';

import 'league_api.dart';
import 'league_models.dart';
import 'league_store.dart';

/// Where the league screen's data stands.
enum LeagueLoadState {
  /// Nothing to show yet.
  loading,

  /// Just fetched.
  ready,

  /// Offline: the copy saved on the phone, from [LeagueController.savedAt].
  saved,

  /// Offline with nothing saved.
  unavailable,
}

/// Loads the learner's league for the league screen (023-weekly-leagues,
/// story 006): the saved copy at once, then a fresh one, which is saved in
/// turn. A failed fetch keeps whatever is showing, so offline is never an
/// error.
class LeagueController extends ChangeNotifier {
  LeagueController({
    required this._api,
    required this._store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LeagueApi _api;
  final LeagueStore _store;
  final DateTime Function() _clock;

  LeagueLoadState _state = LeagueLoadState.loading;
  CurrentLeague? _league;
  DateTime? _savedAt;
  bool _noticeSeen = true;
  bool _disposed = false;

  LeagueLoadState get state => _state;
  CurrentLeague? get league => _league;

  /// When the league being shown was fetched.
  DateTime? get savedAt => _savedAt;

  /// Whether to show the note that others see the learner's first name:
  /// only with a ranking, until "Got it".
  bool get showNotice => !_noticeSeen && _league?.status == LeagueStatus.joined;

  DateTime now() => _clock();

  Future<void> load() async {
    _noticeSeen = await _store.noticeSeen();
    final saved = await _store.read();
    if (saved != null && _league == null) {
      _league = saved.league;
      _savedAt = saved.savedAt;
      _state = LeagueLoadState.saved;
      _notify();
    }
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final league = await _api.current();
      final fetchedAt = _clock();
      _league = league;
      _savedAt = fetchedAt;
      _state = LeagueLoadState.ready;
      _notify();
      await _store.save(league, fetchedAt);
    } on LeagueApiException {
      // Whatever is showing stays, now marked as from [savedAt].
      _state = _league == null
          ? LeagueLoadState.unavailable
          : LeagueLoadState.saved;
      _notify();
    }
  }

  /// "Got it" on the first-name note, or the switch turned off in it.
  Future<void> dismissNotice() async {
    _noticeSeen = true;
    _notify();
    await _store.markNoticeSeen();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
