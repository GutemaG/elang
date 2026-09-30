import 'package:flutter/widgets.dart';

import '../services/app_config_api.dart';
import '../services/session_api.dart';
import 'known_settings.dart';
import 'remote_settings_store.dart';

/// The account settings and app configuration the app reads
/// (022-light-and-dark-themes, FR-10), in one place.
///
/// It starts from the copies saved on the phone, so it works offline, and
/// is brought up to date by each session check ([applySession]) and a
/// configuration fetch ([refreshConfig]); each update is saved and heard by
/// listeners. Read it with `RemoteSettingsScope.of(context)`.
class RemoteSettingsController extends ChangeNotifier {
  RemoteSettingsController({
    required this._store,
    required this._configApi,
    RemoteSettings? account,
    RemoteSettings? config,
  }) : _account = account ?? RemoteSettings.empty,
       _config = config ?? RemoteSettings.empty;

  /// A controller starting from the saved copies, read before the first
  /// frame.
  static Future<RemoteSettingsController> load({
    required RemoteSettingsStore store,
    required AppConfigApi configApi,
  }) async => RemoteSettingsController(
    store: store,
    configApi: configApi,
    account: (await store.readAccount())?.settings,
    config: await store.readConfig(),
  );

  final RemoteSettingsStore _store;
  final AppConfigApi _configApi;

  RemoteSettings _account;
  RemoteSettings _config;

  /// The signed-in learner's settings: read one with
  /// `account.get(AccountSettings.<name>)`.
  RemoteSettings get account => _account;

  /// The app-wide values: read one with `config.get(AppConfig.<name>)`.
  RemoteSettings get config => _config;

  /// Takes the settings a session check returned, and keeps them.
  Future<void> applySession(SessionUser user) async {
    final received = RemoteSettings(user.settings);
    if (received != _account) {
      _account = received;
      notifyListeners();
    }
    await _store.saveAccount(user.id, received);
  }

  /// Fetches the app configuration; offline or on an error, the last copy
  /// stays. Never throws.
  Future<void> refreshConfig() async {
    final fetched = await _configApi.fetch();
    if (fetched == null) return;
    final received = RemoteSettings(fetched);
    if (received != _config) {
      _config = received;
      notifyListeners();
    }
    await _store.saveConfig(received);
  }

  /// Forgets the account settings, on the phone too: called when the
  /// signed-in account may have changed (sign-out, or a new sign-in), so
  /// one learner's settings are never read for another.
  Future<void> forgetAccount() async {
    if (_account != RemoteSettings.empty) {
      _account = RemoteSettings.empty;
      notifyListeners();
    }
    await _store.clearAccount();
  }
}

/// Hands the [RemoteSettingsController] down the tree, as `AppearanceScope`
/// does the Appearance choice; a widget that reads it rebuilds on updates.
class RemoteSettingsScope extends InheritedNotifier<RemoteSettingsController> {
  const RemoteSettingsScope({
    super.key,
    required RemoteSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static RemoteSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RemoteSettingsScope>();
    assert(scope != null, 'No RemoteSettingsScope above this widget');
    return scope!.notifier!;
  }
}
