// Tests for `HttpAuthApi`'s error-mapping table (see the implementation
// plan's "Technical Approach" section): every documented backend error code
// plus network-level/malformed-response failures must map to the correct
// `AuthFailureReason`, and a 200 response must parse into `AuthSuccess`.
//
// Uses `package:http/testing.dart`'s `MockClient` rather than a real socket
// — mocking at the network boundary only, per `coding-standards.md`'s
// testing convention.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/models/pending_onboarding_selection.dart';
import 'package:elang/shared/services/auth_api.dart';
import 'package:elang/shared/services/http_auth_api.dart';

void main() {
  group('signInWithGoogle', () {
    test('a 200 response parses into AuthSuccess', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/google');
        final decodedBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decodedBody['id_token'], 'real-google-id-token');
        expect(decodedBody.containsKey('pending_selection'), isFalse);

        return http.Response(
          jsonEncode({
            'session_token': 'session-abc',
            'expires_at': '2026-10-01T00:00:00.000Z',
            'user': {
              'id': 'user-1',
              'selected_language': 'am',
              'daily_xp_target': 20,
              'is_new_user': true,
            },
          }),
          200,
        );
      });
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(
        idToken: 'real-google-id-token',
      );

      expect(result, isA<AuthSuccess>());
      final success = result as AuthSuccess;
      expect(success.sessionToken, 'session-abc');
      expect(success.expiresAt, DateTime.parse('2026-10-01T00:00:00.000Z'));
    });

    test('a pending selection is attached to the request body', () async {
      final client = MockClient((request) async {
        final decodedBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decodedBody['pending_selection'], {
          'language': 'am',
          'from_language': 'en',
          'daily_goal_minutes': 10,
        });
        return http.Response(
          jsonEncode({
            'session_token': 'tok',
            'expires_at': '2026-10-01T00:00:00.000Z',
            'user': {
              'id': 'u',
              'selected_language': 'am',
              'daily_xp_target': 10,
              'is_new_user': true,
            },
          }),
          200,
        );
      });
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(
        idToken: 'tok',
        pendingSelection: const PendingOnboardingSelection(
          languageCode: 'am',
          dailyGoalMinutes: 10,
        ),
      );

      expect(result, isA<AuthSuccess>());
    });

    test('401 invalid_token maps to providerError', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error_code': 'invalid_token', 'message': 'bad token'}),
          401,
        ),
      );
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(idToken: 'x');

      expect(result, const AuthFailure(AuthFailureReason.providerError));
    });

    test('401 expired_token maps to providerError', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error_code': 'expired_token', 'message': 'expired'}),
          401,
        ),
      );
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(idToken: 'x');

      expect(result, const AuthFailure(AuthFailureReason.providerError));
    });

    test('400 invalid_pending_selection maps to providerError', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error_code': 'invalid_pending_selection',
            'message': 'unsupported language',
          }),
          400,
        ),
      );
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(idToken: 'x');

      expect(result, const AuthFailure(AuthFailureReason.providerError));
    });

    test('502 provider_unreachable maps to networkError', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error_code': 'provider_unreachable',
            'message': 'upstream down',
          }),
          502,
        ),
      );
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(idToken: 'x');

      expect(result, const AuthFailure(AuthFailureReason.networkError));
    });

    test('an unexpected status code maps to networkError', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(idToken: 'x');

      expect(result, const AuthFailure(AuthFailureReason.networkError));
    });

    test(
      'a malformed JSON body on a 200 response maps to networkError',
      () async {
        final client = MockClient(
          (request) async => http.Response('not json at all', 200),
        );
        final api = HttpAuthApi(
          client: client,
          baseUrl: 'http://localhost:8000',
        );

        final result = await api.signInWithGoogle(idToken: 'x');

        expect(result, const AuthFailure(AuthFailureReason.networkError));
      },
    );

    test('a 200 response missing session_token maps to networkError', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'oops': true}), 200),
      );
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithGoogle(idToken: 'x');

      expect(result, const AuthFailure(AuthFailureReason.networkError));
    });

    test(
      'a network-level failure (client throws) maps to networkError',
      () async {
        final client = MockClient((request) async {
          throw http.ClientException('Connection failed');
        });
        final api = HttpAuthApi(
          client: client,
          baseUrl: 'http://localhost:8000',
        );

        final result = await api.signInWithGoogle(idToken: 'x');

        expect(result, const AuthFailure(AuthFailureReason.networkError));
      },
    );
  });

  group('signInWithApple', () {
    test('posts to /api/v1/auth/apple with identity_token', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/apple');
        final decodedBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decodedBody['identity_token'], 'apple-identity-token');

        return http.Response(
          jsonEncode({
            'session_token': 'tok',
            'expires_at': '2026-10-01T00:00:00.000Z',
            'user': {
              'id': 'u',
              'selected_language': 'am',
              'daily_xp_target': 10,
              'is_new_user': false,
            },
          }),
          200,
        );
      });
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithApple(
        identityToken: 'apple-identity-token',
      );

      expect(result, isA<AuthSuccess>());
    });

    test('provider_unreachable maps to networkError', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error_code': 'provider_unreachable',
            'message': 'upstream down',
          }),
          502,
        ),
      );
      final api = HttpAuthApi(client: client, baseUrl: 'http://localhost:8000');

      final result = await api.signInWithApple(identityToken: 'x');

      expect(result, const AuthFailure(AuthFailureReason.networkError));
    });
  });
}
