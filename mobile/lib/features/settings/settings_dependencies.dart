import '../../shared/services/http_user_preferences_api.dart';
import '../../shared/services/session_api.dart';
import '../../shared/services/session_repository.dart';
import '../../shared/services/sound_preference_repository.dart';
import '../../shared/services/user_preferences_api.dart';

/// Bag of shared services the Settings feature depends on, constructed
/// once at app start-up -- same "no DI framework, plain constructor-
/// injected bundle" pattern as [AuthDependencies]/[LessonDependencies].
///
/// [sessionRepository] and [soundPreferenceRepository] are the *same*
/// instances `main.dart` also hands to [LessonDependencies], so a sound
/// toggle flipped here is visible on the very next graded answer.
class SettingsDependencies {
  SettingsDependencies({
    required this.sessionRepository,
    required this.soundPreferenceRepository,
    UserPreferencesApi? userPreferencesApi,
    SessionApi? sessionApi,
  }) : userPreferencesApi =
           userPreferencesApi ??
           HttpUserPreferencesApi(sessionRepository: sessionRepository),
       sessionApi = sessionApi ?? SessionApi();

  final SessionRepository sessionRepository;
  final SoundPreferenceRepository soundPreferenceRepository;
  final UserPreferencesApi userPreferencesApi;
  final SessionApi sessionApi;
}
