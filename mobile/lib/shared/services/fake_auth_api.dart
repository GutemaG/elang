import '../models/pending_onboarding_selection.dart';
import 'auth_api.dart';

/// In-memory stand-in for the real `001-auth-service` client.
///
/// `001-auth-service` hasn't published its API contract yet (see this
/// bolt's `implementation-plan.md` Dependencies section), so the sign-in
/// screen is built and exercised against this fake instead of a real
/// network call. Swap in a real `AuthApi` implementation once that
/// contract lands — no call site outside this file should need to change.
class FakeAuthApi implements AuthApi {
  FakeAuthApi({
    this.latency = const Duration(milliseconds: 900),
    this.failureReason,
  });

  /// Simulated network latency before resolving, so the sign-in screen's
  /// in-flight/disabled-buttons state is actually observable.
  final Duration latency;

  /// When non-null, every call resolves to this failure instead of
  /// succeeding. Intended for manually exercising the inline error/retry
  /// UI during development; leave null for the normal "everything works"
  /// path.
  final AuthFailureReason? failureReason;

  @override
  Future<AuthResult> signInWithGoogle({
    required String idToken,
    PendingOnboardingSelection? pendingSelection,
  }) => _resolve();

  @override
  Future<AuthResult> signInWithApple({
    required String identityToken,
    PendingOnboardingSelection? pendingSelection,
  }) => _resolve();

  Future<AuthResult> _resolve() async {
    await Future<void>.delayed(latency);
    if (failureReason != null) {
      return AuthFailure(failureReason!);
    }
    return AuthSuccess(
      sessionToken: 'fake-session-token',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }
}
