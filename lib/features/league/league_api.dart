import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/config/auth_config.dart';
import '../../shared/services/session_repository.dart';
import 'league_models.dart';

/// Thrown by [LeagueApi] on any failure: offline, a non-200 status, or a
/// body that isn't a league.
class LeagueApiException implements Exception {
  const LeagueApiException(this.message);

  final String message;

  @override
  String toString() => 'LeagueApiException($message)';
}

/// The weekly league endpoints (023-weekly-leagues).
abstract class LeagueApi {
  /// `GET /api/v1/leagues/current`. Throws [LeagueApiException].
  Future<CurrentLeague> current();
}

/// The real [LeagueApi]. Like `HttpUserPreferencesApi`, it reads the
/// session token on every request and never logs tokens or bodies.
class HttpLeagueApi implements LeagueApi {
  HttpLeagueApi({
    required this._sessionRepository,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final SessionRepository _sessionRepository;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<CurrentLeague> current() async {
    final token = (await _sessionRepository.getSessionState()).token;
    if (token == null || token.isEmpty) {
      throw const LeagueApiException('No session token available');
    }
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$_baseUrl/api/v1/leagues/current'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(AuthConfig.requestTimeout);
    } on Object {
      throw const LeagueApiException('Network request failed');
    }
    if (response.statusCode != 200) {
      throw LeagueApiException('Request failed (${response.statusCode})');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const LeagueApiException('Malformed response body');
    }
    final league = CurrentLeague.fromJson(decoded);
    if (league == null) {
      throw const LeagueApiException('Malformed response body');
    }
    return league;
  }
}
