/// Thrown by [HttpLessonApi] on any backend/network failure.
///
/// `LessonApi`'s methods (unlike `AuthApi`'s) have no sealed
/// success/failure result type -- `getSkillTree`/`startLesson`/
/// `getBeansStatus`/`completeLesson` already surface errors as thrown
/// exceptions, caught generically by the screens' existing `FutureBuilder`/
/// try-catch handling (see `007-core-lesson-loop-ui`'s implementation
/// plan). This is that exception: one type, regardless of whether the
/// failure was a non-2xx response or a network-level error (timeout, no
/// connectivity), since none of today's call sites need to distinguish
/// further than "show a generic error and let the user retry."
class LessonApiException implements Exception {
  const LessonApiException(this.message, {this.errorCode});

  final String message;

  /// The backend's `error_code` field, when the failure was a parsed
  /// error response (e.g. `beans_exhausted`, `skill_locked`). `null` for
  /// network-level failures or unparseable responses.
  final String? errorCode;

  @override
  String toString() => 'LessonApiException($errorCode: $message)';
}
