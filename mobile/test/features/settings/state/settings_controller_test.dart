// Tests for `SettingsController` (`005-profile-and-settings`): loading
// current settings, optimistic-update/revert-on-failure for each of the
// three server-backed preferences, the local sound toggle, the
// minutes<->xp reverse-mapping, and logout.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/settings/state/settings_controller.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/user_preferences_api.dart';
import 'package:elang/shared/services/user_preferences_api_exception.dart';

import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

SessionApi _sessionApiReturning({
  required String selectedLanguage,
  required int dailyXpTarget,
  required bool notificationEnabled,
}) {
  return SessionApi(
    client: MockClient((request) async {
      return http.Response(
        jsonEncode({
          'valid': true,
          'user': {
            'id': 'user-1',
            'selected_language': selectedLanguage,
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

SessionApi _invalidSessionApi() {
  return SessionApi(
    client: MockClient((request) async {
      return http.Response(
        jsonEncode({'valid': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

Future<SessionRepository> _signedInSessionRepository({String? authProvider}) async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'session-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: authProvider,
    ),
  );
  return repo;
}

void main() {
  group('load', () {
    test('populates all fields on success, reverse-mapping xp target to minutes', () async {
      final sessionRepository = await _signedInSessionRepository(authProvider: 'google');
      final controller = SettingsController(
        courseApi: FakeCourseApi(),
        sessionApi: _sessionApiReturning(
          selectedLanguage: 'am',
          dailyXpTarget: 60,
          notificationEnabled: false,
        ),
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: sessionRepository,
      );

      await controller.load();

      expect(controller.loadStatus, SettingsLoadStatus.loaded);
      expect(controller.selectedLanguage, 'am');
      expect(controller.dailyGoalMinutes, 15); // 60 xp -> Serious/15min
      expect(controller.notificationEnabled, false);
      expect(controller.soundEnabled, true); // default
      expect(controller.authProvider, 'google');
    });

    test('an invalid session sets an error load status', () async {
      final controller = SettingsController(
        courseApi: FakeCourseApi(),
        sessionApi: _invalidSessionApi(),
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: await _signedInSessionRepository(),
      );

      await controller.load();

      expect(controller.loadStatus, SettingsLoadStatus.error);
    });

    test('no stored token sets an error load status without calling SessionApi', () async {
      var called = false;
      final controller = SettingsController(
        courseApi: FakeCourseApi(),
        sessionApi: SessionApi(
          client: MockClient((request) async {
            called = true;
            return http.Response('', 200);
          }),
        ),
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: SessionRepository(storage: InMemorySecureStorageService()),
      );

      await controller.load();

      expect(controller.loadStatus, SettingsLoadStatus.error);
      expect(called, isFalse);
    });
  });

  group('active course', () {
    test('load reads the active course from the course list', () async {
      final controller = SettingsController(
        courseApi: FakeCourseApi(activeCourseId: 'c-en-om'),
        sessionApi: _sessionApiReturning(
          selectedLanguage: 'om',
          dailyXpTarget: 40,
          notificationEnabled: true,
        ),
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: await _signedInSessionRepository(),
      );

      await controller.load();

      expect(controller.loadStatus, SettingsLoadStatus.loaded);
      expect(controller.activeCourse?.id, 'c-en-om');
    });

    test('a course list that cannot be loaded still loads the settings', () async {
      final controller = SettingsController(
        courseApi: FakeCourseApi()..failWith = const CourseApiException('offline'),
        sessionApi: _sessionApiReturning(
          selectedLanguage: 'am',
          dailyXpTarget: 40,
          notificationEnabled: true,
        ),
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: await _signedInSessionRepository(),
      );

      await controller.load();

      expect(controller.loadStatus, SettingsLoadStatus.loaded);
      expect(controller.activeCourse, isNull);
      expect(controller.selectedLanguage, 'am');
    });

    test('applySwitchedCourse adopts the new course and its language', () async {
      final controller = await _loadedController();

      controller.applySwitchedCourse(FakeCourseApi.defaultCourses[1]);

      expect(controller.activeCourse?.id, 'c-en-om');
      expect(controller.selectedLanguage, 'om');
    });
  });

  group('updateDailyGoalMinutes', () {
    test('adopts the backend-returned xp target on success', () async {
      final userPreferencesApi = FakeUserPreferencesApi()
        ..nextResult = const UpdatedPreferences(
          selectedLanguage: 'am',
          dailyXpTarget: 80,
          notificationEnabled: true,
        );
      final controller = await _loadedController(userPreferencesApi: userPreferencesApi);

      await controller.updateDailyGoalMinutes(20);

      expect(controller.dailyGoalMinutes, 20);
      expect(userPreferencesApi.calls.single.dailyGoalMinutes, 20);
    });

    test('reverts the optimistic value on failure', () async {
      final userPreferencesApi = FakeUserPreferencesApi()
        ..nextException = const UserPreferencesApiException('nope');
      final controller = await _loadedController(
        userPreferencesApi: userPreferencesApi,
        initialDailyXpTarget: 40, // Regular/10min
      );

      await controller.updateDailyGoalMinutes(20); // optimistically -> Intense

      expect(controller.dailyGoalMinutes, 10); // reverted to the original preset
      expect(controller.errorMessage, isNotNull);
    });
  });

  group('updateNotificationEnabled', () {
    test('adopts the backend-returned value on success', () async {
      final userPreferencesApi = FakeUserPreferencesApi()
        ..nextResult = const UpdatedPreferences(
          selectedLanguage: 'am',
          dailyXpTarget: 40,
          notificationEnabled: false,
        );
      final controller = await _loadedController(userPreferencesApi: userPreferencesApi);

      await controller.updateNotificationEnabled(false);

      expect(controller.notificationEnabled, false);
      expect(userPreferencesApi.calls.single.notificationEnabled, false);
    });

    test('reverts on failure', () async {
      final userPreferencesApi = FakeUserPreferencesApi()
        ..nextException = const UserPreferencesApiException('nope');
      final controller = await _loadedController(
        userPreferencesApi: userPreferencesApi,
        initialNotificationEnabled: true,
      );

      await controller.updateNotificationEnabled(false);

      expect(controller.notificationEnabled, true);
      expect(controller.errorMessage, isNotNull);
    });
  });

  group('updateSoundEnabled', () {
    test('persists locally and is readable back from the same repository', () async {
      final soundPreferenceRepository = SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      );
      final controller = await _loadedController(
        soundPreferenceRepository: soundPreferenceRepository,
      );

      await controller.updateSoundEnabled(false);

      expect(controller.soundEnabled, false);
      expect(await soundPreferenceRepository.getSoundEnabled(), false);
    });
  });

  group('logout', () {
    test('clears the stored session', () async {
      final sessionRepository = await _signedInSessionRepository();
      final controller = SettingsController(
        courseApi: FakeCourseApi(),
        sessionApi: _sessionApiReturning(
          selectedLanguage: 'am',
          dailyXpTarget: 40,
          notificationEnabled: true,
        ),
        userPreferencesApi: FakeUserPreferencesApi(),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: sessionRepository,
      );

      await controller.logout();

      final after = await sessionRepository.getSessionState();
      expect(after.token, isNull);
    });
  });
}

/// Builds a controller that's already successfully loaded, for tests that
/// only care about the update methods' behavior.
Future<SettingsController> _loadedController({
  FakeUserPreferencesApi? userPreferencesApi,
  SoundPreferenceRepository? soundPreferenceRepository,
  String initialLanguage = 'am',
  int initialDailyXpTarget = 40,
  bool initialNotificationEnabled = true,
}) async {
  final controller = SettingsController(
    courseApi: FakeCourseApi(),
    sessionApi: _sessionApiReturning(
      selectedLanguage: initialLanguage,
      dailyXpTarget: initialDailyXpTarget,
      notificationEnabled: initialNotificationEnabled,
    ),
    userPreferencesApi: userPreferencesApi ?? FakeUserPreferencesApi(),
    soundPreferenceRepository:
        soundPreferenceRepository ??
        SoundPreferenceRepository(storage: InMemorySecureStorageService()),
    sessionRepository: await _signedInSessionRepository(),
  );
  await controller.load();
  return controller;
}
