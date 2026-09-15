/// A user's pre-auth onboarding choices (target language + daily study
/// goal), held locally until sign-in attaches them to the first auth
/// request. Only ever constructed once *both* choices are known — see
/// `OnboardingRepository`, which is the sole place this is written to
/// storage.
class PendingOnboardingSelection {
  const PendingOnboardingSelection({
    required this.languageCode,
    required this.dailyGoalMinutes,
  });

  /// ISO-ish course code, e.g. `"am"` for Amharic.
  final String languageCode;

  /// One of the four daily-goal presets: 5, 10, 15, or 20.
  final int dailyGoalMinutes;

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'dailyGoalMinutes': dailyGoalMinutes,
  };

  static PendingOnboardingSelection? fromJson(Map<String, dynamic> json) {
    final languageCode = json['languageCode'];
    final dailyGoalMinutes = json['dailyGoalMinutes'];
    if (languageCode is! String || dailyGoalMinutes is! int) return null;
    return PendingOnboardingSelection(
      languageCode: languageCode,
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  @override
  String toString() =>
      'PendingOnboardingSelection(languageCode: $languageCode, '
      'dailyGoalMinutes: $dailyGoalMinutes)';
}
