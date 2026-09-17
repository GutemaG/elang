---
stage: implement
bolt: 014-profile-and-settings-ui
created: '2026-09-17T13:00:00Z'
---

## Implementation Walkthrough: profile-and-settings-ui

### Summary

Built the first Settings screen in this app: view/edit language, daily goal, and notification preference against the real `013-user-preferences-service` backend; a fully-functional local sound toggle; and logout. Reused every existing pattern the plan identified (`HttpLessonApi`'s authenticated-call shape, `LessonController`'s `ChangeNotifier` pattern, `SecureStorageService` for local prefs) rather than introducing anything new to the architecture.

### Structure Overview

New `lib/features/settings/` feature folder (state/screens split, mirroring `lesson`/`auth`) plus 4 new shared services (`UserPreferencesApi`/`HttpUserPreferencesApi`, its exception type, `SoundPreferenceRepository`) and a new `AnswerFeedbackPlayer` decorator. Everything else is a small, additive extension of existing files to thread the new pieces through (`SessionState`, `session_api.dart`, `LessonDependencies`, `SkillTreeDashboardScreen`, `main.dart`).

### Completed Work

- [x] `lib/shared/models/session_state.dart` - gains `authProvider: String?`, persisted purely client-side (backend never carries this)
- [x] `lib/features/auth/state/sign_in_controller.dart` - passes the already-known `provider` into `SessionState` at save time
- [x] `lib/shared/services/session_api.dart` - `SessionUser` gains `notificationEnabled`, parsed from the now-extended backend response
- [x] `lib/shared/services/user_preferences_api.dart` - new `UserPreferencesApi` interface + `UpdatedPreferences` result type
- [x] `lib/shared/services/http_user_preferences_api.dart` - real implementation, mirrors `HttpLessonApi`'s auth/error-mapping structure
- [x] `lib/shared/services/user_preferences_api_exception.dart` - new exception type, mirrors `LessonApiException`'s shape
- [x] `lib/shared/services/sound_preference_repository.dart` - new local repository, backed by the existing `SecureStorageService`
- [x] `lib/shared/services/answer_feedback_player.dart` - new `SoundGatedAnswerFeedbackPlayer` decorator, checks the preference fresh on every call
- [x] `lib/features/lesson/lesson_dependencies.dart` - wraps the real feedback player in the sound gate by default
- [x] `lib/features/settings/settings_dependencies.dart` - new DI bag, mirrors `AuthDependencies`/`LessonDependencies`
- [x] `lib/features/settings/state/settings_controller.dart` - new `ChangeNotifier`: loads current settings via `SessionApi` (no dedicated GET endpoint exists), applies edits with optimistic-update/revert-on-failure, reverse-maps `dailyXpTarget` back to a minutes preset using the real backend table (not the onboarding screen's cosmetic `xpPerDay`)
- [x] `lib/features/settings/screens/settings_screen.dart` - the screen: provider label, daily-goal/language pickers (bottom sheets reusing `SelectableOptionCard`), notification/sound switches, logout with confirmation
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - new Settings entry point (icon button next to "Manage Downloads"), same `Navigator.push` idiom as the existing download-management button
- [x] `lib/main.dart` - constructs one shared `SoundPreferenceRepository` and a new `SettingsDependencies`, threads both through

### Key Decisions

- **Provider stored client-side, not added to the backend**: honors requirements' "not a new [backend] field" note. Accepted, documented limitation: a session saved before this bolt shows a generic "Signed in" until the next sign-in.
- **`SettingsController` as a `ChangeNotifier`**, not a plain `StatefulWidget`: this screen has several independent async mutations with optimistic-update/revert-on-failure, closer in shape to `LessonController` than to the onboarding flow's simple linear screens.
- **Single `PATCH` endpoint, all fields optional**: the controller's `updateLanguage`/`updateDailyGoalMinutes`/`updateNotificationEnabled` each call the same `UserPreferencesApi.updatePreferences`, matching the real backend contract exactly.
- **Reverse-mapping via the real backend table** (`{5:20, 10:40, 15:60, 20:80}`), explicitly not the onboarding screen's cosmetic `GoalOption.xpPerDay` (`10/20/30/50`) — those are decoupled, marketing-copy numbers that would show the wrong current preset if matched against.
- **No new GET endpoint** for reading current settings: reuses `SessionApi.checkSession`, exactly as `013-user-preferences-service` anticipated in its own Stage-4 correction.
- **Sound preference reuses `SecureStorageService`**, not a new `shared_preferences` dependency — this project's one local key-value store already holds a non-secret value (onboarding's pending selection).

### Deviations from Plan

None — the plan's flagged gap (provider display) was resolved exactly as recommended, and every other piece matched the plan as written.

### Dependencies Added

None — no new packages.

### Developer Notes

- `SkillTreeDashboardScreen` now threads 3 extra constructor params (`sessionRepository`, `userPreferencesApi`, `soundPreferenceRepository`) purely to build `SettingsScreen` on tap — it has no other use for them.
- Logout uses `pushNamedAndRemoveUntil`, a new-to-this-codebase navigation idiom (every existing screen only ever needed `pushReplacementNamed`, since Settings is the first screen reached via `push` on top of `home` rather than a linear replace chain).
- 3 pre-existing test files needed constructor-argument fixes for the new required parameters (`splash_screen_test.dart`, `skill_tree_dashboard_screen_test.dart`, `widget_test.dart`) — no behavior changes, just keeping them compiling against the wider constructors.
- `flutter analyze`: 0 errors/warnings; only pre-existing-style info-level `prefer_initializing_formals`/`use_null_aware_elements` suggestions, consistent with the exact same suggestions already present on the files this code mirrors (`HttpLessonApi`, `sync_engine.dart`).
- `flutter test`: 121 passing, 7 failing — all 7 failures are in `http_auth_api_e2e_test.dart` (requires a live backend on `localhost:8000`), a pre-existing, documented gap untouched by this bolt. No new tests written yet for the Settings feature itself — that's Stage 3.
