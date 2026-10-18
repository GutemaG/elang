// A deterministic [UserPreferencesApi] test double for `SettingsController`
// tests: configure [nextResult] for a success, or [nextException] to
// simulate a failure -- no real network mocking needed since the interface
// is already at the right abstraction boundary.

import 'package:elang/shared/services/user_preferences_api.dart';
import 'package:elang/shared/services/user_preferences_api_exception.dart';

class UpdateCall {
  const UpdateCall({this.language, this.dailyGoalMinutes, this.notificationEnabled});

  final String? language;
  final int? dailyGoalMinutes;
  final bool? notificationEnabled;
}

class FakeUserPreferencesApi implements UserPreferencesApi {
  final List<UpdateCall> calls = [];
  UpdatedPreferences? nextResult;
  UserPreferencesApiException? nextException;

  @override
  Future<UpdatedPreferences> updatePreferences({
    String? language,
    int? dailyGoalMinutes,
    bool? notificationEnabled,
  }) async {
    calls.add(
      UpdateCall(
        language: language,
        dailyGoalMinutes: dailyGoalMinutes,
        notificationEnabled: notificationEnabled,
      ),
    );
    final exception = nextException;
    if (exception != null) throw exception;
    final result = nextResult;
    if (result == null) {
      throw StateError('FakeUserPreferencesApi: no nextResult/nextException configured');
    }
    return result;
  }
}
