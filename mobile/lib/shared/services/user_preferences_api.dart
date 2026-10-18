/// The result of a successful preference update — the backend's
/// authoritative, post-update values (never the client's optimistic guess).
class UpdatedPreferences {
  const UpdatedPreferences({
    required this.selectedLanguage,
    required this.dailyXpTarget,
    required this.notificationEnabled,
  });

  final String selectedLanguage;
  final int dailyXpTarget;
  final bool notificationEnabled;
}

/// The `013-user-preferences-service` boundary this UI needs: one call,
/// `PATCH /api/v1/users/me`. Modeled on [LessonApi]'s shape (authenticated,
/// throws [UserPreferencesApiException] on failure) rather than [AuthApi]'s
/// sealed-result shape, since — like every `LessonApi` call — this needs a
/// session token attached fresh per request.
abstract class UserPreferencesApi {
  /// All three fields optional; omitted/`null` means "leave unchanged" —
  /// mirrors the backend's own `PATCH` semantics exactly. Throws
  /// [UserPreferencesApiException] on any failure (invalid value, expired
  /// session, network error).
  Future<UpdatedPreferences> updatePreferences({
    String? language,
    int? dailyGoalMinutes,
    bool? notificationEnabled,
  });
}
