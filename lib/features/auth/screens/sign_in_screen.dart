import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../shared/services/auth_api.dart';
import '../../../shared/services/onboarding_repository.dart';
import '../../../shared/services/session_repository.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../auth_routes.dart';
import '../state/native_sign_in.dart';
import '../state/sign_in_controller.dart';
import '../widgets/google_web_sign_in_button.dart';

/// Sign-in / create-account screen — maps to
/// `stich-screens/.../5._create_account_sign_in/`.
///
/// Google and Apple are rendered as two visually-identical pill buttons
/// (equal size/weight/border, Google above Apple per the export). The
/// inline error/retry banner is the same Stitch export's "Quiet Inline
/// Error State Variant" — there is no separate error screen/route; failure
/// is just a state on this screen (see [SignInController]).
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.authApi,
    required this.onboardingRepository,
    required this.sessionRepository,
    this.googleSignIn,
    this.appleSignIn,
  });

  final AuthApi authApi;
  final OnboardingRepository onboardingRepository;
  final SessionRepository sessionRepository;

  /// Native token-acquisition collaborators. Left `null` in the real app so
  /// [SignInController] defaults to the real `google_sign_in`/
  /// `sign_in_with_apple` wrappers — overridable here purely so tests can
  /// substitute a fake without ever touching a real platform plugin.
  final NativeSignIn? googleSignIn;
  final NativeSignIn? appleSignIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final SignInController _controller;
  late final NativeSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    // Shared with the Web rendered-button widget below (when applicable) —
    // both need the same underlying `GoogleNativeSignIn` instance so its
    // lazy `initialize()` only runs once.
    _googleSignIn = widget.googleSignIn ?? GoogleNativeSignIn();
    _controller = SignInController(
      authApi: widget.authApi,
      onboardingRepository: widget.onboardingRepository,
      sessionRepository: widget.sessionRepository,
      googleSignIn: _googleSignIn,
      appleSignIn: widget.appleSignIn,
    )..onSignedIn = _onSignedIn;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() => setState(() {});

  /// On Web, swaps the custom-styled Google button for Google's own
  /// rendered button — required there since `authenticate()` always throws
  /// (see `GoogleWebSignInButton`'s doc comment). Mobile/desktop keep the
  /// custom button, unaffected.
  Widget _buildGoogleButton() {
    final googleSignIn = _googleSignIn;
    if (kIsWeb && googleSignIn is GoogleNativeSignIn) {
      return GoogleWebSignInButton(
        googleSignIn: googleSignIn,
        onTokenAcquired: (token) => _controller
            .completeWithExternallyAcquiredToken(AuthProvider.google, token),
      );
    }
    return AppButton.secondary(
      label: 'Continue with Google',
      onPressed: _controller.isInFlight
          ? null
          : () => _controller.signIn(AuthProvider.google),
      leading: const _GoogleGlyph(),
    );
  }

  void _onSignedIn() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AuthRoutes.home);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _controller.status;
    final showError =
        status == SignInStatus.errorCancelled ||
        status == SignInStatus.errorFailed;

    return AppPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create your free account',
            style: AppTypography.headlineLg.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            'Save your streak, sync your progress across devices, and '
            'start speaking Amharic today.',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          _buildGoogleButton(),
          const SizedBox(height: AppSpacing.spaceSm),
          AppButton.secondary(
            label: 'Continue with Apple',
            onPressed: _controller.isInFlight
                ? null
                : () => _controller.signIn(AuthProvider.apple),
            leading: const Icon(
              Icons.apple,
              size: 22,
              color: AppColors.onSurface,
            ),
          ),
          if (showError) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            _InlineErrorBanner(status: status, onRetry: _controller.retry),
          ],
          const SizedBox(height: AppSpacing.spaceXl),
          Center(
            child: Text(
              'By continuing you agree to our Terms of Service & Privacy '
              'Policy.',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// The mockup's "quiet inline error": a warm banner with Retry inside it.
class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.status, required this.onRetry});

  final SignInStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Cancel-tone (neutral, "you cancelled") vs. failure-tone (apologetic,
    // "something went wrong") per story 004's technical note.
    final String message = status == SignInStatus.errorCancelled
        ? 'Sign-in was cancelled'
        : 'Something went wrong — try again';

    return InfoBanner(
      icon: Icons.info_outline,
      message: message,
      tone: AppTone.secondary,
      action: AppButton.secondary(
        label: 'Retry',
        onPressed: onRetry,
        leading: const Icon(Icons.refresh, size: 18),
        expand: false,
        size: AppButtonSize.compact,
      ),
    );
  }
}

/// Minimal Google "G" mark rendered from shapes rather than a bundled
/// asset, since no image assets ship with this bolt.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Icon(Icons.g_mobiledata, size: 22, color: AppColors.onSurface),
    );
  }
}
