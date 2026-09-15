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
class AuthFlowController {
  AuthFlowController({required this._sessionRepository});

  final SessionRepository _sessionRepository;

  Future<AuthStartDestination> resolveStartDestination() async {
    final session = await _sessionRepository.getSessionState();
    return session.isValid
        ? AuthStartDestination.home
        : AuthStartDestination.onboarding;
  }
}
