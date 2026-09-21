import 'session_api.dart';
import 'session_repository.dart';

/// Keeps the device's copy of the session's expiry in step with the server.
///
/// The server renews a session each time it is used (at most once a day),
/// so only someone who stays away for the whole 30 days has to sign in
/// again. The app decides at launch whether it is signed in from the expiry
/// it saved -- without a network call, so it opens offline -- which means
/// it has to hear about each renewal, or it would still sign the learner out
/// 30 days after they first signed in.
///
/// [renew] is called in the background at launch and never blocks or
/// throws: offline, or on any failure, the saved expiry just stays as it is
/// until the next launch.
class SessionRenewer {
  SessionRenewer({required this._sessionApi, required this._sessionRepository});

  final SessionApi _sessionApi;
  final SessionRepository _sessionRepository;

  Future<void> renew() async {
    try {
      final before = await _sessionRepository.getSessionState();
      final token = before.token;
      if (token == null || !before.isValid) return;

      final result = await _sessionApi.checkSession(token);
      final expiresAt = result.expiresAt;
      // An invalid session is left for the dashboard to handle: it shows
      // "Please sign in again" rather than being signed out from under.
      if (result.status != SessionCheckStatus.valid || expiresAt == null) {
        return;
      }

      // Signed out or signed in again while the check was in flight: that
      // newer session is not this one to update.
      final now = await _sessionRepository.getSessionState();
      if (now.token != token) return;
      await _sessionRepository.saveSession(now.withExpiresAt(expiresAt));
    } on Object {
      // Renewal is best effort; the saved session is still usable.
    }
  }
}
