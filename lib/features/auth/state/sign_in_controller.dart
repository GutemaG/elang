import 'package:flutter/foundation.dart';

import '../../../shared/models/session_state.dart';
import '../../../shared/services/auth_api.dart';
import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/services/session_repository.dart';
import 'native_sign_in.dart';

/// Screen-local sign-in state, modeled as an enum per the implementation
/// plan rather than as a route: the inline error/retry banner lives on the
/// same screen, it never navigates to a dedicated error screen.
enum SignInStatus { idle, inFlight, errorCancelled, errorFailed }

/// Drives the sign-in screen's Google/Apple buttons and inline error/retry
/// banner.
///
/// Owns the "only one OAuth flow in flight at a time" guard (story 003's
/// "tap Google then Apple" edge case) and the "pending selection survives
/// failure/retry untouched" behavior (story 004) — the latter falls out
/// naturally here because failure handling never calls into
/// [OnboardingRepository] at all.
class SignInController extends ChangeNotifier {
  SignInController({
    required this._authApi,
    required this._onboardingRepository,
    required this._sessionRepository,
    NativeSignIn? googleSignIn,
    NativeSignIn? appleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleNativeSignIn(),
       _appleSignIn = appleSignIn ?? AppleNativeSignIn();

  final AuthApi _authApi;
  final OnboardingRepository _onboardingRepository;
  final SessionRepository _sessionRepository;

  /// Native token-acquisition collaborators — real plugin wrappers by
  /// default, injectable for tests. See `native_sign_in.dart`.
  final NativeSignIn _googleSignIn;
  final NativeSignIn _appleSignIn;

  SignInStatus _status = SignInStatus.idle;
  AuthProvider? _lastAttemptedProvider;

  SignInStatus get status => _status;
  bool get isInFlight => _status == SignInStatus.inFlight;

  /// Attempts a sign-in with [provider]. No-ops if a flow is already
  /// in-flight, so double-tapping (or tapping the other provider mid-flow)
  /// can't start a second concurrent attempt.
  Future<void> signIn(AuthProvider provider) async {
    if (_status == SignInStatus.inFlight) return;

    _lastAttemptedProvider = provider;
    _status = SignInStatus.inFlight;
    notifyListeners();

    // Acquire a real provider token via the native SDK first. Only on
    // success do we proceed into the AuthApi/network call below — a
    // cancellation or SDK-level failure short-circuits without ever
    // touching the network, per the implementation plan.
    final String token;
    try {
      token = switch (provider) {
        AuthProvider.google => await _googleSignIn.signIn(),
        AuthProvider.apple => await _appleSignIn.signIn(),
      };
    } on NativeSignInCancelledException {
      _status = SignInStatus.errorCancelled;
      notifyListeners();
      return;
    } on NativeSignInFailedException catch (e) {
      // Never log token contents — only the (non-PII) failure message.
      debugPrint('Native sign-in failed: ${e.message}');
      _status = SignInStatus.errorFailed;
      notifyListeners();
      return;
    }

    await _completeWithToken(provider, token);
  }

  /// Completes a sign-in for a token that was already acquired outside the
  /// normal [signIn] path — specifically, Web's rendered Google button
  /// (`GoogleWebSignInButton`), which Google requires the user to click
  /// directly rather than one triggered programmatically from our own
  /// button. That widget acquires the ID token itself and hands it here,
  /// skipping the native-SDK step in [signIn] entirely.
  Future<void> completeWithExternallyAcquiredToken(
    AuthProvider provider,
    String token,
  ) async {
    if (_status == SignInStatus.inFlight) return;
    _lastAttemptedProvider = provider;
    _status = SignInStatus.inFlight;
    notifyListeners();
    await _completeWithToken(provider, token);
  }

  Future<void> _completeWithToken(AuthProvider provider, String token) async {
    final pendingSelection = await _onboardingRepository.loadPendingSelection();

    final result = switch (provider) {
      AuthProvider.google => await _authApi.signInWithGoogle(
        idToken: token,
        pendingSelection: pendingSelection,
      ),
      AuthProvider.apple => await _authApi.signInWithApple(
        identityToken: token,
        pendingSelection: pendingSelection,
      ),
    };

    switch (result) {
      case AuthSuccess(sessionToken: final token, expiresAt: final expiresAt):
        await _sessionRepository.saveSession(
          SessionState(
            token: token,
            expiresAt: expiresAt,
            authProvider: provider.name,
          ),
        );
        _status = SignInStatus.idle;
        notifyListeners();
        onSignedIn?.call();
      case AuthFailure(reason: final reason):
        // Never log the token/pending-selection contents here — only the
        // failure reason, which carries no PII.
        debugPrint('Sign-in attempt failed: $reason');
        _status = reason == AuthFailureReason.cancelled
            ? SignInStatus.errorCancelled
            : SignInStatus.errorFailed;
        notifyListeners();
    }
  }

  /// Re-triggers whichever provider's flow last failed.
  Future<void> retry() async {
    final provider = _lastAttemptedProvider;
    if (provider == null) return;
    await signIn(provider);
  }

  /// Invoked once a sign-in succeeds and the session has been persisted.
  /// The screen wires this to its navigation callback.
  VoidCallback? onSignedIn;
}
