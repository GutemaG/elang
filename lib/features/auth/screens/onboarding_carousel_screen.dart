import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../auth_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/l10n/app_language.dart';

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

/// The three slides, in the app language [l]. The chips are Fidel with its
/// sound, the same in every language.
List<_CarouselSlide> _slidesIn(AppLocalizations l) => [
  _CarouselSlide(
    icon: Icons.menu_book,
    title: l.onboardingSlide1Title,
    body: l.onboardingSlide1Body,
    chipLabel: 'ሀ ha',
  ),
  _CarouselSlide(
    icon: Icons.local_fire_department,
    title: l.onboardingSlide2Title,
    body: l.onboardingSlide2Body,
    chipLabel: 'ቡ bu',
  ),
  _CarouselSlide(
    icon: Icons.volume_up,
    title: l.onboardingSlide3Title,
    body: l.onboardingSlide3Body,
    chipLabel: 'ሂ hi',
  ),
];

const int _slideCount = 3;

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

  bool get _isLastSlide => _currentIndex == _slideCount - 1;

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
          AppButton.text(
            label: context.l10n.skip,
            onPressed: _goToLanguageSelection,
          ),
        ],
      ),
      scrollable: false,
      bottomDock: [
        AppButton.primary(
          label: _isLastSlide
              ? context.l10n.getStarted
              : context.l10n.continueButton,
          onPressed: _onContinuePressed,
          trailing: const Icon(Icons.arrow_forward, size: 20),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              context.l10n.alreadyHaveAccount,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            AppButton.text(label: context.l10n.logIn, onPressed: _goToSignIn),
          ],
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slideCount,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) =>
                  _SlideCard(slide: _slidesIn(context.l10n)[index]),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          PageDots(count: _slideCount, index: _currentIndex),
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
                      color: context.colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space2xs),
                  Text(
                    slide.body,
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.onSurfaceVariant,
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
