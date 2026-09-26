import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../auth_flow_controller.dart';
import '../auth_routes.dart';

/// Buna's splash screen — maps to
/// `stich-screens/.../1._buna_splash_screen/`.
///
/// Runs a "brewing your lessons" progress animation while, in parallel,
/// [AuthFlowController] checks secure storage for a valid session. Once
/// both finish, routes to home (valid session — skips onboarding entirely)
/// or the onboarding carousel (no/invalid session). Tapping "Get Started"
/// finishes early without waiting for the animation.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.authFlowController});

  final AuthFlowController authFlowController;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  AuthStartDestination? _resolvedDestination;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _progressController.addStatusListener(_onAnimationStatusChanged);
    _resolveDestination();
  }

  Future<void> _resolveDestination() async {
    final destination = await widget.authFlowController
        .resolveStartDestination();
    if (!mounted) return;
    _resolvedDestination = destination;
    _maybeNavigate();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _maybeNavigate();
    }
  }

  void _maybeNavigate() {
    if (_navigated || _resolvedDestination == null) return;
    if (!_progressController.isCompleted) return;
    _navigateTo(_resolvedDestination!);
  }

  void _navigateTo(AuthStartDestination destination) {
    if (_navigated) return;
    _navigated = true;
    final routeName = destination == AuthStartDestination.home
        ? AuthRoutes.home
        : AuthRoutes.onboardingCarousel;
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  void _onGetStartedPressed() {
    // Finish early: route by whatever's resolved so far, defaulting to
    // onboarding if the session-check hasn't come back yet.
    _navigateTo(_resolvedDestination ?? AuthStartDestination.onboarding);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      background: AppPageBackground.celebration,
      scrollable: false,
      bottomDock: [
        AppButton.primary(
          label: 'Get Started',
          onPressed: _onGetStartedPressed,
          trailing: const Icon(Icons.arrow_forward, size: 20),
        ),
      ],
      body: LayoutBuilder(
        // The mascot and wordmark sit in the middle of the room left above
        // the brewing card; on a short screen the whole column scrolls.
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: AppSpacing.spaceLg),
                Column(
                  children: [
                    const _Mascot(),
                    const SizedBox(height: AppSpacing.spaceLg),
                    Text(
                      'Buna',
                      style: AppTypography.displayLgMobile.copyWith(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2xs),
                    Text(
                      'Learn Amharic, One Sip at a Time.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.spaceXl),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) =>
                        _BrewingProgress(value: _progressController.value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mockup's mascot tile, with the cup standing in for the mascot art.
class _Mascot extends StatelessWidget {
  const _Mascot();

  static const double size = 140;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: size,
      child: AppCard(
        child: SizedBox(
          height: size - 2 * (AppSpacing.spaceMd + AppCard.borderWidth),
          child: Center(
            child: Icon(
              Icons.local_cafe,
              size: 64,
              color: AppColors.secondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrewingProgress extends StatelessWidget {
  const _BrewingProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).clamp(0, 100).toInt();
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Brewing your lessons...',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.spaceXs),
              CountBadge(label: '$percent%'),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          // Driven frame by frame by the brewing animation, so it does not
          // ease on its own.
          AppProgressBar(
            value: value,
            gradient: true,
            animate: false,
            semanticLabel: 'Brewing your lessons',
          ),
        ],
      ),
    );
  }
}
