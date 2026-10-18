import 'package:flutter/foundation.dart';

/// A setting the app knows (022-light-and-dark-themes, FR-10): its key, as
/// the backend's registry names it (`backend/app/domain/settings.py`), and
/// the default the app uses when the value is missing or of another type.
///
/// [T] is `bool`, `int` or `String`, as on the backend.
@immutable
class KnownSetting<T extends Object> {
  const KnownSetting(this.key, this.defaultValue);

  final String key;
  final T defaultValue;

  /// This setting's value in [values], or [defaultValue] when it is missing
  /// or not a [T].
  T readFrom(Map<String, Object?> values) {
    final value = values[key];
    return value is T ? value : defaultValue;
  }
}

/// **To add an account setting**, add one line here, e.g.
/// `static const reduceMotion = KnownSetting<bool>('reduce_motion', false);`
/// then read it where it is used: `RemoteSettingsScope.of(context)
/// .account.get(AccountSettings.reduceMotion)`.
///
/// The backend's `ACCOUNT_SETTINGS` must list the same key.
abstract final class AccountSettings {
  /// Off keeps the learner out of weekly leagues, so nobody sees their name
  /// (023-weekly-leagues, story 007).
  static const showInLeagues = KnownSetting<bool>('show_in_leagues', true);

  /// The language the app's own words are shown in, `""` until chosen
  /// (024-app-localization, story 006). The phone's copy is the one the app
  /// draws in (`AppLanguageController`); this one follows the learner to a
  /// new phone.
  static const appLanguage = KnownSetting<String>('app_language', '');
}

/// **To add an app-wide value**, add one line here, then read it with
/// `RemoteSettingsScope.of(context).config.get(AppConfig.<name>)`.
///
/// The backend's `APP_CONFIG` must list the same key.
abstract final class AppConfig {
  /// The oldest Android build (versionCode) still allowed to run; an older
  /// app shows "Update needed". 0 lets every build run.
  static const minBuildAndroid = KnownSetting<int>('min_build_android', 0);

  /// The oldest iOS build still allowed to run.
  static const minBuildIos = KnownSetting<int>('min_build_ios', 0);

  /// The newest iOS build in the App Store: an older app is offered it.
  /// Android asks Google Play instead.
  static const latestBuildIos = KnownSetting<int>('latest_build_ios', 0);

  /// The iOS app's App Store page, `""` until it is listed.
  static const iosStoreUrl = KnownSetting<String>('ios_store_url', '');
}

/// A snapshot of settings as received: read through [get], so a missing or
/// wrong-typed value reads as the app's default and a key the app doesn't
/// know is simply never read. An older app keeps working when the backend
/// adds a key, and a newer one against a backend that sends nothing.
@immutable
class RemoteSettings {
  RemoteSettings(Map<String, Object?> values)
    : values = Map.unmodifiable(values);

  static final RemoteSettings empty = RemoteSettings(const {});

  /// Everything received, known or not; saved as is for offline use.
  final Map<String, Object?> values;

  T get<T extends Object>(KnownSetting<T> setting) => setting.readFrom(values);

  @override
  bool operator ==(Object other) =>
      other is RemoteSettings && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
