import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as siwa;

import '../../../shared/config/auth_config.dart';

/// Thrown by a [NativeSignIn] collaborator when the user dismisses the
/// native OAuth sheet themselves, before any provider token exists.
///
/// Distinguished from [NativeSignInFailedException] so `SignInController`
/// can map cancellation directly to `SignInStatus.errorCancelled` without
/// ever calling `AuthApi` — cancellation is a client-side, pre-network
/// event.
class NativeSignInCancelledException implements Exception {
  const NativeSignInCancelledException();
}

/// Thrown for any other native-SDK failure: misconfigured plugin, platform
/// channel error, unsupported platform, or an unrecognized SDK response.
/// Maps to `SignInStatus.errorFailed`.
class NativeSignInFailedException implements Exception {
  const NativeSignInFailedException(this.message);

  final String message;

  @override
  String toString() => 'NativeSignInFailedException: $message';
}

/// Minimal shape `SignInController` depends on to acquire a provider token.
///
/// Kept deliberately small (`Future<String> signIn()`) so `SignInController`
/// stays testable against a fake implementation, and so `HttpAuthApi`
/// remains free of any native-plugin dependency (see that class's doc
/// comment).
abstract class NativeSignIn {
  /// Returns the acquired provider token (Google ID token / Apple identity
  /// token) on success.
  ///
  /// Throws [NativeSignInCancelledException] if the user dismissed the
  /// native sheet, or [NativeSignInFailedException] for any other failure.
  Future<String> signIn();
}

/// Wraps `google_sign_in`'s native OAuth flow. Wired on both Android and
/// iOS — Google Sign-In has no platform restriction in this bolt.
class GoogleNativeSignIn implements NativeSignIn {
  GoogleNativeSignIn({gsi.GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? gsi.GoogleSignIn.instance;

  final gsi.GoogleSignIn _googleSignIn;
  Future<void>? _initializing;

  /// Ensures `initialize()` has been called exactly once, regardless of how
  /// many callers await it concurrently. Exposed (not just used internally
  /// by [signIn]) because the Web rendered-button flow
  /// (`GoogleWebSignInButton`) must also await this before calling
  /// `renderButton()` — GIS's button requires the client to already be
  /// initialized.
  Future<void> ensureInitialized() {
    return _initializing ??= _googleSignIn.initialize(
      clientId: AuthConfig.googleClientId,
      // `google_sign_in_web` asserts this must be null — unsupported on
      // Web. Not needed there anyway: the app initializes Web with the
      // same client ID the backend verifies against, so the issued ID
      // token's audience already matches without it. Android/iOS still
      // need it, since their initiating client differs from the
      // verifying (Web) client.
      serverClientId: kIsWeb ? null : AuthConfig.googleServerClientId,
    );
  }

  /// Stream of ID tokens from Web's rendered-button flow.
  ///
  /// On Web, `authenticate()` always throws (see [signIn]) — GIS requires
  /// the click to land directly on Google's own rendered button, not one
  /// triggered programmatically from ours. That button reports its result
  /// through this broadcast stream instead of a returned `Future`, which is
  /// why the Web-only sign-in path (`GoogleWebSignInButton`) is wired to
  /// this rather than to [signIn].
  Stream<String> get webSignInTokens => _googleSignIn.authenticationEvents
      .where((event) => event is gsi.GoogleSignInAuthenticationEventSignIn)
      .cast<gsi.GoogleSignInAuthenticationEventSignIn>()
      .map((event) => event.user.authentication.idToken)
      .where((idToken) => idToken != null)
      .cast<String>();

  @override
  Future<String> signIn() async {
    try {
      await ensureInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const NativeSignInFailedException(
          'Google Sign-In succeeded but returned no ID token',
        );
      }
      return idToken;
    } on gsi.GoogleSignInException catch (e) {
      if (e.code == gsi.GoogleSignInExceptionCode.canceled) {
        throw const NativeSignInCancelledException();
      }
      throw NativeSignInFailedException(
        e.description ?? 'Google Sign-In failed (${e.code})',
      );
    } on NativeSignInCancelledException {
      rethrow;
    } on NativeSignInFailedException {
      rethrow;
    } catch (e) {
      // Anything else (e.g. no platform implementation registered — the
      // plugin isn't configured for this build/device) — fail gracefully
      // rather than let a raw platform error surface, per this story's
      // "native SDK plugin not configured" edge case.
      throw NativeSignInFailedException('Google Sign-In failed: $e');
    }
  }
}

/// Wraps `sign_in_with_apple`'s native OAuth flow.
///
/// **iOS only**, per this bolt's binding checkpoint decision: Sign in with
/// Apple's Android/web variant requires a hosted HTTPS redirect page that
/// does not exist in this project, so it is deferred rather than
/// half-wired. On any non-iOS platform, [signIn] throws
/// [NativeSignInFailedException] immediately (surfacing as the existing
/// "Something went wrong" inline error) rather than invoking the plugin at
/// all — callers/UI must not crash if the Apple button is tapped there.
class AppleNativeSignIn implements NativeSignIn {
  AppleNativeSignIn({bool? isIOS})
    : _isIOS = isIOS ?? (defaultTargetPlatform == TargetPlatform.iOS);

  final bool _isIOS;

  @override
  Future<String> signIn() async {
    if (!_isIOS) {
      throw const NativeSignInFailedException(
        'Sign in with Apple is not available on this platform yet',
      );
    }

    try {
      final credential = await siwa.SignInWithApple.getAppleIDCredential(
        scopes: const [siwa.AppleIDAuthorizationScopes.email],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        throw const NativeSignInFailedException(
          'Sign in with Apple succeeded but returned no identity token',
        );
      }
      return identityToken;
    } on siwa.SignInWithAppleAuthorizationException catch (e) {
      if (e.code == siwa.AuthorizationErrorCode.canceled) {
        throw const NativeSignInCancelledException();
      }
      throw NativeSignInFailedException(
        'Sign in with Apple failed (${e.code}): ${e.message}',
      );
    } on siwa.SignInWithAppleException catch (e) {
      throw NativeSignInFailedException('Sign in with Apple failed: $e');
    } on NativeSignInCancelledException {
      rethrow;
    } on NativeSignInFailedException {
      rethrow;
    } catch (e) {
      // Anything else (e.g. no platform implementation registered) — fail
      // gracefully rather than let a raw platform error surface, per this
      // story's "native SDK plugin not configured" edge case.
      throw NativeSignInFailedException('Sign in with Apple failed: $e');
    }
  }
}
