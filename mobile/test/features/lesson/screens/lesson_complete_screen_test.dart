// Lesson-complete summary + streak/level-up modal tests (story 004), plus
// (010-offline-caching-and-sync-ui, story 003) the pending-sync variant
// shown after an offline completion.
//
// Covers: the base summary (XP, streak, accuracy, daily-goal progress)
// always renders; a crown-level-up/streak-freeze unlock shows the
// level-up modal with no empty/broken section when absent; dismissing
// returns to the caller (the dashboard, in the real flow); a pending-sync
// result shows exact XP/accuracy but "syncs when back online" instead of a
// guessed streak/daily-goal number, and never shows a level-up modal even
// if the (otherwise-unreachable) crown fields were somehow set.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_complete_screen.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';

void main() {
  testWidgets(
    'shows XP earned, streak, accuracy, and daily-goal progress',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonCompleteScreen(
            result: LessonCompletionResult(
              xpEarned: 25,
              dailyXpTotal: 25,
              dailyXpTarget: 30,
              streakCount: 6,
              streakIncreasedToday: true,
              accuracyPercent: 94,
              correctCount: 16,
              totalCount: 17,
              timeSpent: Duration(minutes: 2, seconds: 14),
            ),
          ),
        ),
      );

      expect(find.text('Lesson Complete!'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
      expect(find.text('6 Days'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.text('25 / 30 XP today'), findsOneWidget);
      expect(find.text('+1 Today'), findsOneWidget);
    },
  );

  testWidgets(
    'no level-up/crown change renders no empty or broken level-up section',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonCompleteScreen(
            result: LessonCompletionResult(
              xpEarned: 10,
              dailyXpTotal: 10,
              dailyXpTarget: 30,
              streakCount: 1,
              streakIncreasedToday: false,
              accuracyPercent: 80,
              correctCount: 4,
              totalCount: 5,
              timeSpent: Duration(seconds: 30),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // No level-up modal content ever appeared.
      expect(find.text('Crown Level Up!'), findsNothing);
      expect(find.text('Streak Freeze Unlocked!'), findsNothing);
    },
  );

  testWidgets(
    'a crown level-up is shown via the level-up modal before returning',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LessonCompleteScreen(
                        result: LessonCompletionResult(
                          xpEarned: 25,
                          dailyXpTotal: 25,
                          dailyXpTarget: 30,
                          streakCount: 6,
                          streakIncreasedToday: true,
                          accuracyPercent: 100,
                          correctCount: 5,
                          totalCount: 5,
                          timeSpent: Duration(seconds: 40),
                          skillUnlockedTitle: 'Family & Introductions',
                          crownLevel: 3,
                          crownLeveledUp: true,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open summary'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open summary'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Crown Level Up!'), findsOneWidget);
      expect(find.textContaining('crown level 3'), findsOneWidget);

      // Two "Continue" buttons now coexist (the summary screen's own,
      // still underneath, plus the level-up modal's) — target the modal's.
      await tester.tap(find.text('Continue').last);
      await tester.pumpAndSettle();

      // Level-up modal dismissed, then the summary itself popped back to
      // the caller.
      expect(find.text('open summary'), findsOneWidget);
    },
  );

  testWidgets(
    'a streak-freeze unlock uses the streak-freeze copy, not the generic crown-level copy',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonCompleteScreen(
            result: LessonCompletionResult(
              xpEarned: 25,
              dailyXpTotal: 25,
              dailyXpTarget: 30,
              streakCount: 6,
              streakIncreasedToday: true,
              accuracyPercent: 100,
              correctCount: 5,
              totalCount: 5,
              timeSpent: Duration(seconds: 40),
              crownLevel: 5,
              crownLeveledUp: true,
              streakFreezeUnlocked: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Streak Freeze Unlocked!'), findsOneWidget);
      expect(find.text('Crown Level Up!'), findsNothing);
    },
  );

  testWidgets(
    'a pending-sync result shows exact XP/accuracy but "syncs when back online" for streak/daily-goal',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonCompleteScreen(
            result: LessonCompletionResult(
              xpEarned: 10,
              dailyXpTotal: 0,
              dailyXpTarget: 0,
              streakCount: 0,
              streakIncreasedToday: false,
              accuracyPercent: 100,
              correctCount: 2,
              totalCount: 2,
              timeSpent: Duration(seconds: 20),
              pendingSync: true,
            ),
          ),
        ),
      );

      // XP and accuracy are exact (client-known) even offline.
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Streak/daily-goal are not guessed at.
      expect(find.text('SYNCS WHEN ONLINE'), findsOneWidget);
      expect(find.text('0 Days'), findsNothing);
      expect(find.text('+1 Today'), findsNothing);
      expect(find.textContaining('XP today'), findsNothing);
      expect(find.textContaining("You're offline"), findsOneWidget);
    },
  );

  testWidgets(
    'a pending-sync result never shows a level-up modal, even if crown fields were somehow set',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonCompleteScreen(
            result: LessonCompletionResult(
              xpEarned: 10,
              dailyXpTotal: 0,
              dailyXpTarget: 0,
              streakCount: 0,
              streakIncreasedToday: false,
              accuracyPercent: 100,
              correctCount: 2,
              totalCount: 2,
              timeSpent: Duration(seconds: 20),
              crownLevel: 3,
              crownLeveledUp: true,
              pendingSync: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Crown Level Up!'), findsNothing);
    },
  );
}
