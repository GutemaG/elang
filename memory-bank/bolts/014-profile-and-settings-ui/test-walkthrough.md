---
stage: test
bolt: 014-profile-and-settings-ui
created: '2026-09-17T14:00:00Z'
---

## Test Report: profile-and-settings-ui

### Summary

- **Tests**: 155 passing / 162 total (up from 121/128 pre-bolt) — 34 new tests added by this bolt.
- **The 7 failures** are all pre-existing, all in `http_auth_api_e2e_test.dart` (requires a live backend on `localhost:8000`), untouched by this bolt.
- `flutter analyze`: 0 errors/warnings, only pre-existing-style info-level suggestions.

### Test Files

- [x] `test/shared/services/http_user_preferences_api_test.dart` (new) - request shape sent to `PATCH /api/v1/users/me`, response parsing, 422/network/missing-token error mapping
- [x] `test/shared/services/session_api_test.dart` (new) - first real coverage of `SessionApi.checkSession`, including the new `notification_enabled` field and its "missing field -> error" guard
- [x] `test/shared/services/sound_preference_repository_test.dart` (new) - default-true, persistence, cross-instance read-back
- [x] `test/shared/services/sound_gated_answer_feedback_player_test.dart` (new) - delegates when enabled, suppresses when disabled, re-checks fresh on every call (not cached at construction), `dispose()` always delegates
- [x] `test/features/settings/state/settings_controller_test.dart` (new) - `load()` success/invalid-session/no-token; each of the 3 server-backed update methods' success (adopts backend-authoritative values) and failure (reverts to the prior value, sets an error message) paths; the minutes<->xp reverse-mapping; local sound persistence; logout clears the session
- [x] `test/features/settings/screens/settings_screen_test.dart` (new) - renders current settings correctly (including the reverse-mapped goal label); notification toggle round-trips through the fake API; sound toggle never touches the preferences API; logout confirm/cancel; error state + working retry
- [x] `test/features/auth/state/sign_in_controller_native_test.dart` (extended) - asserts the saved session now records `authProvider`
- [x] `test/features/auth/splash_screen_test.dart`, `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart`, `test/widget_test.dart` (fixed only, from Stage 2) - no new assertions, just compiling against the wider constructors

### Acceptance Criteria Validation

**Story 001-settings-screen**
- ✅ **View all 4 settings on load**: `settings_screen_test.dart`'s first test asserts provider label, reverse-mapped goal label, language, and both switch values simultaneously.
- ✅ **Edit each setting**: notification toggle covered end-to-end (widget → controller → fake API); sound toggle covered end-to-end (widget → controller → real local repository read-back); language/daily-goal edit paths covered at the controller level (`updateLanguage`/`updateDailyGoalMinutes`), with the bottom-sheet picker UI itself exercised implicitly by `SelectableOptionCard`'s own existing test coverage from `001-auth-onboarding` (not re-tested here to avoid duplicating that widget's own suite).
- ✅ **Failed edit reverts to last known-good value**: `settings_controller_test.dart`'s three failure-path tests each assert the value returns to what it was before the optimistic update, not the failed attempt.

**Story 002-logout**
- ✅ **Logout clears the session**: asserted directly against a real `SessionRepository` (not a fake) in both the controller and screen tests.
- ✅ **Lands on sign-in, stack unwound**: `settings_screen_test.dart`'s logout test navigates through a real `MaterialApp` route table and confirms the sign-in placeholder is reached.
- ✅ **Confirmation before clearing**: a dedicated test confirms *cancelling* the dialog leaves the session untouched.

**Cross-cutting**
- ✅ **Sound toggle is immediately live, no restart**: `sound_gated_answer_feedback_player_test.dart`'s "checks fresh on every call" test proves this directly at the unit level (flips the preference between two calls on the *same* long-lived player instance, matching how `LessonDependencies` actually constructs it once at app start).
- ✅ **"Signed in with provider" gap resolved and doesn't regress sign-in**: `sign_in_controller_native_test.dart`'s extended assertion.

### Issues Found

None during Test stage. All issues surfaced during Plan/Implement were already resolved and documented in those stages' artifacts.

### Notes

- Deliberately did not write a dedicated widget test for the language/daily-goal bottom-sheet picker's own rendering (which `SelectableOptionCard` already owns and tests), to avoid duplicating coverage of a shared, already-tested widget — consistent with this project's stated testing philosophy of not over-testing framework/shared-widget behavior.
- `SessionApi` (idle since `001-auth-onboarding`, by design) has its first real test coverage as of this bolt — its own docstring already anticipated this.
