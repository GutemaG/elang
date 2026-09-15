import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';

/// The three possible outcomes of a `GET /api/v1/auth/session` call.
enum SessionCheckStatus {
  /// The token is recognized and not expired server-side.
  valid,

  /// The backend responded but the token is unknown/expired
  /// (`{ "valid": false }` — an expected outcome, not an error).
  invalid,

  /// Could not get a definitive answer from the backend (network failure,
  /// unexpected status code, malformed response).
  error,
}

/// The subset of the signed-in user's profile the session endpoint returns.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.selectedLanguage,
    required this.dailyXpTarget,
  });

  final String id;
  final String selectedLanguage;
  final int dailyXpTarget;
}

/// Result of a session-validation call.
class SessionCheckResult {
  const SessionCheckResult.valid(this.user) : status = SessionCheckStatus.valid;

  const SessionCheckResult.invalid()
    : status = SessionCheckStatus.invalid,
      user = null;

  const SessionCheckResult.error()
    : status = SessionCheckStatus.error,
      user = null;

  final SessionCheckStatus status;
  final SessionUser? user;
}

/// Thin client for `GET /api/v1/auth/session`.
///
/// Built per this bolt's acceptance criteria/story reference to the
/// endpoint, but — per the plan's binding "Checkpoint Decisions" — **not**
/// wired into `AuthFlowController`'s splash-time routing. `AuthFlowController`
/// keeps using only the locally-stored session's expiry (no network call at
/// launch); this client sits unused until a future feature actually needs
/// server-side session revocation detection.
class SessionApi {
  SessionApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Validates [sessionToken] against the backend. Never throws — any
  /// network-level or parsing failure resolves to
  /// [SessionCheckStatus.error] rather than propagating a raw exception.
  Future<SessionCheckResult> checkSession(String sessionToken) async {
    http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl/api/v1/auth/session'),
        headers: {'Authorization': 'Bearer $sessionToken'},
      );
    } on Object {
      return const SessionCheckResult.error();
    }

    if (response.statusCode != 200) {
      return const SessionCheckResult.error();
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const SessionCheckResult.error();
      }
      if (decoded['valid'] != true) {
        return const SessionCheckResult.invalid();
      }
      final user = decoded['user'];
      if (user is! Map<String, dynamic>) {
        return const SessionCheckResult.error();
      }
      final id = user['id'];
      final selectedLanguage = user['selected_language'];
      final dailyXpTarget = user['daily_xp_target'];
      if (id is! String ||
          selectedLanguage is! String ||
          dailyXpTarget is! int) {
        return const SessionCheckResult.error();
      }
      return SessionCheckResult.valid(
        SessionUser(
          id: id,
          selectedLanguage: selectedLanguage,
          dailyXpTarget: dailyXpTarget,
        ),
      );
    } on FormatException {
      return const SessionCheckResult.error();
    }
  }
}
