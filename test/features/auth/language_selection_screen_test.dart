// Language selection screen tests (010-multi-language-courses, bolt 026).
//
// The screen asks "I speak" and "I want to learn" from the public course
// catalog: an Amharic speaker can pick Afaan Oromo and the reverse, coming-soon
// courses are disabled, a catalog failure shows Retry with no silent default,
// and both languages are what gets recorded for sign-in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/auth/screens/language_selection_screen.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/onboarding_repository.dart';
import 'package:elang/shared/widgets/selectable_option_card.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

const _pendingSelectionStorageKey = 'pending_onboarding_selection';

Widget _wrapped(OnboardingRepository repo, CourseApi api) {
  return MaterialApp(
    initialRoute: AuthRoutes.languageSelection,
    routes: {
      AuthRoutes.languageSelection: (_) =>
          LanguageSelectionScreen(onboardingRepository: repo, courseApi: api),
      AuthRoutes.dailyGoalSelection: (_) =>
          const Scaffold(body: Text('DAILY_GOAL_STUB')),
    },
  );
}

SelectableOptionCard _cardFor(WidgetTester tester, String text) {
  return tester.widget<SelectableOptionCard>(
    find
        .ancestor(
          of: find.textContaining(text),
          matching: find.byType(SelectableOptionCard),
        )
        .first,
  );
}

Future<void> _finishOnboardingGoal(
  WidgetTester tester,
  OnboardingRepository repo,
) async {
  // Recording both choices needs the daily goal too; persist it directly.
  await repo.selectDailyGoal(10);
}

void main() {
  late InMemorySecureStorageService storage;
  late OnboardingRepository repo;

  setUp(() {
    storage = InMemorySecureStorageService();
    repo = OnboardingRepository(storage: storage);
  });

  testWidgets('shows a spinner, then the catalog-driven options', (
    tester,
  ) async {
    final api = FakeCourseApi();
    await tester.pumpWidget(_wrapped(repo, api));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(api.catalogCalls, 1);
    expect(find.text('I speak'), findsOneWidget);
    expect(find.text('What do you want to learn?'), findsOneWidget);
  });

  testWidgets('defaults to English and offers the courses taught from it', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapped(repo, FakeCourseApi()));
    await tester.pumpAndSettle();

    // From English: Amharic and Afaan Oromo, Amharic selected by default.
    expect(find.text('English'), findsOneWidget);
    expect(_cardFor(tester, 'Amharic').enabled, isTrue);
    expect(_cardFor(tester, 'Amharic').selected, isTrue);
    expect(_cardFor(tester, 'Afaan Oromo').enabled, isTrue);
    expect(_cardFor(tester, 'Afaan Oromo').selected, isFalse);
  });

  testWidgets(
    'an Amharic speaker is offered Afaan Oromo, with no English step',
    (tester) async {
      await tester.pumpWidget(_wrapped(repo, FakeCourseApi()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('አማርኛ'));
      await tester.pumpAndSettle();

      // Only Afaan Oromo is taught from Amharic.
      expect(find.textContaining('Afaan Oromo ·'), findsOneWidget);
      expect(find.textContaining('Amharic ·'), findsNothing);
      expect(_cardFor(tester, 'Afaan Oromo').selected, isTrue);
    },
  );

  testWidgets(
    'an Afaan Oromo speaker is offered Amharic when it is available',
    (tester) async {
      final api = FakeCourseApi(
        courses: const [
          Course(
            id: 'c-en-am',
            learningLanguage: 'am',
            fromLanguage: 'en',
            title: 'English to Amharic',
          ),
          Course(
            id: 'c-om-am',
            learningLanguage: 'am',
            fromLanguage: 'om',
            title: 'Afaan Oromo to Amharic',
          ),
        ],
      );
      await tester.pumpWidget(_wrapped(repo, api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Afaan Oromoo'));
      await tester.pumpAndSettle();

      expect(_cardFor(tester, 'Amharic').selected, isTrue);
      expect(find.text('Afaan Oromo to Amharic'), findsOneWidget);
    },
  );

  testWidgets('a coming-soon course is disabled with a waitlist button', (
    tester,
  ) async {
    final api = FakeCourseApi(
      courses: const [
        Course(
          id: 'c-en-am',
          learningLanguage: 'am',
          fromLanguage: 'en',
          title: 'English to Amharic',
        ),
        Course(
          id: 'c-en-om',
          learningLanguage: 'om',
          fromLanguage: 'en',
          title: 'English to Afaan Oromo',
          status: CourseStatus.comingSoon,
        ),
      ],
    );
    await tester.pumpWidget(_wrapped(repo, api));
    await tester.pumpAndSettle();

    expect(find.text('COMING SOON'), findsOneWidget);
    expect(find.text('Join Waitlist'), findsOneWidget);
    final card = _cardFor(tester, 'Afaan Oromo');
    expect(card.enabled, isFalse);
    expect(card.selected, isFalse);

    // Tapping it must not change the selection.
    await tester.tap(find.textContaining('Afaan Oromo ·'), warnIfMissed: false);
    await tester.pump();
    expect(_cardFor(tester, 'Amharic').selected, isTrue);

    await tester.tap(find.text('Join Waitlist'));
    await tester.pump();
    expect(
      find.text("You're on the waitlist for Afaan Oromo."),
      findsOneWidget,
    );
  });

  testWidgets(
    'a language that no available course is taught from is not offered as one you speak',
    (tester) async {
      final api = FakeCourseApi(
        courses: const [
          Course(
            id: 'c-en-am',
            learningLanguage: 'am',
            fromLanguage: 'en',
            title: 'English to Amharic',
          ),
          Course(
            id: 'c-om-am',
            learningLanguage: 'am',
            fromLanguage: 'om',
            title: 'Afaan Oromo to Amharic',
            status: CourseStatus.comingSoon,
          ),
        ],
      );
      await tester.pumpWidget(_wrapped(repo, api));
      await tester.pumpAndSettle();

      expect(find.text('Afaan Oromoo'), findsNothing);
      expect(find.text('English'), findsOneWidget);
    },
  );

  testWidgets(
    'a catalog failure shows Retry, a disabled Continue and no default',
    (tester) async {
      final api = FakeCourseApi()
        ..failWith = const CourseApiException('offline');
      await tester.pumpWidget(_wrapped(repo, api));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load the courses."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('I speak'), findsNothing);

      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('DAILY_GOAL_STUB'), findsNothing);

      // Retrying after the backend recovers shows the options.
      api.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('I speak'), findsOneWidget);
    },
  );

  testWidgets('an empty catalog says no courses are available yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapped(
        repo,
        FakeCourseApi(
          courses: const [
            Course(
              id: 'x',
              learningLanguage: 'am',
              fromLanguage: 'en',
              title: 'English to Amharic',
              status: CourseStatus.comingSoon,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No courses are available yet.'), findsOneWidget);
  });

  testWidgets('Continue records both languages and moves to the daily goal', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapped(repo, FakeCourseApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('አማርኛ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('DAILY_GOAL_STUB'), findsOneWidget);
    // Language alone is not enough to persist the pending selection yet.
    expect(storage.values[_pendingSelectionStorageKey], isNull);

    await _finishOnboardingGoal(tester, repo);
    final pending = await repo.loadPendingSelection();
    expect(pending, isNotNull);
    expect(pending!.languageCode, 'om'); // learning Afaan Oromo
    expect(pending.fromLanguageCode, 'am'); // from Amharic
    expect(pending.dailyGoalMinutes, 10);
  });

  testWidgets('English to Amharic is recorded when nothing else is chosen', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapped(repo, FakeCourseApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await _finishOnboardingGoal(tester, repo);

    final pending = await repo.loadPendingSelection();
    expect(pending!.languageCode, 'am');
    expect(pending.fromLanguageCode, 'en');
  });

  for (final width in [360.0, 320.0]) {
    testWidgets('does not overflow at ${width}dp with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: _wrapped(repo, FakeCourseApi()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
