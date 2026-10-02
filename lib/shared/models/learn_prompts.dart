import 'language_names.dart';

/// The language-selection screen's words, in the language the learner
/// speaks: an Amharic speaker is asked in Amharic what they want to learn,
/// and finds their courses under "ለአማርኛ ተናጋሪዎች".
///
/// A language with no entry here gets the English words, with its name
/// filled in ("For Somali speakers"), so a language the admin site adds
/// still works before anyone translates these.
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
  static LearnPrompts of(String code) =>
      _translated[code] ??
      LearnPrompts(
        question: _english.question,
        subtitle: _english.subtitle,
        forSpeakers: 'For ${languageName(code)} speakers',
      );

  static const _english = LearnPrompts(
    question: 'What do you want to learn?',
    subtitle: 'Choose your journey to connect with heritage & family.',
    forSpeakers: 'For English speakers',
  );

  static const Map<String, LearnPrompts> _translated = {
    'en': _english,
    'am': LearnPrompts(
      question: 'ምን መማር ይፈልጋሉ?',
      subtitle: 'ከቅርስዎ እና ከቤተሰብዎ ጋር ለመገናኘት ጉዞዎን ይምረጡ።',
      forSpeakers: 'ለአማርኛ ተናጋሪዎች',
    ),
    'om': LearnPrompts(
      question: 'Maal barachuu barbaadda?',
      subtitle:
          'Aadaa fi maatii kee waliin walitti hidhamuuf imala kee filadhu.',
      forSpeakers: 'Afaan Oromoo dubbattootaaf',
    ),
  };
}
