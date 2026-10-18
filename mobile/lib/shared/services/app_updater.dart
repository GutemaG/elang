import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The store an app is updated from.
enum UpdateStore { googlePlay, appStore }

/// What Google Play has for this phone.
enum PlayUpdate {
  /// Nothing newer, or Play can't tell (a debug or sideloaded build).
  none,

  /// A newer build this phone may take.
  available,

  /// A newer build already downloaded, waiting for a restart.
  downloaded,
}

/// The phone's side of app updates: which build this is, and the store
/// that updates it. Kept behind an interface so tests use a fake.
abstract class AppUpdater {
  /// The store this app updates from, or `null` (the web, desktops) where
  /// nothing is checked.
  UpdateStore? get store;

  /// This app's build number (the `+N` in `pubspec.yaml`), or `null` if it
  /// can't be read.
  Future<int?> installedBuild();

  /// Android: what Google Play has for this phone. Never throws.
  Future<PlayUpdate> checkPlay();

  /// Android: Play's flexible update. Play asks the learner, then downloads
  /// while they keep learning; `true` once the download is done. Never
  /// throws.
  Future<bool> downloadInBackground();

  /// Android: installs the downloaded update, which restarts the app.
  Future<void> installDownloaded();

  /// Android: Play's full-screen update; `false` if Play couldn't start it
  /// or the learner backed out. Never throws.
  Future<bool> updateNow();

  /// Opens this app's store page: [url] if given, else Google Play's page
  /// on Android. `false` if there is none to open. Never throws.
  Future<bool> openStore({String url = ''});
}

/// The real [AppUpdater]: Google Play's in-app updates on Android, the App
/// Store page on iOS.
class StoreAppUpdater implements AppUpdater {
  StoreAppUpdater({TargetPlatform? platform, bool isWeb = kIsWeb})
    : store = isWeb
          ? null
          : switch (platform ?? defaultTargetPlatform) {
              TargetPlatform.android => UpdateStore.googlePlay,
              TargetPlatform.iOS => UpdateStore.appStore,
              _ => null,
            };

  @override
  final UpdateStore? store;

  @override
  Future<int?> installedBuild() async {
    try {
      return int.tryParse((await PackageInfo.fromPlatform()).buildNumber);
    } on Object {
      return null;
    }
  }

  @override
  Future<PlayUpdate> checkPlay() async {
    if (store != UpdateStore.googlePlay) return PlayUpdate.none;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.installStatus == InstallStatus.downloaded) {
        return PlayUpdate.downloaded;
      }
      return info.updateAvailability == UpdateAvailability.updateAvailable &&
              info.flexibleUpdateAllowed
          ? PlayUpdate.available
          : PlayUpdate.none;
    } on Object {
      // Not installed from Play, or Play is missing.
      return PlayUpdate.none;
    }
  }

  @override
  Future<bool> downloadInBackground() async {
    try {
      return await InAppUpdate.startFlexibleUpdate() == AppUpdateResult.success;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> installDownloaded() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } on Object {
      // Play installs it on the next launch instead.
    }
  }

  @override
  Future<bool> updateNow() async {
    if (store != UpdateStore.googlePlay) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable &&
          info.updateAvailability !=
              UpdateAvailability.developerTriggeredUpdateInProgress) {
        return false;
      }
      return await InAppUpdate.performImmediateUpdate() ==
          AppUpdateResult.success;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> openStore({String url = ''}) async {
    try {
      var address = url;
      if (address.isEmpty && store == UpdateStore.googlePlay) {
        final package = (await PackageInfo.fromPlatform()).packageName;
        address = 'https://play.google.com/store/apps/details?id=$package';
      }
      if (address.isEmpty) return false;
      return await launchUrl(
        Uri.parse(address),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      return false;
    }
  }
}
