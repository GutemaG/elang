import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';
import '../services/session_repository.dart';

/// Thrown by [AccountSettingsApi.update] when the change wasn't saved.
class AccountSettingsException implements Exception {
  const AccountSettingsException(this.message);

  final String message;

  @override
  String toString() => 'AccountSettingsException($message)';
}

/// Writes account settings (022-light-and-dark-themes, FR-8), first used by
/// "Show me in leagues" (023-weekly-leagues, story 007).
abstract class AccountSettingsApi {
  /// `PATCH /api/v1/users/me/settings` with [changes]; returns every
  /// setting as now stored. Throws [AccountSettingsException].
  Future<Map<String, Object?>> update(Map<String, Object?> changes);
}

/// The real [AccountSettingsApi]: the session token is read on every
/// request, and nothing but a status is ever reported.
class HttpAccountSettingsApi implements AccountSettingsApi {
  HttpAccountSettingsApi({
    required this._sessionRepository,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final SessionRepository _sessionRepository;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<Map<String, Object?>> update(Map<String, Object?> changes) async {
    final token = (await _sessionRepository.getSessionState()).token;
    if (token == null || token.isEmpty) {
      throw const AccountSettingsException('No session token available');
    }
    final http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse('$_baseUrl/api/v1/users/me/settings'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(changes),
          )
          .timeout(AuthConfig.requestTimeout);
    } on Object {
      throw const AccountSettingsException('Network request failed');
    }
    if (response.statusCode != 200) {
      throw AccountSettingsException('Request failed (${response.statusCode})');
    }
    try {
      final decoded = jsonDecode(response.body);
      final settings = decoded is Map<String, dynamic>
          ? decoded['settings']
          : null;
      if (settings is Map<String, dynamic>) return settings;
    } on FormatException {
      // Falls through.
    }
    throw const AccountSettingsException('Malformed response body');
  }
}
