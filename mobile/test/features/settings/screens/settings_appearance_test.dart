// The Appearance row in Settings (022-light-and-dark-themes, bolt 070,
// story 006): System, Light or Dark, applied at once and kept on the phone.

import 'dart:convert';

import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';
import '../../../helpers/test_appearance.dart';

Future<Widget> _settings({AppearanceController? appearance}) async {
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
  );
  if (appearance == null) {
    return MaterialApp(theme: AppTheme.light, home: screen);
  }
  // As the app does (main.dart): the scope above, the mode from it.
  return AppearanceScope(
    controller: appearance,
    child: ValueListenableBuilder(
      valueListenable: appearance,
      builder: (context, mode, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: screen,
      ),
    ),
  );
}

Future<void> _openRow(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(SettingsScreen.appearanceRowKey),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('the row reads as one node with its current value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(await _settings(appearance: testAppearance()));
    await tester.pumpAndSettle();
    await _openRow(tester);

    expect(
      tester.getSemantics(find.byKey(SettingsScreen.appearanceRowKey)),
      isSemantics(
        label: 'Appearance\nSystem',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('picking Dark makes the app dark at once and keeps it', (
    tester,
  ) async {
    final storage = InMemorySecureStorageService();
    final appearance = testAppearance(storage: storage);
    await tester.pumpWidget(await _settings(appearance: appearance));
    await tester.pumpAndSettle();
    await _openRow(tester);

    await tester.tap(find.byKey(SettingsScreen.appearanceRowKey));
    await tester.pumpAndSettle();
    expect(find.text('Match your phone'), findsOneWidget);
    expect(find.text('Always light'), findsOneWidget);
    await tester.tap(find.text('Always dark'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.dark,
    );
    expect(appearance.value, ThemeMode.dark);
    expect(storage.values['appearance'], 'dark');
    expect(
      find.descendant(
        of: find.byKey(SettingsScreen.appearanceRowKey),
        matching: find.text('Dark'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('closing the sheet keeps the choice as it was', (tester) async {
    final appearance = testAppearance(mode: ThemeMode.light);
    await tester.pumpWidget(await _settings(appearance: appearance));
    await tester.pumpAndSettle();
    await _openRow(tester);

    await tester.tap(find.byKey(SettingsScreen.appearanceRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(appearance.value, ThemeMode.light);
  });

  testWidgets('with no Appearance in scope, the row is left out', (
    tester,
  ) async {
    await tester.pumpWidget(await _settings());
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsScreen.appearanceRowKey), findsNothing);
    expect(find.text('Sound'), findsOneWidget);
  });
}
