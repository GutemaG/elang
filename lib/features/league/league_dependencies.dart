import '../../shared/services/secure_storage_service.dart';
import '../../shared/services/session_repository.dart';
import '../../shared/settings/account_settings_api.dart';
import 'league_api.dart';
import 'league_store.dart';

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
}
