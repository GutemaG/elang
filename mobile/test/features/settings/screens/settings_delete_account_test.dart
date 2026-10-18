// "Delete account" in Settings: both app stores require an app with sign-in
// to let people delete their account, and its data, from inside the app.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/account_deletion_api.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/widgets/app_button.dart';

import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

class _FakeAccountDeletionApi implements AccountDeletionApi {
  _FakeAccountDeletionApi({this.fails = false});

  final bool fails;
  int calls = 0;

  @override
  Future<void> deleteAccount() async {
    calls++;
    if (fails) throw const AccountDeletionException('offline');
  }
}

Future<SessionRepository> _signedIn() async {
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

SessionApi _sessionApi() => SessionApi(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'valid': true,
        'user': {
          'id': 'user-1',
          'selected_language': 'am',
          'daily_xp_target': 20,
          'notification_enabled': false,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  SessionRepository sessionRepository, {
  AccountDeletionApi? api,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsScreen(
        sessionApi: _sessionApi(),
        courseApi: FakeCourseApi(),
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: sessionRepository,
        accountDeletionApi: api,
      ),
      routes: {
        AuthRoutes.signIn: (context) =>
            const Scaffold(body: Text('Sign In Placeholder')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openConfirmation(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(SettingsScreen.deleteAccountKey));
  await tester.tap(find.byKey(SettingsScreen.deleteAccountKey));
  await tester.pumpAndSettle();
  expect(find.text('Delete your account?'), findsOneWidget);
}

void main() {
  testWidgets('deletes the account after asking, then goes to sign-in', (
    tester,
  ) async {
    final sessionRepository = await _signedIn();
    final api = _FakeAccountDeletionApi();
    await _pump(tester, sessionRepository, api: api);

    await _openConfirmation(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Delete account').last);
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(find.text('Sign In Placeholder'), findsOneWidget);
    expect((await sessionRepository.getSessionState()).token, isNull);
  });

  testWidgets('cancelling deletes nothing', (tester) async {
    final sessionRepository = await _signedIn();
    final api = _FakeAccountDeletionApi();
    await _pump(tester, sessionRepository, api: api);

    await _openConfirmation(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(api.calls, 0);
    expect((await sessionRepository.getSessionState()).token, isNotNull);
  });

  testWidgets('a failed delete says so and stays signed in', (tester) async {
    final sessionRepository = await _signedIn();
    await _pump(
      tester,
      sessionRepository,
      api: _FakeAccountDeletionApi(fails: true),
    );

    await _openConfirmation(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Delete account').last);
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Couldn't delete your account. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.text('Sign In Placeholder'), findsNothing);
    expect((await sessionRepository.getSessionState()).token, isNotNull);
  });

  testWidgets('without an API there is no button', (tester) async {
    await _pump(tester, await _signedIn());

    expect(find.byKey(SettingsScreen.deleteAccountKey), findsNothing);
  });

  group('HttpAccountDeletionApi', () {
    test('sends DELETE /api/v1/users/me with the session token', () async {
      late http.Request sent;
      final api = HttpAccountDeletionApi(
        sessionRepository: await _signedIn(),
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          sent = request;
          return http.Response('', 204);
        }),
      );

      await api.deleteAccount();

      expect(sent.method, 'DELETE');
      expect(sent.url.toString(), 'https://api.test/api/v1/users/me');
      expect(sent.headers['Authorization'], 'Bearer session-token');
    });

    test('anything but 204 is a failure', () async {
      final api = HttpAccountDeletionApi(
        sessionRepository: await _signedIn(),
        baseUrl: 'https://api.test',
        client: MockClient((_) async => http.Response('', 500)),
      );

      expect(api.deleteAccount, throwsA(isA<AccountDeletionException>()));
    });
  });
}
