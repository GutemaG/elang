// Tests for `SessionApi.checkSession` -- first real coverage of this
// previously-unused client (see its docstring), now consumed by
// `SettingsScreen` (`014-profile-and-settings-ui`) to read current
// language/daily-goal/notification state on load.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/services/session_api.dart';

void main() {
  test('a valid session parses selected_language/daily_xp_target/notification_enabled', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/auth/session');
      expect(request.headers['Authorization'], 'Bearer tok-123');
      return http.Response(
        jsonEncode({
          'valid': true,
          'user': {
            'id': 'user-1',
            'selected_language': 'am',
            'daily_xp_target': 60,
            'notification_enabled': false,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SessionApi(client: client);

    final result = await api.checkSession('tok-123');

    expect(result.status, SessionCheckStatus.valid);
    expect(result.user!.id, 'user-1');
    expect(result.user!.selectedLanguage, 'am');
    expect(result.user!.dailyXpTarget, 60);
    expect(result.user!.notificationEnabled, false);
  });

  test('{"valid": false} maps to SessionCheckStatus.invalid, not an error', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'valid': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SessionApi(client: client);

    final result = await api.checkSession('unknown-tok');

    expect(result.status, SessionCheckStatus.invalid);
    expect(result.user, isNull);
  });

  test('a non-200 status maps to SessionCheckStatus.error', () async {
    final client = MockClient((request) async => http.Response('', 401));
    final api = SessionApi(client: client);

    final result = await api.checkSession('tok');

    expect(result.status, SessionCheckStatus.error);
  });

  test('a response missing notification_enabled maps to SessionCheckStatus.error', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'valid': true,
          'user': {'id': 'user-1', 'selected_language': 'am', 'daily_xp_target': 40},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SessionApi(client: client);

    final result = await api.checkSession('tok');

    expect(result.status, SessionCheckStatus.error);
  });

  test('a network failure maps to SessionCheckStatus.error without throwing', () async {
    final client = MockClient((request) async => throw Exception('no route to host'));
    final api = SessionApi(client: client);

    final result = await api.checkSession('tok');

    expect(result.status, SessionCheckStatus.error);
  });
}
