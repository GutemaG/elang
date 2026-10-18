// Tests for `HttpUserPreferencesApi`: request shape sent to
// `013-user-preferences-service`'s `PATCH /api/v1/users/me`, response
// parsing, and error mapping (`UserPreferencesApiException`).
//
// Uses `package:http/testing.dart`'s `MockClient`, mocking at the network
// boundary only -- same convention as `http_lesson_api_test.dart`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/user_preferences_api_exception.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

Future<SessionRepository> _signedInSessionRepository() async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'session-token-abc',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  return repo;
}

void main() {
  test('sends a PATCH with only the provided fields, attaching the session token', () async {
    final sessionRepository = await _signedInSessionRepository();
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/users/me');
      expect(request.headers['Authorization'], 'Bearer session-token-abc');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {'daily_goal_minutes': 15});
      return http.Response(
        jsonEncode({
          'id': 'user-1',
          'selected_language': 'am',
          'daily_xp_target': 60,
          'notification_enabled': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = HttpUserPreferencesApi(sessionRepository: sessionRepository, client: client);

    final result = await api.updatePreferences(dailyGoalMinutes: 15);

    expect(result.selectedLanguage, 'am');
    expect(result.dailyXpTarget, 60);
    expect(result.notificationEnabled, true);
  });

  test('an empty update sends an empty body', () async {
    final sessionRepository = await _signedInSessionRepository();
    final client = MockClient((request) async {
      expect(jsonDecode(request.body), <String, dynamic>{});
      return http.Response(
        jsonEncode({
          'id': 'user-1',
          'selected_language': 'am',
          'daily_xp_target': 40,
          'notification_enabled': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = HttpUserPreferencesApi(sessionRepository: sessionRepository, client: client);

    await api.updatePreferences();
  });

  test('a 422 invalid_preference_value response throws with that error code', () async {
    final sessionRepository = await _signedInSessionRepository();
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error_code': 'invalid_preference_value',
          'message': 'Unsupported language code',
        }),
        422,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = HttpUserPreferencesApi(sessionRepository: sessionRepository, client: client);

    await expectLater(
      api.updatePreferences(language: 'xx'),
      throwsA(
        isA<UserPreferencesApiException>().having(
          (e) => e.errorCode,
          'errorCode',
          'invalid_preference_value',
        ),
      ),
    );
  });

  test('a network failure throws UserPreferencesApiException', () async {
    final sessionRepository = await _signedInSessionRepository();
    final client = MockClient((request) async {
      throw Exception('socket closed');
    });
    final api = HttpUserPreferencesApi(sessionRepository: sessionRepository, client: client);

    await expectLater(
      api.updatePreferences(notificationEnabled: false),
      throwsA(isA<UserPreferencesApiException>()),
    );
  });

  test('no session token throws UserPreferencesApiException without making a request', () async {
    final sessionRepository = SessionRepository(storage: InMemorySecureStorageService());
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('', 200);
    });
    final api = HttpUserPreferencesApi(sessionRepository: sessionRepository, client: client);

    await expectLater(
      api.updatePreferences(notificationEnabled: true),
      throwsA(isA<UserPreferencesApiException>()),
    );
    expect(called, isFalse);
  });
}
