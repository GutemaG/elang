import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/l10n/app_language.dart';
import '../../shared/services/app_updater.dart';
import '../../shared/services/secure_storage_service.dart';
import '../../shared/settings/known_settings.dart';
import '../../shared/settings/remote_settings_controller.dart';
import 'update_required_screen.dart';

/// What [AppUpdateGate] needs, handed to the app root by `main`.
class AppUpdates {
  const AppUpdates({
    required this.updater,
    required this.settings,
    required this.storage,
  });

  final AppUpdater updater;
  final RemoteSettingsController settings;
  final SecureStorageService storage;
}

/// Keeps the app up to date, around every screen (`MaterialApp.builder`):
///
/// - **Required:** a build older than the backend's minimum for its store
///   (`min_build_android`, `min_build_ios`) shows [UpdateRequiredScreen]
///   in place of the app, offline too, from the configuration saved on the
///   phone.
/// - **Offered:** on Android, when Google Play has a newer build for this
///   phone, Play's flexible update (downloaded while the learner keeps
///   learning, then "Restart"); on iOS, when `latest_build_ios` is newer,
///   a link to the App Store. At most once every [promptInterval], so it
///   never nags.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.updater,
    required this.settings,
    required this.storage,
    required this.child,
    this.now = DateTime.now,
  });

  final AppUpdater updater;
  final RemoteSettingsController settings;

  /// Remembers when an update was last offered.
  final SecureStorageService storage;

  final Widget child;
  final DateTime Function() now;

  static const promptInterval = Duration(days: 3);
  static const promptedAtKey = 'app_update_prompted_at';

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  int? _build;

  /// Whether this launch has already considered offering an update.
  bool _offered = false;

  AppUpdater get _updater => widget.updater;
  RemoteSettings get _config => widget.settings.config;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onConfigChanged);
    unawaited(_start());
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onConfigChanged);
    super.dispose();
  }

  Future<void> _start() async {
    if (_updater.store == null) return;
    final build = await _updater.installedBuild();
    if (!mounted || build == null) return;
    setState(() => _build = build);
    await _maybeOffer();
  }

  void _onConfigChanged() {
    setState(() {});
    unawaited(_maybeOffer());
  }

  /// Whether this build is older than its store's minimum.
  bool get _required {
    final build = _build;
    final minimum = switch (_updater.store) {
      UpdateStore.googlePlay => _config.get(AppConfig.minBuildAndroid),
      UpdateStore.appStore => _config.get(AppConfig.minBuildIos),
      null => 0,
    };
    return build != null && build < minimum;
  }

  Future<void> _maybeOffer() async {
    final build = _build;
    if (_offered || build == null || _required) return;
    switch (_updater.store) {
      case UpdateStore.googlePlay:
        _offered = true;
        final play = await _updater.checkPlay();
        if (!mounted) return;
        if (play == PlayUpdate.downloaded) return _offerRestart();
        if (play != PlayUpdate.available || !await _mayPrompt()) return;
        await _markPrompted();
        if (await _updater.downloadInBackground() && mounted) {
          _offerRestart();
        }
      case UpdateStore.appStore:
        // Waits for a configuration that names a newer build.
        final url = _config.get(AppConfig.iosStoreUrl);
        if (build >= _config.get(AppConfig.latestBuildIos) || url.isEmpty) {
          return;
        }
        _offered = true;
        if (!await _mayPrompt() || !mounted) return;
        await _markPrompted();
        if (!mounted) return;
        _showSnackBar(
          context.l10n.updateAvailable,
          action: context.l10n.updateAction,
          onPressed: () => unawaited(_updater.openStore(url: url)),
        );
      case null:
        return;
    }
  }

  void _offerRestart() {
    if (!mounted) return;
    _showSnackBar(
      context.l10n.updateDownloaded,
      action: context.l10n.updateRestart,
      onPressed: () => unawaited(_updater.installDownloaded()),
    );
  }

  void _showSnackBar(
    String text, {
    required String action,
    required VoidCallback onPressed,
  }) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: action, onPressed: onPressed),
      ),
    );
  }

  Future<bool> _mayPrompt() async {
    try {
      final last = DateTime.tryParse(
        await widget.storage.read(AppUpdateGate.promptedAtKey) ?? '',
      );
      return last == null ||
          widget.now().difference(last) >= AppUpdateGate.promptInterval;
    } on Object {
      return true;
    }
  }

  Future<void> _markPrompted() async {
    try {
      await widget.storage.write(
        AppUpdateGate.promptedAtKey,
        widget.now().toUtc().toIso8601String(),
      );
    } on Object {
      // Offered again next launch: better than never.
    }
  }

  /// "Update now": Play's full-screen update on Android, else the store
  /// page. Play's page closes the app when the update installs.
  Future<void> _updateRequired() async {
    if (_updater.store == UpdateStore.googlePlay &&
        await _updater.updateNow()) {
      return;
    }
    final opened = await _updater.openStore(
      url: _updater.store == UpdateStore.appStore
          ? _config.get(AppConfig.iosStoreUrl)
          : '',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.updateStoreFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_required) return widget.child;
    // Its own navigator, for the overlay its widgets need; the app's
    // navigator is gone, so Back leaves the app instead of reaching it.
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => UpdateRequiredScreen(onUpdate: _updateRequired),
      ),
    );
  }
}
