import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';
import '../models/pending_onboarding_selection.dart';
import 'auth_api.dart';

/// Real, HTTP-backed [AuthApi] implementation calling the `001-auth-service`
/// endpoints (`POST /api/v1/auth/google`, `POST /api/v1/auth/apple`).
///
/// Deliberately network-only: this class knows nothing about native OAuth
/// SDKs (Google/Apple sign-in plugins) — it only exchanges an already-
/// acquired provider token for a backend session. Token acquisition is the
/// caller's job (see `SignInController`'s `GoogleNativeSignIn`/
/// `AppleNativeSignIn` collaborators), which keeps this class trivially
/// testable with a mocked `http.Client` and no platform plugins involved.
///
/// Never logs tokens, request bodies, or response bodies — only, at most,
/// an HTTP status code — per `coding-standards.md`'s logging discipline.
class HttpAuthApi implements AuthApi {
  HttpAuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  @override
  Future<AuthResult> signInWithGoogle({
    required String idToken,
    PendingOnboardingSelection? pendingSelection,
  }) => _authenticate(
    path: '/api/v1/auth/google',
    tokenField: 'id_token',
    token: idToken,
    pendingSelection: pendingSelection,
  );

  @override
  Future<AuthResult> signInWithApple({
    required String identityToken,
    PendingOnboardingSelection? pendingSelection,
  }) => _authenticate(
    path: '/api/v1/auth/apple',
    tokenField: 'identity_token',
    token: identityToken,
    pendingSelection: pendingSelection,
  );

  Future<AuthResult> _authenticate({
    required String path,
    required String tokenField,
    required String token,
    required PendingOnboardingSelection? pendingSelection,
  }) async {
    final requestBody = <String, dynamic>{
      tokenField: token,
      if (pendingSelection != null)
        'pending_selection': {
          'language': pendingSelection.languageCode,
          'from_language': pendingSelection.fromLanguageCode,
          'daily_goal_minutes': pendingSelection.dailyGoalMinutes,
        },
    };

    http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: _jsonHeaders,
        body: jsonEncode(requestBody),
      );
    } on Object {
      // SocketException, TimeoutException, HandshakeException, etc. — any
      // failure before a response was even received. Per the error-mapping
      // table, all network-level failures map to `networkError`.
      return const AuthFailure(AuthFailureReason.networkError);
    }

    return _mapResponse(response);
  }

  AuthResult _mapResponse(http.Response response) {
    if (response.statusCode == 200) {
      return _parseSuccess(response.body);
    }

    // Error-mapping table (see implementation-plan.md "Technical Approach"):
    //   401 invalid_token / expired_token   -> providerError
    //   400 invalid_pending_selection       -> providerError
    //   502 provider_unreachable           -> networkError (retryable)
    //   any other unexpected status        -> networkError (fail safe)
    switch (response.statusCode) {
      case 401:
      case 400:
        return const AuthFailure(AuthFailureReason.providerError);
      case 502:
        return const AuthFailure(AuthFailureReason.networkError);
      default:
        return const AuthFailure(AuthFailureReason.networkError);
    }
  }

  AuthResult _parseSuccess(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const AuthFailure(AuthFailureReason.networkError);
      }
      final sessionToken = decoded['session_token'];
      if (sessionToken is! String) {
        return const AuthFailure(AuthFailureReason.networkError);
      }
      final expiresAtRaw = decoded['expires_at'];
      final expiresAt = expiresAtRaw is String
          ? DateTime.tryParse(expiresAtRaw)
          : null;
      return AuthSuccess(sessionToken: sessionToken, expiresAt: expiresAt);
    } on FormatException {
      // Malformed/unparseable JSON body on an otherwise-200 response.
      return const AuthFailure(AuthFailureReason.networkError);
    }
  }
}
