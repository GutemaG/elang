import 'dart:ui';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../l10n/app_language.dart';
import 'language_names.dart';

/// The course choice's words in the language the learner speaks, whatever
/// the app language: an Amharic speaker is asked in Amharic what they want
/// to learn, and finds their courses under "ለአማርኛ ተናጋሪዎች".
///
/// The words come from that language's ARB file (024-app-localization). A
/// language the app has no file for gets the English words, with its name
/// filled in ("For Somali speakers"), so a language the admin site adds
/// still works before anyone translates the app into it.
class LearnPrompts {
  const LearnPrompts({
    required this.question,
    required this.subtitle,
    required this.forSpeakers,
  });

  /// The screen's heading: "What do you want to learn?".
  final String question;

  /// The line under the heading.
  final String subtitle;

  /// The heading over this language's courses: "For English speakers".
  final String forSpeakers;

  /// The words for speakers of [code].
  static LearnPrompts of(String code) {
    final AppLocalizations l = AppLanguage.has(code)
        ? lookupAppLocalizations(Locale(code))
        : AppLocalizationsEn();
    return LearnPrompts(
      question: l.learnQuestion,
      subtitle: l.learnSubtitle,
      forSpeakers: l.forSpeakers(
        AppLanguage.has(code) ? languageNativeName(code) : languageName(code),
      ),
    );
  }
}
