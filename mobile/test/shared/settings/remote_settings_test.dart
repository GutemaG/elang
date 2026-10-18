// The app reads account settings and app configuration with its own
// defaults, and keeps the last copy on the phone
// (022-light-and-dark-themes, bolt 072, story 009, FR-10).

import 'dart:convert';

import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/app_config_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/settings/known_settings.dart';
import 'package:elang/shared/settings/remote_settings_controller.dart';
import 'package:elang/shared/settings/remote_settings_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

// Test-only settings: the app's real lists are empty until a setting is
// needed.
const _reduceMotion = KnownSetting<bool>('reduce_motion', false);
const _reminderHour = KnownSetting<int>('reminder_hour', 20);
const _theme = KnownSetting<String>('theme', 'system');

SessionUser _user(String id, Map<String, Object?> settings) => SessionUser(
  id: id,
  selectedLanguage: 'am',
  dailyXpTarget: 40,
  notificationEnabled: true,
  settings: settings,
);

AppConfigApi _configApi(Object? body, {int status = 200}) => AppConfigApi(
  baseUrl: 'https://api.test',
  client: MockClient((request) async {
    expect(request.url.path, '/api/v1/config');
    expect(request.headers.containsKey('Authorization'), isFalse);
    return http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }),
);

AppConfigApi _offline() => AppConfigApi(
  baseUrl: 'https://api.test',
  client: MockClient((request) async => throw http.ClientException('offline')),
);

void main() {
  group('RemoteSettings', () {
    test('a present value of the right type is read', () {
      final s = RemoteSettings({'reduce_motion': true, 'reminder_hour': 7});
      expect(s.get(_reduceMotion), isTrue);
      expect(s.get(_reminderHour), 7);
    });

    test('a missing key reads as the default', () {
      expect(RemoteSettings.empty.get(_theme), 'system');
      expect(RemoteSettings.empty.get(_reminderHour), 20);
    });

    test('a value of another type reads as the default', () {
      final s = RemoteSettings({
        'reduce_motion': 'yes',
        'reminder_hour': 7.5,
        'theme': 3,
      });
      expect(s.get(_reduceMotion), isFalse);
      expect(s.get(_reminderHour), 20);
      expect(s.get(_theme), 'system');
    });

    test('keys the app does not know are kept but never in the way', () {
      final s = RemoteSettings({'added_later': 1, 'theme': 'dark'});
      expect(s.get(_theme), 'dark');
      expect(s.values['added_later'], 1);
    });
  });

  group('SessionApi', () {
    Future<SessionCheckResult> check(Map<String, Object?> user) => SessionApi(
      baseUrl: 'https://api.test',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'valid': true,
            'user': {
              'id': 'user-1',
              'selected_language': 'am',
              'daily_xp_target': 40,
              'notification_enabled': true,
              ...user,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ).checkSession('tok');

    test('reads settings when the backend sends them', () async {
      final result = await check({
        'settings': {'theme': 'dark'},
      });
      expect(result.status, SessionCheckStatus.valid);
      expect(result.user!.settings, {'theme': 'dark'});
    });

    test('an older backend without settings still checks, with none', () async {
      final result = await check({});
      expect(result.status, SessionCheckStatus.valid);
      expect(result.user!.settings, isEmpty);
    });

    test('settings that are not a map count as none', () async {
      final result = await check({'settings': 'dark'});
      expect(result.status, SessionCheckStatus.valid);
      expect(result.user!.settings, isEmpty);
    });
  });

  group('AppConfigApi', () {
    test('reads the config map, with no sign-in', () async {
      expect(
        await _configApi({
          'config': {'max_beans': 5},
        }).fetch(),
        {'max_beans': 5},
      );
    });

    test('is null offline, on an error status or a malformed body', () async {
      expect(await _offline().fetch(), isNull);
      expect(await _configApi({'config': {}}, status: 503).fetch(), isNull);
      expect(await _configApi('not json').fetch(), isNull);
      expect(await _configApi({'config': 'x'}).fetch(), isNull);
      expect(await _configApi([1, 2]).fetch(), isNull);
    });
  });

  group('RemoteSettingsStore', () {
    late InMemorySecureStorageService storage;
    late RemoteSettingsStore store;

    setUp(() {
      storage = InMemorySecureStorageService();
      store = RemoteSettingsStore(storage: storage);
    });

    test('nothing saved reads as none', () async {
      expect(await store.readAccount(), isNull);
      expect(await store.readConfig(), RemoteSettings.empty);
    });

    test('both round-trip', () async {
      await store.saveAccount('user-1', RemoteSettings({'theme': 'dark'}));
      await store.saveConfig(RemoteSettings({'max_beans': 5}));

      final account = await store.readAccount();
      expect(account!.userId, 'user-1');
      expect(account.settings.get(_theme), 'dark');
      expect((await store.readConfig()).values, {'max_beans': 5});
    });

    test('a copy that cannot be read back counts as none', () async {
      await storage.write('account_settings', '{not json');
      await storage.write('app_config', '[1]');
      expect(await store.readAccount(), isNull);
      expect(await store.readConfig(), RemoteSettings.empty);
    });

    test('clearing the account copy leaves the config', () async {
      await store.saveAccount('user-1', RemoteSettings({'theme': 'dark'}));
      await store.saveConfig(RemoteSettings({'max_beans': 5}));
      await store.clearAccount();
      expect(await store.readAccount(), isNull);
      expect((await store.readConfig()).values, {'max_beans': 5});
    });
  });

  group('RemoteSettingsController', () {
    late InMemorySecureStorageService storage;
    late RemoteSettingsStore store;

    setUp(() {
      storage = InMemorySecureStorageService();
      store = RemoteSettingsStore(storage: storage);
    });

    test('offline, it starts from the saved copies', () async {
      await store.saveAccount('user-1', RemoteSettings({'theme': 'dark'}));
      await store.saveConfig(RemoteSettings({'max_beans': 3}));

      final c = await RemoteSettingsController.load(
        store: store,
        configApi: _offline(),
      );
      await c.refreshConfig();

      expect(c.account.get(_theme), 'dark');
      expect(c.config.values, {'max_beans': 3});
    });

    test('a session check updates, saves and tells listeners', () async {
      final c = await RemoteSettingsController.load(
        store: store,
        configApi: _offline(),
      );
      var told = 0;
      c.addListener(() => told++);

      await c.applySession(_user('user-1', {'theme': 'light'}));
      await c.applySession(_user('user-1', {'theme': 'light'}));

      expect(c.account.get(_theme), 'light');
      expect(told, 1, reason: 'the same settings again change nothing');
      expect((await store.readAccount())!.settings.get(_theme), 'light');
    });

    test('a config fetch updates and saves it', () async {
      final c = await RemoteSettingsController.load(
        store: store,
        configApi: _configApi({
          'config': {'max_beans': 7},
        }),
      );
      await c.refreshConfig();

      expect(c.config.values, {'max_beans': 7});
      expect((await store.readConfig()).values, {'max_beans': 7});
    });

    test('forgetting the account clears it here and on the phone', () async {
      final c = await RemoteSettingsController.load(
        store: store,
        configApi: _offline(),
      );
      await c.applySession(_user('user-1', {'theme': 'dark'}));

      await c.forgetAccount();

      expect(c.account, RemoteSettings.empty);
      expect(await store.readAccount(), isNull);
    });
  });

  group('account changes', () {
    SessionState session(String token, {int days = 1}) => SessionState(
      token: token,
      expiresAt: DateTime.now().add(Duration(days: days)),
      authProvider: 'google',
    );

    test('sign-out and a new sign-in are heard; a renewal is not', () async {
      final sessions = SessionRepository(
        storage: InMemorySecureStorageService(),
      );
      var changes = 0;
      sessions.addAccountChangedListener(() => changes++);

      await sessions.saveSession(session('tok-a'));
      expect(changes, 1, reason: 'signed in');
      await sessions.saveSession(session('tok-a', days: 30));
      expect(changes, 1, reason: 'the same session, renewed');
      await sessions.clearSession();
      expect(changes, 2, reason: 'signed out');
      await sessions.saveSession(session('tok-b'));
      expect(changes, 3, reason: 'someone signed in');
    });

    test("one learner's settings are gone once the account changes", () async {
      final storage = InMemorySecureStorageService();
      final sessions = SessionRepository(storage: storage);
      final c = await RemoteSettingsController.load(
        store: RemoteSettingsStore(storage: storage),
        configApi: _offline(),
      );
      sessions.addAccountChangedListener(() => c.forgetAccount());
      await sessions.saveSession(session('tok-a'));
      await c.applySession(_user('user-a', {'theme': 'dark'}));

      await sessions.clearSession();
      await Future<void>.delayed(Duration.zero);

      expect(c.account.get(_theme), 'system');
      expect(await RemoteSettingsStore(storage: storage).readAccount(), isNull);
    });
  });

  testWidgets('a widget reading the scope rebuilds on an update', (
    tester,
  ) async {
    final c = RemoteSettingsController(
      store: RemoteSettingsStore(storage: InMemorySecureStorageService()),
      configApi: _offline(),
    );
    await tester.pumpWidget(
      RemoteSettingsScope(
        controller: c,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) =>
                Text(RemoteSettingsScope.of(context).account.get(_theme)),
          ),
        ),
      ),
    );
    expect(find.text('system'), findsOneWidget);

    await tester.runAsync(
      () => c.applySession(_user('user-1', {'theme': 'dark'})),
    );
    await tester.pump();

    expect(find.text('dark'), findsOneWidget);
  });
}
