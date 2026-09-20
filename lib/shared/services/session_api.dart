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
    required this.notificationEnabled,
    this.activeCourseId,
  });

  final String id;

  /// The user's active course (010-multi-language-courses); `null` for an
  /// older backend that does not send one.
  final String? activeCourseId;
  final String selectedLanguage;
  final int dailyXpTarget;

  /// New in `013-user-preferences-service`. Stored, functionally inert —
  /// see `005-profile-and-settings`'s requirements for why.
  final bool notificationEnabled;
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
/// launch). As of `014-profile-and-settings-ui`, `SettingsScreen` is the
/// first real consumer — it calls [checkSession] on load to read the
/// account's current language/daily-goal/notification state, since bolt
/// `013-user-preferences-service` deliberately didn't add a redundant GET
/// endpoint for that.
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
      final notificationEnabled = user['notification_enabled'];
      if (id is! String ||
          selectedLanguage is! String ||
          dailyXpTarget is! int ||
          notificationEnabled is! bool) {
        return const SessionCheckResult.error();
      }
      return SessionCheckResult.valid(
        SessionUser(
          id: id,
          selectedLanguage: selectedLanguage,
          dailyXpTarget: dailyXpTarget,
          notificationEnabled: notificationEnabled,
          activeCourseId: user['active_course_id'] is String
              ? user['active_course_id'] as String
              : null,
        ),
      );
    } on FormatException {
      return const SessionCheckResult.error();
    }
  }
}
