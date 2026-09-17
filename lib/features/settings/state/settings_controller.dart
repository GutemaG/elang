import 'package:flutter/foundation.dart';

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
    required this._userPreferencesApi,
    required this._soundPreferenceRepository,
    required this._sessionRepository,
  });

  final SessionApi _sessionApi;
  final UserPreferencesApi _userPreferencesApi;
  final SoundPreferenceRepository _soundPreferenceRepository;
  final SessionRepository _sessionRepository;

  SettingsLoadStatus _loadStatus = SettingsLoadStatus.loading;
  String? _errorMessage;

  String? _selectedLanguage;
  int? _dailyXpTarget;
  bool _notificationEnabled = true;
  bool _soundEnabled = true;

  /// `null` for a session saved before `014-profile-and-settings-ui` (a
  /// one-time, self-healing gap -- see the implementation plan). The
  /// screen shows a generic fallback in that case, not an error.
  String? _authProvider;

  SettingsLoadStatus get loadStatus => _loadStatus;
  String? get errorMessage => _errorMessage;
  String? get selectedLanguage => _selectedLanguage;
  bool get notificationEnabled => _notificationEnabled;
  bool get soundEnabled => _soundEnabled;
  String? get authProvider => _authProvider;

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
    _dailyXpTarget = user.dailyXpTarget;
    _notificationEnabled = user.notificationEnabled;
    _soundEnabled = await _soundPreferenceRepository.getSoundEnabled();
    _loadStatus = SettingsLoadStatus.loaded;
    notifyListeners();
  }

  Future<void> updateLanguage(String language) async {
    final previous = _selectedLanguage;
    _selectedLanguage = language;
    _errorMessage = null;
    notifyListeners();
    await _applyUpdate(
      call: () => _userPreferencesApi.updatePreferences(language: language),
      onRevert: () => _selectedLanguage = previous,
    );
  }

  Future<void> updateDailyGoalMinutes(int minutes) async {
    final previous = _dailyXpTarget;
    _dailyXpTarget = _minutesToXpTarget[minutes];
    _errorMessage = null;
    notifyListeners();
    await _applyUpdate(
      call: () => _userPreferencesApi.updatePreferences(dailyGoalMinutes: minutes),
      onRevert: () => _dailyXpTarget = previous,
    );
  }

  Future<void> updateNotificationEnabled(bool enabled) async {
    final previous = _notificationEnabled;
    _notificationEnabled = enabled;
    _errorMessage = null;
    notifyListeners();
    await _applyUpdate(
      call: () => _userPreferencesApi.updatePreferences(notificationEnabled: enabled),
      onRevert: () => _notificationEnabled = previous,
    );
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

  Future<void> logout() => _sessionRepository.clearSession();
}
