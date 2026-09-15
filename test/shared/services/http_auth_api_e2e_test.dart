// REAL end-to-end integration test — requires a running backend.
//
// Unlike `http_auth_api_test.dart` (which mocks `http.Client` and never
// touches a socket), this file uses Dart's real `http.Client` to send
// actual HTTP requests to a real, running instance of the `backend/`
// FastAPI app on `http://localhost:8000` (matching `AuthConfig.apiBaseUrl`).
// It will FAIL — with connection-refused errors, not assertion failures —
// if the backend is not running. It is intentionally excluded from being
// "just another unit test": it belongs to the integration-test class of
// this project's suite, not the pure/mocked unit-test class.
//
// To run the backend locally before running this file:
//
//   cd backend
//   uv run alembic upgrade head   # first time only / fresh DB
//   uv run uvicorn app.main:app --port 8000
//
// Then, from the repo root:
//
//   flutter test test/shared/services/http_auth_api_e2e_test.dart
//
// ---------------------------------------------------------------------------
// SCOPE / WHAT THIS DOES AND DOES NOT PROVE
// ---------------------------------------------------------------------------
// There are no real Google/Apple OAuth credentials in this environment, so
// this file CANNOT and does NOT attempt a genuine full success round-trip
// (real provider token -> real verified account). `GoogleTokenVerifier` /
// `AppleTokenVerifier` would reject any token we could construct here as
// `invalid_token`, same as a garbage string.
//
// What this file DOES prove, against the real running server process (no
// mocks on either side):
//   - Sending an obviously-garbage token to `/api/v1/auth/google` and
//     `/apple` gets a REAL 401 `{"error_code":"invalid_token",...}` response,
//     and `HttpAuthApi` correctly parses that real response into
//     `AuthFailure(AuthFailureReason.providerError)`. This proves the
//     request-shape (field names) AND the error-response-shape genuinely
//     agree between the two sides — not just that each side matches its own
//     documentation/mocks independently.
//   - `GET /api/v1/auth/session` with no `Authorization` header, and with a
//     malformed one, really returns 401 `missing_credentials` — and that
//     `SessionApi` (via the equivalent empty-token call, since `SessionApi`'s
//     public API always sends *some* Authorization header) handles a real
//     401 without throwing, resolving to `SessionCheckStatus.error`.
//   - `GET /api/v1/auth/session` with a garbage-but-present Bearer token
//     really returns `200 {"valid": false}` (not a 401) — confirming this
//     exact documented-as-tricky real-server behavior, and that `SessionApi`
//     maps it to `SessionCheckStatus.invalid`.
//   - A malformed (non-JSON) request body against `/api/v1/auth/google`
//     really returns a `422` (FastAPI/Pydantic's own validation-error shape)
//     — NOT one of the four documented domain error codes. This was not
//     explicitly specced anywhere read for this bolt; it is a genuine
//     real-server discovery, recorded here and in `test-walkthrough.md`.
//     (`HttpAuthApi` itself never constructs a malformed body, so this
//     status is never actually produced by real app usage — but it is
//     worth knowing that if it ever were, `HttpAuthApi`'s `_mapResponse`
//     `default` branch would map it to `networkError`.)
//
// What this file explicitly does NOT prove:
//   - That a real Google/Apple ID token verifies successfully end-to-end.
//   - That `AuthSuccess` parsing (the 200 path) works against a REAL
//     verified-provider response — that remains verified only via Stage 2's
//     mocked tests in `http_auth_api_test.dart`, which construct a synthetic
//     200 response. This is the same limitation already documented in
//     `memory-bank/bolts/001-auth-service/ddd-03-test-report.md`'s Issues
//     Found section.
//   - Anything about the native Google/Apple SDK collaborators
//     (`GoogleNativeSignIn`/`AppleNativeSignIn`) — those remain covered only
//     by `sign_in_controller_native_test.dart`'s fakes; no native platform
//     plugin can run in this test environment at all.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:elang/shared/services/auth_api.dart';
import 'package:elang/shared/services/http_auth_api.dart';
import 'package:elang/shared/services/session_api.dart';

const _baseUrl = 'http://localhost:8000';

void main() {
  group('HttpAuthApi against a real running backend', () {
    test(
      'a garbage Google ID token gets a real 401 invalid_token, mapped to providerError',
      () async {
        final api = HttpAuthApi(baseUrl: _baseUrl);

        final result = await api.signInWithGoogle(
          idToken: 'this-is-not-a-real-jwt-garbage-token',
        );

        expect(result, const AuthFailure(AuthFailureReason.providerError));
      },
    );

    test(
      'a garbage Apple identity token gets a real 401 invalid_token, mapped to providerError',
      () async {
        final api = HttpAuthApi(baseUrl: _baseUrl);

        final result = await api.signInWithApple(
          identityToken: 'this-is-not-a-real-jwt-garbage-token',
        );

        expect(result, const AuthFailure(AuthFailureReason.providerError));
      },
    );
  });

  group('SessionApi against a real running backend', () {
    test(
      'a missing/empty Authorization value gets a real 401 missing_credentials, '
      'and SessionApi resolves to error without throwing',
      () async {
        final api = SessionApi(baseUrl: _baseUrl);

        // SessionApi.checkSession always sends *some* Authorization header
        // ("Bearer <token>"); passing an empty token produces "Bearer "
        // (whitespace-only after the scheme), which the real backend treats
        // identically to a missing header (see raw-request test below for
        // the literal no-header case).
        final result = await api.checkSession('');

        expect(result.status, SessionCheckStatus.error);
      },
    );

    test(
      'a garbage but present Bearer token gets a real 200 {valid:false}, '
      'mapped to SessionCheckStatus.invalid (not an error)',
      () async {
        final api = SessionApi(baseUrl: _baseUrl);

        final result = await api.checkSession('totally-garbage-session-token');

        expect(result.status, SessionCheckStatus.invalid);
      },
    );

    test(
      'raw request with literally no Authorization header gets a real 401 missing_credentials',
      () async {
        final client = http.Client();
        try {
          final response = await client.get(
            Uri.parse('$_baseUrl/api/v1/auth/session'),
          );

          expect(response.statusCode, 401);
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          expect(decoded['error_code'], 'missing_credentials');
        } finally {
          client.close();
        }
      },
    );

    test(
      'raw request with a malformed (non-Bearer) Authorization header gets a real 401',
      () async {
        final client = http.Client();
        try {
          final response = await client.get(
            Uri.parse('$_baseUrl/api/v1/auth/session'),
            headers: {'Authorization': 'garbage-not-bearer-scheme'},
          );

          expect(response.statusCode, 401);
        } finally {
          client.close();
        }
      },
    );
  });

  group('Real-server discoveries beyond the documented error-mapping table', () {
    test(
      'a malformed (non-JSON) request body to /api/v1/auth/google gets a 422, '
      'not one of the 4 documented domain error codes',
      () async {
        final client = http.Client();
        try {
          final response = await client.post(
            Uri.parse('$_baseUrl/api/v1/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: 'not json at all',
          );

          // FastAPI/Pydantic's own request-validation error, distinct from
          // the domain-level 401/400/502 error codes this bolt's error-
          // mapping table documents. HttpAuthApi never produces a malformed
          // body itself, so this path is unreachable through real app usage
          // — but it's worth recording precisely what the real server does.
          expect(response.statusCode, 422);
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          expect(decoded.containsKey('detail'), isTrue);
        } finally {
          client.close();
        }
      },
    );

    test(
      'a request missing the required id_token field also gets a 422',
      () async {
        final client = http.Client();
        try {
          final response = await client.post(
            Uri.parse('$_baseUrl/api/v1/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{}),
          );

          expect(response.statusCode, 422);
        } finally {
          client.close();
        }
      },
    );
  });
}
