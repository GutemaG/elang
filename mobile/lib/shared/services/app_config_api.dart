import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';

/// Thin client for `GET /api/v1/config` (022-light-and-dark-themes, FR-9):
/// app-wide values, no sign-in needed.
class AppConfigApi {
  AppConfigApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// The configuration map, or `null` offline, on any error status, or on a
  /// body that isn't `{"config": {...}}`. Never throws.
  Future<Map<String, Object?>?> fetch() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/v1/config'))
          .timeout(AuthConfig.requestTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final config = decoded['config'];
      return config is Map<String, dynamic> ? config : null;
    } on Object {
      return null;
    }
  }
}
