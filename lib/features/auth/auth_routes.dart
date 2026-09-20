import 'package:flutter/material.dart';

import 'auth_dependencies.dart';
import 'screens/daily_goal_selection_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/onboarding_carousel_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';

/// Route table for the auth/onboarding flow.
///
/// The flow is strictly linear (splash -> carousel -> language -> goal ->
/// sign-in) with two branch points — a valid session skips straight from
/// splash to home, and the carousel's "Log In" link skips straight to
/// sign-in — so a flat named-route table plus [Navigator.pushReplacementNamed]
/// is enough; no routing package is pulled in for this.
abstract final class AuthRoutes {
  static const String splash = '/';
  static const String onboardingCarousel = '/onboarding';
  static const String languageSelection = '/onboarding/language';
  static const String dailyGoalSelection = '/onboarding/daily-goal';
  static const String signIn = '/sign-in';
  static const String home = '/home';

  /// Builds the full route table for [MaterialApp.routes], with every auth
  /// screen wired to the shared [AuthDependencies] bag.
  ///
  /// [homeBuilder] builds whatever the post-sign-in / valid-session
  /// destination is — as of `006-core-lesson-loop-ui` that's the skill-tree
  /// dashboard, not the old `HomePlaceholderScreen`. This route table stays
  /// deliberately agnostic to what that destination is: `splash_screen.dart`
  /// and `sign_in_screen.dart` only ever navigate to the [home] route
  /// *name*, never to a concrete widget.
  static Map<String, WidgetBuilder> build(
    AuthDependencies deps, {
    required WidgetBuilder homeBuilder,
  }) {
    return {
      splash: (context) =>
          SplashScreen(authFlowController: deps.authFlowController),
      onboardingCarousel: (context) => const OnboardingCarouselScreen(),
      languageSelection: (context) => LanguageSelectionScreen(
        onboardingRepository: deps.onboardingRepository,
        courseApi: deps.courseApi,
      ),
      dailyGoalSelection: (context) => DailyGoalSelectionScreen(
        onboardingRepository: deps.onboardingRepository,
      ),
      signIn: (context) => SignInScreen(
        authApi: deps.authApi,
        onboardingRepository: deps.onboardingRepository,
        sessionRepository: deps.sessionRepository,
      ),
      home: homeBuilder,
    };
  }
}
