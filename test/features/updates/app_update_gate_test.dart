// Required and offered app updates (AppUpdateGate): a build older than the
// backend's minimum for its store shows "Update needed" in place of the
// app; a newer build in the store is offered, at most every few days.

import 'dart:convert';

import 'package:elang/features/updates/app_update_gate.dart';
import 'package:elang/features/updates/update_required_screen.dart';
import 'package:elang/shared/l10n/app_language.dart';
import 'package:elang/shared/services/app_config_api.dart';
import 'package:elang/shared/services/app_updater.dart';
import 'package:elang/shared/settings/known_settings.dart';
import 'package:elang/shared/settings/remote_settings_controller.dart';
import 'package:elang/shared/settings/remote_settings_store.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

final _now = DateTime.utc(2026, 10, 3, 9);

class _FakeUpdater implements AppUpdater {
  _FakeUpdater({
    this.store = UpdateStore.googlePlay,
    this.build = 10,
    this.play = PlayUpdate.none,
    this.downloads = true,
    this.updatesNow = true,
    this.opensStore = true,
  });

  @override
  final UpdateStore? store;
  final int? build;
  PlayUpdate play;
  final bool downloads;
  final bool updatesNow;
  final bool opensStore;

  final calls = <String>[];

  @override
  Future<int?> installedBuild() async => build;

  @override
  Future<PlayUpdate> checkPlay() async {
    calls.add('checkPlay');
    return play;
  }

  @override
  Future<bool> downloadInBackground() async {
    calls.add('download');
    return downloads;
  }

  @override
  Future<void> installDownloaded() async => calls.add('install');

  @override
  Future<bool> updateNow() async {
    calls.add('updateNow');
    return updatesNow;
  }

  @override
  Future<bool> openStore({String url = ''}) async {
    calls.add('openStore $url');
    return opensStore;
  }
}

class _Setup {
  _Setup({_FakeUpdater? updater, Map<String, Object?> config = const {}})
    : updater = updater ?? _FakeUpdater(),
      settings = RemoteSettingsController(
        store: RemoteSettingsStore(storage: InMemorySecureStorageService()),
        configApi: AppConfigApi(
          client: MockClient(
            (_) async => _served == null
                ? throw http.ClientException('offline')
                : http.Response(jsonEncode({'config': _served}), 200),
          ),
        ),
        config: RemoteSettings(config),
      );

  final _FakeUpdater updater;
  final RemoteSettingsController settings;
  final storage = InMemorySecureStorageService();

  /// What the backend sends on the next fetch; `null` is offline.
  static Map<String, Object?>? _served;

  Future<void> serve(Map<String, Object?> config) async {
    _served = config;
    await settings.refreshConfig();
  }

  Widget app() => MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLanguage.delegates,
    supportedLocales: AppLanguage.locales,
    builder: (context, child) => AppUpdateGate(
      updater: updater,
      settings: settings,
      storage: storage,
      now: () => _now,
      child: child!,
    ),
    home: const Scaffold(body: Text('HOME')),
  );
}

Future<void> _pump(WidgetTester tester, _Setup setup) async {
  await tester.pumpWidget(setup.app());
  await tester.pumpAndSettle();
}

final _required = find.byType(UpdateRequiredScreen);
final _home = find.text('HOME');

void main() {
  setUp(() => _Setup._served = null);

  group('a required update', () {
    testWidgets('a build older than the Android minimum shows only the '
        'update screen, from the configuration saved on the phone', (
      tester,
    ) async {
      final setup = _Setup(config: {AppConfig.minBuildAndroid.key: 11});
      await _pump(tester, setup);

      expect(_required, findsOneWidget);
      expect(find.text('Update needed'), findsOneWidget);
      expect(_home, findsNothing);
      // Nothing optional is offered on top of it.
      expect(setup.updater.calls, isEmpty);
    });

    testWidgets('a build at the minimum runs', (tester) async {
      final setup = _Setup(config: {AppConfig.minBuildAndroid.key: 10});
      await _pump(tester, setup);

      expect(_home, findsOneWidget);
      expect(_required, findsNothing);
    });

    testWidgets("the other platform's minimum does not apply", (tester) async {
      final setup = _Setup(config: {AppConfig.minBuildIos.key: 99});
      await _pump(tester, setup);

      expect(_home, findsOneWidget);
    });

    testWidgets('a minimum raised by the next fetch shows the update screen', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      expect(_home, findsOneWidget);

      await setup.serve({AppConfig.minBuildAndroid.key: 12});
      await tester.pumpAndSettle();

      expect(_required, findsOneWidget);
    });

    testWidgets('on Android, Update now starts Google Play\'s update', (
      tester,
    ) async {
      final setup = _Setup(config: {AppConfig.minBuildAndroid.key: 11});
      await _pump(tester, setup);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(setup.updater.calls, ['updateNow']);
    });

    testWidgets('when Play cannot update, the Play page opens instead', (
      tester,
    ) async {
      final setup = _Setup(
        updater: _FakeUpdater(updatesNow: false),
        config: {AppConfig.minBuildAndroid.key: 11},
      );
      await _pump(tester, setup);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(setup.updater.calls, ['updateNow', 'openStore ']);
    });

    testWidgets('a store that cannot open says so', (tester) async {
      final setup = _Setup(
        updater: _FakeUpdater(updatesNow: false, opensStore: false),
        config: {AppConfig.minBuildAndroid.key: 11},
      );
      await _pump(tester, setup);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't open the store"), findsOneWidget);
      expect(_required, findsOneWidget);
    });

    testWidgets('on iOS, Update now opens the App Store page', (tester) async {
      final setup = _Setup(
        updater: _FakeUpdater(store: UpdateStore.appStore),
        config: {
          AppConfig.minBuildIos.key: 11,
          AppConfig.iosStoreUrl.key: 'https://apps.apple.com/app/id1',
        },
      );
      await _pump(tester, setup);

      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();

      expect(setup.updater.calls, ['openStore https://apps.apple.com/app/id1']);
    });
  });

  group('an offered update on Android', () {
    testWidgets('a build Play has is downloaded, then Restart installs it', (
      tester,
    ) async {
      final setup = _Setup(updater: _FakeUpdater(play: PlayUpdate.available));
      await _pump(tester, setup);

      expect(setup.updater.calls, ['checkPlay', 'download']);
      expect(find.text('The update is ready.'), findsOneWidget);
      expect(_home, findsOneWidget);

      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();

      expect(setup.updater.calls.last, 'install');
      expect(
        setup.storage.values[AppUpdateGate.promptedAtKey],
        _now.toIso8601String(),
      );
    });

    testWidgets('it is not offered again within three days', (tester) async {
      final setup = _Setup(updater: _FakeUpdater(play: PlayUpdate.available));
      setup.storage.values[AppUpdateGate.promptedAtKey] = _now
          .subtract(const Duration(days: 2))
          .toIso8601String();
      await _pump(tester, setup);

      expect(setup.updater.calls, ['checkPlay']);
    });

    testWidgets('it is offered again after three days', (tester) async {
      final setup = _Setup(updater: _FakeUpdater(play: PlayUpdate.available));
      setup.storage.values[AppUpdateGate.promptedAtKey] = _now
          .subtract(AppUpdateGate.promptInterval)
          .toIso8601String();
      await _pump(tester, setup);

      expect(setup.updater.calls, ['checkPlay', 'download']);
    });

    testWidgets('a learner who turns down the download is not told it is '
        'ready', (tester) async {
      final setup = _Setup(
        updater: _FakeUpdater(play: PlayUpdate.available, downloads: false),
      );
      await _pump(tester, setup);

      expect(find.text('The update is ready.'), findsNothing);
    });

    testWidgets('an update downloaded earlier offers Restart at once', (
      tester,
    ) async {
      final setup = _Setup(updater: _FakeUpdater(play: PlayUpdate.downloaded));
      setup.storage.values[AppUpdateGate.promptedAtKey] = _now
          .toIso8601String();
      await _pump(tester, setup);

      expect(setup.updater.calls, ['checkPlay']);
      expect(find.text('Restart'), findsOneWidget);
    });

    testWidgets('Play is asked once a launch', (tester) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await setup.serve({});
      await tester.pumpAndSettle();

      expect(setup.updater.calls, ['checkPlay']);
    });
  });

  group('an offered update on iOS', () {
    _FakeUpdater ios() => _FakeUpdater(store: UpdateStore.appStore);

    testWidgets('a newer App Store build is offered, and Update opens it', (
      tester,
    ) async {
      final setup = _Setup(
        updater: ios(),
        config: {
          AppConfig.latestBuildIos.key: 11,
          AppConfig.iosStoreUrl.key: 'https://apps.apple.com/app/id1',
        },
      );
      await _pump(tester, setup);

      expect(find.text('A new version of Buna is available.'), findsOneWidget);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(setup.updater.calls, ['openStore https://apps.apple.com/app/id1']);
    });

    testWidgets('it waits for a configuration that names a newer build', (
      tester,
    ) async {
      final setup = _Setup(updater: ios());
      await _pump(tester, setup);
      expect(find.byType(SnackBar), findsNothing);

      await setup.serve({
        AppConfig.latestBuildIos.key: 11,
        AppConfig.iosStoreUrl.key: 'https://apps.apple.com/app/id1',
      });
      await tester.pumpAndSettle();

      expect(find.text('A new version of Buna is available.'), findsOneWidget);
    });

    testWidgets('nothing is offered without a store page', (tester) async {
      final setup = _Setup(
        updater: ios(),
        config: {AppConfig.latestBuildIos.key: 11},
      );
      await _pump(tester, setup);

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('nothing is offered to the newest build', (tester) async {
      final setup = _Setup(
        updater: ios(),
        config: {
          AppConfig.latestBuildIos.key: 10,
          AppConfig.iosStoreUrl.key: 'https://apps.apple.com/app/id1',
        },
      );
      await _pump(tester, setup);

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('the web checks nothing, whatever the minimum', (tester) async {
    final setup = _Setup(
      updater: _FakeUpdater(store: null),
      config: {
        AppConfig.minBuildAndroid.key: 99,
        AppConfig.minBuildIos.key: 99,
      },
    );
    await _pump(tester, setup);

    expect(_home, findsOneWidget);
    expect(setup.updater.calls, isEmpty);
  });

  testWidgets('a build number that cannot be read is never blocked', (
    tester,
  ) async {
    final setup = _Setup(
      updater: _FakeUpdater(build: null),
      config: {AppConfig.minBuildAndroid.key: 99},
    );
    await _pump(tester, setup);

    expect(_home, findsOneWidget);
  });
}
