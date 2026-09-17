import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';
import 'session_repository.dart';
import 'user_preferences_api.dart';
import 'user_preferences_api_exception.dart';

/// Real, HTTP-backed [UserPreferencesApi] calling
/// `013-user-preferences-service`'s `PATCH /api/v1/users/me`.
///
/// Mirrors [HttpLessonApi]'s structure exactly: every call is authenticated,
/// so the session token is read fresh from [SessionRepository] on every
/// request rather than baked in at construction. Never logs tokens, request
/// bodies, or response bodies -- only, at most, an HTTP status code.
class HttpUserPreferencesApi implements UserPreferencesApi {
  HttpUserPreferencesApi({
    required SessionRepository sessionRepository,
    http.Client? client,
    String? baseUrl,
  }) : _sessionRepository = sessionRepository,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final SessionRepository _sessionRepository;
  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _sessionRepository.getSessionState();
    final token = session.token;
    if (token == null || token.isEmpty) {
      // Unreachable in practice -- Settings is only ever reached via the
      // authenticated `home` route -- but a cheap, correct guard beats
      // sending a request guaranteed to 401.
      throw const UserPreferencesApiException(
        'No session token available',
        errorCode: 'missing_credentials',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  @override
  Future<UpdatedPreferences> updatePreferences({
    String? language,
    int? dailyGoalMinutes,
    bool? notificationEnabled,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{
      if (language != null) 'language': language,
      if (dailyGoalMinutes != null) 'daily_goal_minutes': dailyGoalMinutes,
      if (notificationEnabled != null) 'notification_enabled': notificationEnabled,
    };

    http.Response response;
    try {
      response = await _client.patch(
        Uri.parse('$_baseUrl/api/v1/users/me'),
        headers: headers,
        body: jsonEncode(body),
      );
    } on Object {
      throw const UserPreferencesApiException('Network request failed');
    }

    if (response.statusCode != 200) {
      throw _errorFrom(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const UserPreferencesApiException('Malformed response body');
    }
    final selectedLanguage = decoded['selected_language'];
    final dailyXpTarget = decoded['daily_xp_target'];
    final resultNotificationEnabled = decoded['notification_enabled'];
    if (selectedLanguage is! String ||
        dailyXpTarget is! int ||
        resultNotificationEnabled is! bool) {
      throw const UserPreferencesApiException('Malformed response body');
    }
    return UpdatedPreferences(
      selectedLanguage: selectedLanguage,
      dailyXpTarget: dailyXpTarget,
      notificationEnabled: resultNotificationEnabled,
    );
  }

  UserPreferencesApiException _errorFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final errorCode = decoded['error_code'];
        final message = decoded['message'];
        return UserPreferencesApiException(
          message is String ? message : 'Request failed (${response.statusCode})',
          errorCode: errorCode is String ? errorCode : null,
        );
      }
    } on FormatException {
      // Fall through to the generic exception below.
    }
    return UserPreferencesApiException('Request failed (${response.statusCode})');
  }
}
