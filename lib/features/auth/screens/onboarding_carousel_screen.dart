import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spaceXs),
                      Text(
                        'Buna',
                        style: AppTypography.headlineMd.copyWith(
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _goToLanguageSelection,
                    child: Text(
                      'Skip',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) =>
                      _SlideCard(slide: _slides[index]),
                ),
              ),
              _DotIndicator(count: _slides.length, activeIndex: _currentIndex),
              const SizedBox(height: AppSpacing.spaceMd),
              TactileButton(
                label: _isLastSlide ? 'Get Started' : 'Continue',
                onPressed: _onContinuePressed,
                trailing: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: _goToSignIn,
                    child: Text(
                      'Log In',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceSm),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});

  final _CarouselSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.spaceSm),
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.base),
        border: Border.all(color: AppColors.surfaceDim, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    slide.icon,
                    size: 72,
                    color: AppColors.secondaryContainer,
                  ),
                ),
                Positioned(
                  top: AppSpacing.spaceSm,
                  left: AppSpacing.spaceSm,
                  child: _Chip(label: slide.chipLabel),
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
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceXs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.surfaceDim),
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.primaryContainer,
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryContainer : AppColors.surfaceDim,
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
        );
      }),
    );
  }
}
