// The app's words in Amharic and Afaan Oromo (024-app-localization): a
// screen drawn in each language, and the words built outside a screen
// (the reminder, league lines, places, the course-choice prompts).

import 'package:elang/features/auth/screens/daily_goal_selection_screen.dart';
import 'package:elang/features/league/widgets/league_result_sheet.dart';
import 'package:elang/features/league/widgets/league_widgets.dart';
import 'package:elang/l10n/app_localizations.dart';
import 'package:elang/shared/l10n/app_language.dart';
import 'package:elang/shared/models/learn_prompts.dart';
import 'package:elang/shared/services/onboarding_repository.dart';
import 'package:elang/shared/services/reminders/reminder_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/in_memory_secure_storage_service.dart';

AppLocalizations _in(String code) => lookupAppLocalizations(Locale(code));

void main() {
  for (final (code, heading, continueLabel) in [
    ('en', 'Choose your daily goal', 'Continue'),
    ('am', 'ዕለታዊ ግብዎን ይምረጡ', 'ቀጥል'),
    ('om', 'Galma guyyaa kee filadhu', 'Itti fufi'),
  ]) {
    testWidgets('the daily goal screen is drawn in $code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLanguage.delegates,
          supportedLocales: AppLanguage.locales,
          home: DailyGoalSelectionScreen(
            onboardingRepository: OnboardingRepository(
              storage: InMemorySecureStorageService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(heading), findsOneWidget);
      expect(find.text(continueLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('the daily reminder speaks the app language', () {
    expect(reminderMessage(3, _in('am')).$1, 'የ3 ቀን ተከታታይነትዎን ያስቀጥሉ');
    expect(reminderMessage(0, _in('om')).$1, "Yeroon barnoota har'aa gaheera");
    // English by default, as before.
    expect(reminderMessage(1).$1, 'Keep your 1-day streak going');
  });

  test('places are written the way each language writes them', () {
    expect(ordinal(2), '2nd');
    expect(ordinal(2, _in('en')), '2nd');
    expect(ordinal(2, _in('am')), '2ኛ');
    expect(ordinal(2, _in('om')), '2ffaa');
  });

  test('league lines follow the app language, with plurals', () {
    final now = DateTime.utc(2026, 10, 2, 12);
    expect(
      leagueTimeLeft(
        now.add(const Duration(days: 3, hours: 1)),
        now,
        _in('am'),
      ),
      '3 ቀናት ቀርተዋል',
    );
    expect(
      leagueTimeLeft(
        now.add(const Duration(hours: 1, minutes: 5)),
        now,
        _in('om'),
      ),
      "Sa'aatii 1 hafe",
    );
    expect(
      leagueZoneSummary(1, 2, _in('om')),
      "Gubbaa 1 ol guddata · jalaa 2 gadi bu'u",
    );
  });

  test('the course choice asks in the language spoken, whatever the app '
      'language', () {
    expect(LearnPrompts.of('am').question, 'ምን መማር ይፈልጋሉ?');
    expect(LearnPrompts.of('am').forSpeakers, 'ለአማርኛ ተናጋሪዎች');
    expect(LearnPrompts.of('om').forSpeakers, 'Afaan Oromoo dubbattootaaf');
    expect(LearnPrompts.of('en').forSpeakers, 'For English speakers');
    // A language the app has no words for: English, with its name.
    expect(LearnPrompts.of('so').forSpeakers, 'For Somali speakers');
  });

  test('month and weekday names come from the app language', () {
    expect(_in('en').monthName(3), 'March');
    expect(_in('om').monthName(1), 'Amajjii');
    expect(_in('am').weekdayLetters, hasLength(7));
    expect(_in('om').weekdayLetters.first, 'W');
  });
}
