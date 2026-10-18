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
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/user_preferences_api.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_card.dart';

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

SessionApi _sessionApiReturning({
  int dailyXpTarget = 40,
  bool notificationEnabled = true,
}) {
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
  CourseApi? courseApi,
}) {
  return MaterialApp(
    home: SettingsScreen(
      sessionApi: sessionApi,
      courseApi: courseApi ?? FakeCourseApi(),
      userPreferencesApi: userPreferencesApi ?? FakeUserPreferencesApi(),
      soundPreferenceRepository:
          soundPreferenceRepository ??
          SoundPreferenceRepository(storage: InMemorySecureStorageService()),
      sessionRepository: sessionRepository,
    ),
    routes: {
      AuthRoutes.signIn: (context) =>
          const Scaffold(body: Text('Sign In Placeholder')),
    },
  );
}

void main() {
  group('profile header', () {
    Future<SessionRepository> withProfile({String? photoUrl}) async {
      final repo = SessionRepository(storage: InMemorySecureStorageService());
      await repo.saveSession(
        SessionState(
          token: 'session-token',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          authProvider: 'google',
          displayName: 'Abebe Bikila',
          email: 'abebe@example.com',
          photoUrl: photoUrl,
        ),
      );
      return repo;
    }

    testWidgets('shows the name, email and initials from Google', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          sessionApi: _sessionApiReturning(),
          sessionRepository: await withProfile(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abebe Bikila'), findsOneWidget);
      expect(find.text('abebe@example.com'), findsOneWidget);
      expect(find.text('AB'), findsOneWidget);
      expect(find.text('Signed in with Google'), findsOneWidget);
    });

    testWidgets('a photo that cannot load falls back to the initials', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          sessionApi: _sessionApiReturning(),
          sessionRepository: await withProfile(
            photoUrl: 'https://example.com/photo.jpg',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'shows the provider label, daily goal, course, and both switches',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          sessionApi: _sessionApiReturning(
            dailyXpTarget: 60,
            notificationEnabled: false,
          ),
          sessionRepository: await _signedInSessionRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Signed in with Google'), findsOneWidget);
      expect(find.text('Serious · 15 min/day'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('English to Amharic'), findsOneWidget);
      final notificationSwitch = tester.widget<SwitchRow>(
        find.widgetWithText(SwitchRow, 'Notifications'),
      );
      expect(notificationSwitch.value, false);
      final soundSwitch = tester.widget<SwitchRow>(
        find.widgetWithText(SwitchRow, 'Sound'),
      );
      expect(soundSwitch.value, true);
    },
  );

  testWidgets('toggling notification calls the API and updates the switch', (
    tester,
  ) async {
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

    await tester.tap(find.widgetWithText(SwitchRow, 'Notifications'));
    await tester.pumpAndSettle();

    expect(userPreferencesApi.calls.single.notificationEnabled, false);
    final notificationSwitch = tester.widget<SwitchRow>(
      find.widgetWithText(SwitchRow, 'Notifications'),
    );
    expect(notificationSwitch.value, false);
  });

  testWidgets(
    'toggling sound persists locally without calling the preferences API',
    (tester) async {
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

      await tester.tap(find.widgetWithText(SwitchRow, 'Sound'));
      await tester.pumpAndSettle();

      expect(await soundPreferenceRepository.getSoundEnabled(), false);
      expect(userPreferencesApi.calls, isEmpty);
    },
  );

  testWidgets(
    'logout clears the session and navigates to sign-in, unwinding the stack',
    (tester) async {
      final sessionRepository = await _signedInSessionRepository();
      await tester.pumpWidget(
        _wrap(
          sessionApi: _sessionApiReturning(),
          sessionRepository: sessionRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Log out'));
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      // Confirmation dialog.
      expect(
        find.text("You'll need to sign in again to continue learning."),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Log out').last);
      await tester.pumpAndSettle();

      expect(find.text('Sign In Placeholder'), findsOneWidget);
      final session = await sessionRepository.getSessionState();
      expect(session.token, isNull);
    },
  );

  testWidgets('cancelling the logout confirmation keeps the session', (
    tester,
  ) async {
    final sessionRepository = await _signedInSessionRepository();
    await tester.pumpWidget(
      _wrap(
        sessionApi: _sessionApiReturning(),
        sessionRepository: sessionRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In Placeholder'), findsNothing);
    final session = await sessionRepository.getSessionState();
    expect(session.token, isNotNull);
  });

  testWidgets('a failed load shows an error state with a working retry', (
    tester,
  ) async {
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
      _wrap(
        sessionApi: sessionApi,
        sessionRepository: await _signedInSessionRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your settings"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your settings"), findsNothing);
    expect(find.text('Signed in with Google'), findsOneWidget);
  });

  // Course row (010-multi-language-courses, bolt 026): Settings uses the same
  // picker as the dashboard chip, shows the active course, and keeps it on a
  // failed switch.
  testWidgets('the Course row opens the shared picker and saves a switch', (
    tester,
  ) async {
    final courseApi = FakeCourseApi();
    await tester.pumpWidget(
      _wrap(
        sessionApi: _sessionApiReturning(
          dailyXpTarget: 40,
          notificationEnabled: true,
        ),
        sessionRepository: await _signedInSessionRepository(),
        courseApi: courseApi,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('English to Amharic'), findsOneWidget);

    await tester.tap(find.text('Course'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a course'), findsOneWidget);
    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(courseApi.switchCalls, ['c-en-om']);
    expect(find.text('Choose a course'), findsNothing);
    expect(find.text('English to Afaan Oromo'), findsOneWidget);
  });

  testWidgets(
    'a failed course switch keeps the current course and shows a message',
    (tester) async {
      final courseApi = FakeCourseApi()
        ..switchFailure = const CourseApiException('nope');
      await tester.pumpWidget(
        _wrap(
          sessionApi: _sessionApiReturning(
            dailyXpTarget: 40,
            notificationEnabled: true,
          ),
          sessionRepository: await _signedInSessionRepository(),
          courseApi: courseApi,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Course'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('English to Afaan Oromo'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't switch course. Please try again."),
        findsOneWidget,
      );
      expect(find.text('English to Amharic'), findsOneWidget);
    },
  );

  testWidgets('with no course list the row falls back to the language name', (
    tester,
  ) async {
    final courseApi = FakeCourseApi()
      ..failWith = const CourseApiException('offline');
    await tester.pumpWidget(
      _wrap(
        sessionApi: _sessionApiReturning(
          dailyXpTarget: 40,
          notificationEnabled: true,
        ),
        sessionRepository: await _signedInSessionRepository(),
        courseApi: courseApi,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amharic'), findsOneWidget);
  });
}
