// "Show me in leagues" in Settings (023-weekly-leagues, bolt 075, story
// 007): read from the account settings, saved at once, and put back with a
// message when saving fails. The course panel's "Weekly league" row.

import 'dart:convert';

import 'package:elang/features/courses/course_panel.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/app_config_api.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/settings/known_settings.dart';
import 'package:elang/shared/settings/remote_settings_controller.dart';
import 'package:elang/shared/settings/remote_settings_store.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../helpers/fake_league_api.dart';
import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

RemoteSettingsController _settings({bool show = true}) =>
    RemoteSettingsController(
      store: RemoteSettingsStore(storage: InMemorySecureStorageService()),
      configApi: AppConfigApi(
        client: MockClient((_) async => throw http.ClientException('x')),
      ),
      account: RemoteSettings({'show_in_leagues': show}),
    );

Future<Widget> _screen({
  RemoteSettingsController? settings,
  FakeAccountSettingsApi? api,
}) async {
  final storage = InMemorySecureStorageService();
  final sessions = SessionRepository(storage: storage);
  await sessions.saveSession(
    SessionState(
      token: 'session-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
    ),
  );
  final screen = SettingsScreen(
    sessionApi: SessionApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'valid': true,
            'user': {
              'id': 'user-1',
              'selected_language': 'am',
              'daily_xp_target': 40,
              'notification_enabled': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ),
    courseApi: FakeCourseApi(),
    userPreferencesApi: FakeUserPreferencesApi(),
    soundPreferenceRepository: SoundPreferenceRepository(storage: storage),
    sessionRepository: sessions,
    accountSettingsApi: api,
  );
  final app = MaterialApp(theme: AppTheme.light, home: screen);
  return settings == null
      ? app
      : RemoteSettingsScope(controller: settings, child: app);
}

Future<void> _toSwitch(WidgetTester tester) => tester.scrollUntilVisible(
  find.byKey(SettingsScreen.showInLeaguesKey),
  200,
  scrollable: find.byType(Scrollable).first,
);

bool _value(WidgetTester tester) => tester
    .widget<Switch>(
      find.descendant(
        of: find.byKey(SettingsScreen.showInLeaguesKey),
        matching: find.byType(Switch),
      ),
    )
    .value;

void main() {
  testWidgets('the switch shows the account setting and saves a change', (
    tester,
  ) async {
    final settings = _settings();
    final api = FakeAccountSettingsApi();
    await tester.pumpWidget(await _screen(settings: settings, api: api));
    await tester.pumpAndSettle();
    await _toSwitch(tester);

    expect(find.text('Show me in leagues'), findsOneWidget);
    expect(
      find.text('Others in your league see your first name'),
      findsOneWidget,
    );
    expect(_value(tester), isTrue);

    await tester.tap(find.byKey(SettingsScreen.showInLeaguesKey));
    await tester.pumpAndSettle();

    expect(api.updates, [
      {'show_in_leagues': false},
    ]);
    expect(settings.account.get(AccountSettings.showInLeagues), isFalse);
    expect(_value(tester), isFalse);
  });

  testWidgets('a failed save puts the switch back and says so', (tester) async {
    final settings = _settings(show: false);
    final api = FakeAccountSettingsApi()..fail = true;
    await tester.pumpWidget(await _screen(settings: settings, api: api));
    await tester.pumpAndSettle();
    await _toSwitch(tester);

    await tester.tap(find.byKey(SettingsScreen.showInLeaguesKey));
    await tester.pumpAndSettle();

    expect(_value(tester), isFalse);
    expect(find.text("Couldn't save. Check your connection."), findsOneWidget);
  });

  testWidgets('without the settings API or scope, no League section', (
    tester,
  ) async {
    await tester.pumpWidget(await _screen(settings: _settings()));
    await tester.pumpAndSettle();
    expect(find.text('Show me in leagues'), findsNothing);

    await tester.pumpWidget(await _screen(api: FakeAccountSettingsApi()));
    await tester.pumpAndSettle();
    expect(find.text('Show me in leagues'), findsNothing);
  });

  group('course panel', () {
    Widget panel({VoidCallback? onLeague}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CoursePanel(
          courses: const [],
          activeCourseId: null,
          onCourseSelected: (_) {},
          onAddCourse: () {},
          onSettings: () {},
          onDownloads: () {},
          onLeague: onLeague,
        ),
      ),
    );

    testWidgets('"Weekly league" opens the league', (tester) async {
      var opened = 0;
      await tester.pumpWidget(panel(onLeague: () => opened++));

      await tester.tap(find.text('Weekly league'));

      expect(opened, 1);
    });

    testWidgets('no row without a way to open it', (tester) async {
      await tester.pumpWidget(panel());
      expect(find.text('Weekly league'), findsNothing);
    });
  });
}
