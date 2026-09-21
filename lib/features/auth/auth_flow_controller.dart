import 'dart:async';

import '../../shared/services/session_renewer.dart';
import '../../shared/services/session_repository.dart';

/// Where the splash screen should send the user once its session-check
/// resolves.
enum AuthStartDestination {
  /// A valid session exists — skip onboarding entirely.
  home,

  /// No valid session — show the onboarding carousel.
  onboarding,
}

/// The "session-check / routing" service from the implementation plan:
/// reads the stored [SessionState] and turns it into a routing decision,
/// so `SplashScreen` itself only has to call one method and navigate.
///
/// The decision uses only the saved session, so the app opens offline.
/// When signed in, [SessionRenewer] then runs in the background to pick up
/// the server's renewed expiry; routing never waits on it.
class AuthFlowController {
  AuthFlowController({required this._sessionRepository, this._renewer});

  final SessionRepository _sessionRepository;
  final SessionRenewer? _renewer;

  Future<AuthStartDestination> resolveStartDestination() async {
    final session = await _sessionRepository.getSessionState();
    if (!session.isValid) return AuthStartDestination.onboarding;
    final renewer = _renewer;
    if (renewer != null) unawaited(renewer.renew());
    return AuthStartDestination.home;
  }
}
