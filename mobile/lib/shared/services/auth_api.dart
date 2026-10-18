import '../models/pending_onboarding_selection.dart';

/// Which native OAuth provider a sign-in call was made with.
enum AuthProvider { google, apple }

/// Domain-level reasons a sign-in attempt can fail. The UI never sees raw
/// HTTP/SDK exceptions — only this enum — per `coding-standards.md`'s
/// Flutter error-handling convention.
enum AuthFailureReason {
  /// The user dismissed the native OAuth sheet themselves.
  cancelled,

  /// Could not reach the backend (offline, timeout, 5xx, etc.).
  networkError,

  /// The provider (Google/Apple) itself rejected/errored the request.
  providerError,
}

/// Result of a sign-in attempt: either a new session, or a typed failure.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess({required this.sessionToken, this.expiresAt});

  final String sessionToken;
  final DateTime? expiresAt;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;
}

/// The auth-service boundary this UI needs, independent of whichever
/// concrete backend contract `001-auth-service` eventually ships.
///
/// This is intentionally a thin interface: two calls, one per supported
/// provider, each accepting the provider's token plus any pending
/// onboarding selection to attach on first-time account creation. Once
/// `001-auth-service` publishes its real contract, only the concrete
/// implementation behind this interface needs to change — screens and
/// state classes built against [AuthApi] should not need to change.
abstract class AuthApi {
  Future<AuthResult> signInWithGoogle({
    required String idToken,
    PendingOnboardingSelection? pendingSelection,
  });

  Future<AuthResult> signInWithApple({
    required String identityToken,
    PendingOnboardingSelection? pendingSelection,
  });
}
