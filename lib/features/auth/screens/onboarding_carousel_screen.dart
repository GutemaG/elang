import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../auth_routes.dart';

class _CarouselSlide {
  const _CarouselSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.chipLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final String chipLabel;
}

const List<_CarouselSlide> _slides = [
  _CarouselSlide(
    icon: Icons.menu_book,
    title: 'Bite-Sized Amharic',
    body:
        'Master Fidel syllabaries and confident daily conversations in '
        'just 5 minutes a day.',
    chipLabel: 'ሀ ha',
  ),
  _CarouselSlide(
    icon: Icons.local_fire_department,
    title: 'Stay Motivated with Streaks',
    body:
        'Earn XP, keep your streak alive, and climb the Highlands map as '
        'you learn.',
    chipLabel: 'ቡ bu',
  ),
  _CarouselSlide(
    icon: Icons.volume_up,
    title: 'Learn Real Dialects',
    body:
        "Practice with authentic native-speaker audio from Addis Ababa's "
        'Merkato market.',
    chipLabel: 'ሂ hi',
  ),
];

/// The skippable, 3-slide onboarding carousel — maps to
/// `stich-screens/.../2._onboarding_carousel/`.
///
/// Per the plan's Checkpoint Decisions, this screen intentionally has no
/// cross-screen "step N of M" chrome; its own 3-dot indicator is
/// screen-local. Slide position is not persisted — reopening the app
/// always restarts the carousel from slide 1 (story 001 edge case).
class OnboardingCarouselScreen extends StatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  State<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  bool get _isLastSlide => _currentIndex == _slides.length - 1;

  void _goToLanguageSelection() {
    Navigator.of(context).pushReplacementNamed(AuthRoutes.languageSelection);
  }

  void _goToSignIn() {
    Navigator.of(context).pushNamed(AuthRoutes.signIn);
  }

  void _onContinuePressed() {
    if (_isLastSlide) {
      _goToLanguageSelection();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      topBar: AppTopBar.brand(
        trailing: [
          AppButton.text(label: 'Skip', onPressed: _goToLanguageSelection),
        ],
      ),
      scrollable: false,
      bottomDock: [
        AppButton.primary(
          label: _isLastSlide ? 'Get Started' : 'Continue',
          onPressed: _onContinuePressed,
          trailing: const Icon(Icons.arrow_forward, size: 20),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Already have an account?',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            AppButton.text(label: 'Log In', onPressed: _goToSignIn),
          ],
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) =>
                  _SlideCard(slide: _slides[index]),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          PageDots(count: _slides.length, index: _currentIndex),
          const SizedBox(height: AppSpacing.spaceSm),
        ],
      ),
    );
  }
}

/// One slide: the mockup's raised card with the Tibeb stripe, the
/// illustration (an icon in place of the art) with its letter chip, the
/// title and the body. A slide taller than the room scrolls.
class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});

  final _CarouselSlide slide;

  static const double illustrationSize = 160;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceSm),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 2 * AppSpacing.spaceSm,
          ),
          child: Center(
            child: AppCard(
              topStripe: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: illustrationSize,
                    child: Stack(
                      children: [
                        Center(
                          child: IconBadge(
                            icon: slide.icon,
                            tone: AppTone.secondary,
                            size: illustrationSize,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          child: CountBadge(label: slide.chipLabel),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  Text(
                    slide.title,
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space2xs),
                  Text(
                    slide.body,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
