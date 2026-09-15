// Daily goal selection screen tests.
//
// Covers story 002's acceptance criteria: all 4 presets render; Regular
// (10 min) is selected by default; selecting a different preset changes
// the selection; and the combined "no partial state" edge case — nothing
// is written to secure storage until *both* language and daily goal are
// known (OnboardingRepository's contract), verified end-to-end by driving
// the language screen and then this screen against the same repository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/auth/screens/daily_goal_selection_screen.dart';
import 'package:elang/features/auth/screens/language_selection_screen.dart';
import 'package:elang/shared/services/onboarding_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

const _pendingSelectionStorageKey = 'pending_onboarding_selection';

Widget _wrapped(OnboardingRepository repo) {
  return MaterialApp(
    initialRoute: AuthRoutes.dailyGoalSelection,
    routes: {
      AuthRoutes.dailyGoalSelection: (_) =>
          DailyGoalSelectionScreen(onboardingRepository: repo),
      AuthRoutes.signIn: (_) => const Scaffold(body: Text('SIGN_IN_STUB')),
    },
  );
}

void main() {
  testWidgets('renders all 4 daily-goal presets', (tester) async {
    final repo = OnboardingRepository(storage: InMemorySecureStorageService());
    await tester.pumpWidget(_wrapped(repo));

    expect(find.textContaining('Casual'), findsOneWidget);
    expect(find.textContaining('Regular'), findsOneWidget);
    expect(find.textContaining('Serious'), findsOneWidget);
    expect(find.textContaining('Intense'), findsOneWidget);
  });

  testWidgets('Regular (10 min) is selected by default', (tester) async {
    final repo = OnboardingRepository(storage: InMemorySecureStorageService());
    await tester.pumpWidget(_wrapped(repo));

    // First establish the language, so the combined pending selection is
    // observable once this screen's Continue is tapped.
    await repo.selectLanguage('am');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final pending = await repo.loadPendingSelection();
    expect(pending, isNotNull);
    expect(pending!.dailyGoalMinutes, 10);
  });

  testWidgets('selecting a different preset changes the selection', (
    tester,
  ) async {
    final repo = OnboardingRepository(storage: InMemorySecureStorageService());
    await tester.pumpWidget(_wrapped(repo));
    await repo.selectLanguage('am');

    await tester.tap(find.textContaining('Intense'));
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final pending = await repo.loadPendingSelection();
    expect(pending, isNotNull);
    expect(pending!.dailyGoalMinutes, 20);
  });

  testWidgets(
    'nothing is persisted after only the daily goal is chosen (language still unknown)',
    (tester) async {
      final storage = InMemorySecureStorageService();
      final repo = OnboardingRepository(storage: storage);
      await tester.pumpWidget(_wrapped(repo));

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Only the daily goal is known at this point — the language never
      // was, in this test — so no partial/corrupted state should exist in
      // storage yet.
      expect(storage.values[_pendingSelectionStorageKey], isNull);
    },
  );

  testWidgets(
    'both selections together get persisted once known, and not before',
    (tester) async {
      final storage = InMemorySecureStorageService();
      final repo = OnboardingRepository(storage: storage);

      // Drive the real language-selection screen first.
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AuthRoutes.languageSelection,
          routes: {
            AuthRoutes.languageSelection: (_) =>
                LanguageSelectionScreen(onboardingRepository: repo),
            AuthRoutes.dailyGoalSelection: (_) =>
                DailyGoalSelectionScreen(onboardingRepository: repo),
            AuthRoutes.signIn: (_) =>
                const Scaffold(body: Text('SIGN_IN_STUB')),
          },
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Language alone: nothing written yet.
      expect(storage.values[_pendingSelectionStorageKey], isNull);

      // Now on the daily-goal screen (Regular is pre-selected).
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Both known: the pending selection is now persisted.
      final pending = await repo.loadPendingSelection();
      expect(pending, isNotNull);
      expect(pending!.languageCode, 'am');
      expect(pending.dailyGoalMinutes, 10);
      expect(storage.values[_pendingSelectionStorageKey], isNotNull);
    },
  );
}
