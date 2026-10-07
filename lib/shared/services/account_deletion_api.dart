import 'package:http/http.dart' as http;

import '../config/auth_config.dart';
import 'session_repository.dart';

/// Thrown by [AccountDeletionApi.deleteAccount] when the account was not
/// deleted.
class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => 'AccountDeletionException($message)';
}

/// Deletes the signed-in account and everything stored for it, as both app
/// stores require of an app with sign-in.
abstract class AccountDeletionApi {
  /// `DELETE /api/v1/users/me`. Throws [AccountDeletionException].
  Future<void> deleteAccount();
}

/// The real [AccountDeletionApi]: the session token is read on the request,
/// and nothing but a status is ever reported.
class HttpAccountDeletionApi implements AccountDeletionApi {
  HttpAccountDeletionApi({
    required this._sessionRepository,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final SessionRepository _sessionRepository;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<void> deleteAccount() async {
    final token = (await _sessionRepository.getSessionState()).token;
    if (token == null || token.isEmpty) {
      throw const AccountDeletionException('No session token available');
    }
    final http.Response response;
    try {
      response = await _client
          .delete(
            Uri.parse('$_baseUrl/api/v1/users/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(AuthConfig.requestTimeout);
    } on Object {
      throw const AccountDeletionException('Network request failed');
    }
    if (response.statusCode != 204) {
      throw AccountDeletionException('Request failed (${response.statusCode})');
    }
  }
}
