import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../shared/config/auth_config.dart';
import '../../shared/services/session_repository.dart';

/// What a piece of feedback is about (027-learner-feedback). [wire] is the
/// name the backend takes.
enum FeedbackCategory {
  bug('bug'),
  idea('idea'),
  content('content'),
  other('other');

  const FeedbackCategory(this.wire);

  final String wire;
}

/// Thrown by [FeedbackApi] on any failure. [tooMany] is the backend saying
/// the learner has sent enough for today.
class FeedbackApiException implements Exception {
  const FeedbackApiException(this.message, {this.tooMany = false});

  final String message;
  final bool tooMany;

  @override
  String toString() => 'FeedbackApiException($message)';
}

/// Sends feedback to `POST /api/v1/feedback` (027-learner-feedback). The
/// backend adds the learner's current course itself.
abstract class FeedbackApi {
  /// Throws [FeedbackApiException].
  Future<void> send({
    required FeedbackCategory category,
    required String message,
    int? rating,
  });
}

/// The real [FeedbackApi]. Like `HttpLeagueApi`, it reads the session token
/// on every request and never logs tokens or bodies.
class HttpFeedbackApi implements FeedbackApi {
  HttpFeedbackApi({
    required this._sessionRepository,
    http.Client? client,
    String? baseUrl,
    String? platform,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl,
       _platform = platform ?? _currentPlatform();

  final SessionRepository _sessionRepository;
  final http.Client _client;
  final String _baseUrl;
  final String _platform;

  static String _currentPlatform() =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  @override
  Future<void> send({
    required FeedbackCategory category,
    required String message,
    int? rating,
  }) async {
    final token = (await _sessionRepository.getSessionState()).token;
    if (token == null || token.isEmpty) {
      throw const FeedbackApiException('No session token available');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/feedback'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'category': category.wire,
              'message': message,
              'rating': rating,
              'platform': _platform,
            }),
          )
          .timeout(AuthConfig.requestTimeout);
    } on Object {
      throw const FeedbackApiException('Network request failed');
    }
    if (response.statusCode == 429) {
      throw const FeedbackApiException('Too much today', tooMany: true);
    }
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw FeedbackApiException('Request failed (${response.statusCode})');
    }
  }
}
