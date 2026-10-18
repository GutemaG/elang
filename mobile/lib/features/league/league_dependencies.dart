import 'package:flutter/widgets.dart';

import '../../shared/services/secure_storage_service.dart';
import '../../shared/services/session_repository.dart';
import '../../shared/settings/account_settings_api.dart';
import 'league_api.dart';
import 'league_models.dart';
import 'league_store.dart';
import 'widgets/league_result_sheet.dart';

/// What the weekly league needs (023-weekly-leagues), built once at start-up
/// like the other dependency bundles. The league copy on the phone is
/// forgotten whenever the signed-in account changes.
class LeagueDependencies {
  LeagueDependencies({
    required SecureStorageService storage,
    required SessionRepository sessionRepository,
    LeagueApi? api,
    AccountSettingsApi? accountSettingsApi,
  }) : store = LeagueStore(storage: storage),
       api = api ?? HttpLeagueApi(sessionRepository: sessionRepository),
       accountSettingsApi =
           accountSettingsApi ??
           HttpAccountSettingsApi(sessionRepository: sessionRepository) {
    sessionRepository.addAccountChangedListener(store.forget);
  }

  final LeagueStore store;
  final LeagueApi api;
  final AccountSettingsApi accountSettingsApi;

  bool _resultShown = false;

  /// Shows [league]'s last-week result if it has one (story 008), once per
  /// run whichever screen gets it first, then tells the backend it was
  /// seen. If that fails (offline), the backend still offers it, and it is
  /// shown again on the next run.
  Future<void> showResultOnce(
    BuildContext context,
    CurrentLeague league,
  ) async {
    final result = league.lastResult;
    if (result == null || _resultShown) return;
    _resultShown = true;
    await showLeagueResultSheet(context, result);
    try {
      await api.markResultSeen();
    } on LeagueApiException {
      // Offered again next time.
    }
  }
}
