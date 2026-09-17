// Widget tests for `SettingsScreen` (story 001/002, `005-profile-and-settings`):
// view/edit current settings, and logout navigation.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/user_preferences_api.dart';

import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

Future<SessionRepository> _signedInSessionRepository() async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'session-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
    ),
  );
  return repo;
}

SessionApi _sessionApiReturning({int dailyXpTarget = 40, bool notificationEnabled = true}) {
  return SessionApi(
    client: MockClient((request) async {
      return http.Response(
        jsonEncode({
          'valid': true,
          'user': {
            'id': 'user-1',
            'selected_language': 'am',
            'daily_xp_target': dailyXpTarget,
            'notification_enabled': notificationEnabled,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

Widget _wrap({
  required SessionApi sessionApi,
  required SessionRepository sessionRepository,
  UserPreferencesApi? userPreferencesApi,
  SoundPreferenceRepository? soundPreferenceRepository,
}) {
  return MaterialApp(
    home: SettingsScreen(
      sessionApi: sessionApi,
      userPreferencesApi: userPreferencesApi ?? FakeUserPreferencesApi(),
      soundPreferenceRepository:
          soundPreferenceRepository ??
          SoundPreferenceRepository(storage: InMemorySecureStorageService()),
      sessionRepository: sessionRepository,
    ),
    routes: {
      AuthRoutes.signIn: (context) => const Scaffold(body: Text('Sign In Placeholder')),
    },
  );
}

void main() {
  testWidgets('shows the provider label, daily goal, language, and both switches', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        sessionApi: _sessionApiReturning(dailyXpTarget: 60, notificationEnabled: false),
        sessionRepository: await _signedInSessionRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('Serious · 15 min/day'), findsOneWidget);
    expect(find.text('Amharic'), findsOneWidget);
    final notificationSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Notifications'),
    );
    expect(notificationSwitch.value, false);
    final soundSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Sound'),
    );
    expect(soundSwitch.value, true);
  });

  testWidgets('toggling notification calls the API and updates the switch', (tester) async {
    final userPreferencesApi = FakeUserPreferencesApi()
      ..nextResult = const UpdatedPreferences(
        selectedLanguage: 'am',
        dailyXpTarget: 40,
        notificationEnabled: false,
      );
    await tester.pumpWidget(
      _wrap(
        sessionApi: _sessionApiReturning(notificationEnabled: true),
        sessionRepository: await _signedInSessionRepository(),
        userPreferencesApi: userPreferencesApi,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Notifications'));
    await tester.pumpAndSettle();

    expect(userPreferencesApi.calls.single.notificationEnabled, false);
    final notificationSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Notifications'),
    );
    expect(notificationSwitch.value, false);
  });

  testWidgets('toggling sound persists locally without calling the preferences API', (
    tester,
  ) async {
    final soundPreferenceRepository = SoundPreferenceRepository(
      storage: InMemorySecureStorageService(),
    );
    final userPreferencesApi = FakeUserPreferencesApi();
    await tester.pumpWidget(
      _wrap(
        sessionApi: _sessionApiReturning(),
        sessionRepository: await _signedInSessionRepository(),
        userPreferencesApi: userPreferencesApi,
        soundPreferenceRepository: soundPreferenceRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Sound'));
    await tester.pumpAndSettle();

    expect(await soundPreferenceRepository.getSoundEnabled(), false);
    expect(userPreferencesApi.calls, isEmpty);
  });

  testWidgets('logout clears the session and navigates to sign-in, unwinding the stack', (
    tester,
  ) async {
    final sessionRepository = await _signedInSessionRepository();
    await tester.pumpWidget(
      _wrap(sessionApi: _sessionApiReturning(), sessionRepository: sessionRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    // Confirmation dialog.
    expect(find.text("You'll need to sign in again to continue learning."), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In Placeholder'), findsOneWidget);
    final session = await sessionRepository.getSessionState();
    expect(session.token, isNull);
  });

  testWidgets('cancelling the logout confirmation keeps the session', (tester) async {
    final sessionRepository = await _signedInSessionRepository();
    await tester.pumpWidget(
      _wrap(sessionApi: _sessionApiReturning(), sessionRepository: sessionRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In Placeholder'), findsNothing);
    final session = await sessionRepository.getSessionState();
    expect(session.token, isNotNull);
  });

  testWidgets('a failed load shows an error state with a working retry', (tester) async {
    var callCount = 0;
    final sessionApi = SessionApi(
      client: MockClient((request) async {
        callCount++;
        if (callCount == 1) return http.Response('', 500);
        return http.Response(
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
        );
      }),
    );

    await tester.pumpWidget(
      _wrap(sessionApi: sessionApi, sessionRepository: await _signedInSessionRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your settings"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your settings"), findsNothing);
    expect(find.text('Signed in with Google'), findsOneWidget);
  });
}
