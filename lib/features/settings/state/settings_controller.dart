import 'package:flutter/foundation.dart';

import '../../../shared/models/course.dart';
import '../../../shared/services/course_api.dart';
import '../../../shared/services/reminders/reminder_service.dart';
import '../../../shared/services/session_api.dart';
import '../../../shared/services/session_repository.dart';
import '../../../shared/services/sound_preference_repository.dart';
import '../../../shared/services/user_preferences_api.dart';
import '../../../shared/services/user_preferences_api_exception.dart';

enum SettingsLoadStatus { loading, loaded, error }

/// The real backend mapping from a daily-goal preset's minutes to its XP
/// target (`MINUTES_TO_XP_TARGET` in `backend/app/domain/value_objects.py`).
/// Deliberately *not* the onboarding screen's `GoalOption.xpPerDay`
/// (10/20/30/50), which is cosmetic marketing copy decoupled from this real
/// value -- matching on that field would show the wrong current preset.
const Map<int, int> _minutesToXpTarget = {5: 20, 10: 40, 15: 60, 20: 80};

/// Drives the Settings screen: loads the account's current preferences
/// (language/daily-goal/notification, via [SessionApi] -- no dedicated GET
/// endpoint exists, per `013-user-preferences-service`'s own Stage-4
/// decision) plus the local sound preference, and applies edits with
/// optimistic-update/revert-on-failure semantics (mirrors `LessonController`'s
/// `ChangeNotifier` pattern, chosen over a plain `StatefulWidget` because of
/// these multiple independent async mutations).
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this._sessionApi,
    required this._courseApi,
    required this._userPreferencesApi,
    required this._soundPreferenceRepository,
    required this._sessionRepository,
    this._reminders,
  });

  final SessionApi _sessionApi;
  final CourseApi _courseApi;
  final UserPreferencesApi _userPreferencesApi;
  final SoundPreferenceRepository _soundPreferenceRepository;
  final SessionRepository _sessionRepository;

  /// The 8 pm reminder the Notifications switch controls
  /// (021-daily-reminder, bolt 064); `null` makes the switch only a saved
  /// preference, as before.
  final ReminderService? _reminders;

  SettingsLoadStatus _loadStatus = SettingsLoadStatus.loading;
  String? _errorMessage;

  String? _selectedLanguage;

  /// The learner's active course (010-multi-language-courses), `null` if the
  /// course list could not be loaded -- the screen then falls back to the
  /// language name.
  Course? _activeCourse;
  int? _dailyXpTarget;
  bool _notificationEnabled = true;

  /// Whether the phone allows notifications; `true` where reminders are
  /// not in play (no [_reminders], or the web).
  bool _notificationsPermitted = true;
  bool _soundEnabled = true;

  /// `null` for a session saved before `014-profile-and-settings-ui` (a
  /// one-time, self-healing gap -- see the implementation plan). The
  /// screen shows a generic fallback in that case, not an error.
  String? _authProvider;

  /// The signed-in person as their provider reported it (see
  /// `SessionState.displayName`); any of these may be `null`.
  String? _displayName;
  String? _email;
  String? _photoUrl;

  SettingsLoadStatus get loadStatus => _loadStatus;
  String? get errorMessage => _errorMessage;
  String? get selectedLanguage => _selectedLanguage;
  Course? get activeCourse => _activeCourse;

  /// What the switch shows: the saved value (bolt 065), on by default.
  bool get notificationEnabled => _notificationEnabled;

  /// The switch is saved on but the phone blocks notifications: Settings
  /// shows a line under it that opens the phone's settings.
  bool get notificationsBlocked =>
      _notificationEnabled && !_notificationsPermitted;
  bool get soundEnabled => _soundEnabled;
  String? get authProvider => _authProvider;
  String? get displayName => _displayName;
  String? get email => _email;
  String? get photoUrl => _photoUrl;

  /// The current daily-goal preset's minutes, reverse-mapped from
  /// [_dailyXpTarget]. `null` only if the stored value somehow doesn't
  /// match any known preset (shouldn't happen -- defensive, not a normal
  /// case).
  int? get dailyGoalMinutes {
    final target = _dailyXpTarget;
    if (target == null) return null;
    for (final entry in _minutesToXpTarget.entries) {
      if (entry.value == target) return entry.key;
    }
    return null;
  }

  Future<void> load() async {
    _loadStatus = SettingsLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final session = await _sessionRepository.getSessionState();
    _authProvider = session.authProvider;
    _displayName = session.displayName;
    _email = session.email;
    _photoUrl = session.photoUrl;
    final token = session.token;
    if (token == null || token.isEmpty) {
      _loadStatus = SettingsLoadStatus.error;
      notifyListeners();
      return;
    }

    final result = await _sessionApi.checkSession(token);
    final user = result.user;
    if (result.status != SessionCheckStatus.valid || user == null) {
      _loadStatus = SettingsLoadStatus.error;
      notifyListeners();
      return;
    }

    _selectedLanguage = user.selectedLanguage;
    try {
      _activeCourse = (await _courseApi.getCourses()).activeCourse;
    } on CourseApiException {
      _activeCourse = null;
    }
    _dailyXpTarget = user.dailyXpTarget;
    _notificationEnabled = user.notificationEnabled;
    await _reminders?.setEnabled(_notificationEnabled);
    _notificationsPermitted = await _checkPermitted();
    _soundEnabled = await _soundPreferenceRepository.getSoundEnabled();
    _loadStatus = SettingsLoadStatus.loaded;
    notifyListeners();
  }

  /// Adopts a course the learner just switched to (the switch itself is done
  /// by the shared course picker, which keeps the old course on failure).
  void applySwitchedCourse(Course course) {
    _activeCourse = course;
    _selectedLanguage = course.learningLanguage;
    notifyListeners();
  }

  Future<void> updateDailyGoalMinutes(int minutes) async {
    final previous = _dailyXpTarget;
    _dailyXpTarget = _minutesToXpTarget[minutes];
    _errorMessage = null;
    notifyListeners();
    await _applyUpdate(
      call: () =>
          _userPreferencesApi.updatePreferences(dailyGoalMinutes: minutes),
      onRevert: () => _dailyXpTarget = previous,
    );
  }

  Future<void> updateNotificationEnabled(bool enabled) async {
    final reminders = _reminders;
    if (enabled && reminders != null && reminders.supported) {
      // Asks again if the phone still blocks them. The learner's "on" is
      // saved either way; after a refusal the blocked line offers the
      // phone's settings (see [recheckNotificationPermission]).
      _notificationsPermitted = await reminders.requestPermission();
    }
    final previous = _notificationEnabled;
    _notificationEnabled = enabled;
    _errorMessage = null;
    notifyListeners();
    await _applyUpdate(
      call: () =>
          _userPreferencesApi.updatePreferences(notificationEnabled: enabled),
      onRevert: () => _notificationEnabled = previous,
    );
    await reminders?.setEnabled(_notificationEnabled);
  }

  /// Checks the phone's permission again, e.g. after the learner comes
  /// back from the phone's settings.
  Future<void> recheckNotificationPermission() async {
    final permitted = await _checkPermitted();
    if (permitted == _notificationsPermitted) return;
    _notificationsPermitted = permitted;
    notifyListeners();
    await _reminders?.reschedule();
  }

  /// Opens the phone's notification settings for the app.
  Future<void> openNotificationSettings() async {
    await _reminders?.openSettings();
  }

  Future<bool> _checkPermitted() async {
    final reminders = _reminders;
    if (reminders == null || !reminders.supported) return true;
    return reminders.isPermitted();
  }

  /// Applies [call], adopting the backend's authoritative returned values
  /// on success (never trusting the optimistic guess as final) or invoking
  /// [onRevert] and surfacing [errorMessage] on failure -- the "revert to
  /// last known-good value, not the failed attempt" acceptance criterion.
  Future<void> _applyUpdate({
    required Future<UpdatedPreferences> Function() call,
    required void Function() onRevert,
  }) async {
    try {
      final updated = await call();
      _selectedLanguage = updated.selectedLanguage;
      _dailyXpTarget = updated.dailyXpTarget;
      _notificationEnabled = updated.notificationEnabled;
      notifyListeners();
    } on UserPreferencesApiException {
      onRevert();
      _errorMessage = "Couldn't save your change. Please try again.";
      notifyListeners();
    }
  }

  Future<void> updateSoundEnabled(bool enabled) async {
    final previous = _soundEnabled;
    _soundEnabled = enabled;
    _errorMessage = null;
    notifyListeners();
    try {
      await _soundPreferenceRepository.setSoundEnabled(enabled);
    } catch (_) {
      _soundEnabled = previous;
      _errorMessage = "Couldn't save your change. Please try again.";
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _sessionRepository.clearSession();
    await _reminders?.signedOut();
  }
}
