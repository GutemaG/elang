import 'dart:convert';

import '../services/secure_storage_service.dart';
import 'known_settings.dart';

/// The last account settings and app configuration received, kept on the
/// phone so the app reads them offline (022-light-and-dark-themes, FR-10).
///
/// Account settings are saved with the id of the account they belong to,
/// and forgotten when the signed-in account changes
/// (`RemoteSettingsController.forgetAccount`), so one learner's are never
/// read for another. A copy that can't be read back counts as none.
class RemoteSettingsStore {
  RemoteSettingsStore({required this._storage});

  static const String _accountKey = 'account_settings';
  static const String _configKey = 'app_config';

  final SecureStorageService _storage;

  /// The saved account settings, with the id of the account they belong
  /// to; `null` when none are saved or the copy is unreadable.
  Future<({String userId, RemoteSettings settings})?> readAccount() async {
    final decoded = await _readJson(_accountKey);
    if (decoded is! Map<String, dynamic>) return null;
    final userId = decoded['user_id'];
    final settings = decoded['settings'];
    if (userId is! String || settings is! Map<String, dynamic>) return null;
    return (userId: userId, settings: RemoteSettings(settings));
  }

  Future<void> clearAccount() => _storage.delete(_accountKey);

  Future<void> saveAccount(String userId, RemoteSettings settings) =>
      _storage.write(
        _accountKey,
        jsonEncode({'user_id': userId, 'settings': settings.values}),
      );

  /// The saved configuration, or empty when none is saved or the copy is
  /// unreadable.
  Future<RemoteSettings> readConfig() async {
    final decoded = await _readJson(_configKey);
    return decoded is Map<String, dynamic>
        ? RemoteSettings(decoded)
        : RemoteSettings.empty;
  }

  Future<void> saveConfig(RemoteSettings config) =>
      _storage.write(_configKey, jsonEncode(config.values));

  Future<Object?> _readJson(String key) async {
    try {
      final raw = await _storage.read(key);
      return raw == null ? null : jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
