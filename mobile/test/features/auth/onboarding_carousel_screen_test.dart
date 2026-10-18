// Onboarding carousel tests.
//
// Covers: the carousel is skippable via "Skip", advances through slides via
// swipe and via the "Continue"/"Get Started" CTA, and reaching the end
// proceeds to language selection — matching story
// 001-splash-and-onboarding-carousel's acceptance criteria.
//
// `OnboardingCarouselScreen` takes no constructor dependencies, so it's
// pumped directly per the task's "individual screen widgets" instruction.
// It does call `Navigator.of(context).pushReplacementNamed`/`pushNamed`, so
// each test wraps it in a minimal `MaterialApp` route table with stub
// destination screens (not the full app/route table) purely so those calls
// have somewhere to land.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/auth/screens/onboarding_carousel_screen.dart';

Widget _wrapped() {
  return MaterialApp(
    initialRoute: AuthRoutes.onboardingCarousel,
    routes: {
      AuthRoutes.onboardingCarousel: (_) => const OnboardingCarouselScreen(),
      AuthRoutes.languageSelection: (_) =>
          const Scaffold(body: Text('LANGUAGE_SELECTION_STUB')),
      AuthRoutes.signIn: (_) => const Scaffold(body: Text('SIGN_IN_STUB')),
    },
  );
}

void main() {
  testWidgets('tapping Skip proceeds directly to language selection', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapped());

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('LANGUAGE_SELECTION_STUB'), findsOneWidget);
  });

  testWidgets('the "Log In" escape hatch proceeds to sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapped());

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN_IN_STUB'), findsOneWidget);
  });

  testWidgets('swiping advances to the next slide', (tester) async {
    await tester.pumpWidget(_wrapped());

    expect(find.text('Bite-Sized Amharic'), findsOneWidget);
    expect(find.text('Stay Motivated with Streaks'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Stay Motivated with Streaks'), findsOneWidget);
    expect(find.text('Bite-Sized Amharic'), findsNothing);
  });

  testWidgets(
    'tapping Continue through every slide then reaching the end proceeds to language selection',
    (tester) async {
      await tester.pumpWidget(_wrapped());

      // Slide 1 of 3: label is "Continue".
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Slide 2 of 3.
      expect(find.text('Stay Motivated with Streaks'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Slide 3 of 3 (last slide): the CTA becomes "Get Started".
      expect(find.text('Learn Real Dialects'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('LANGUAGE_SELECTION_STUB'), findsOneWidget);
    },
  );
}
