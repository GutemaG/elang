/// Thrown by [HttpUserPreferencesApi] on any backend/network failure.
///
/// Mirrors `LessonApiException`'s shape exactly (message + backend
/// `error_code`, one type regardless of failure kind) under its own name,
/// since that class's docstring specifically scopes it to `LessonApi`.
class UserPreferencesApiException implements Exception {
  const UserPreferencesApiException(this.message, {this.errorCode});

  final String message;

  /// The backend's `error_code` field (e.g. `invalid_preference_value`,
  /// `invalid_session`), when the failure was a parsed error response.
  /// `null` for network-level failures or unparseable responses.
  final String? errorCode;

  @override
  String toString() => 'UserPreferencesApiException($errorCode: $message)';
}
