/// A user's pre-auth onboarding choices (the language they speak, the
/// language they want to learn, and the daily study goal), held locally until
/// sign-in attaches them to the first auth request. Only ever constructed once
/// *all* choices are known — see `OnboardingRepository`, which is the sole
/// place this is written to storage.
class PendingOnboardingSelection {
  const PendingOnboardingSelection({
    required this.languageCode,
    required this.dailyGoalMinutes,
    this.fromLanguageCode = defaultFromLanguageCode,
  });

  /// The from-language assumed when none was chosen, and for a selection
  /// stored before `010-multi-language-courses`.
  static const String defaultFromLanguageCode = 'en';

  /// ISO-ish code of the language to learn, e.g. `"am"` for Amharic.
  final String languageCode;

  /// ISO-ish code of the language the learner speaks, e.g. `"en"`.
  final String fromLanguageCode;

  /// One of the four daily-goal presets: 5, 10, 15, or 20.
  final int dailyGoalMinutes;

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'fromLanguageCode': fromLanguageCode,
    'dailyGoalMinutes': dailyGoalMinutes,
  };

  static PendingOnboardingSelection? fromJson(Map<String, dynamic> json) {
    final languageCode = json['languageCode'];
    final dailyGoalMinutes = json['dailyGoalMinutes'];
    if (languageCode is! String || dailyGoalMinutes is! int) return null;
    final fromLanguageCode = json['fromLanguageCode'];
    return PendingOnboardingSelection(
      languageCode: languageCode,
      dailyGoalMinutes: dailyGoalMinutes,
      fromLanguageCode: fromLanguageCode is String
          ? fromLanguageCode
          : defaultFromLanguageCode,
    );
  }

  @override
  String toString() =>
      'PendingOnboardingSelection(languageCode: $languageCode, '
      'fromLanguageCode: $fromLanguageCode, '
      'dailyGoalMinutes: $dailyGoalMinutes)';
}
