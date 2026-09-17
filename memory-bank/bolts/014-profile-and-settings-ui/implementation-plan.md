---
stage: plan
bolt: 014-profile-and-settings-ui
created: '2026-09-17T11:30:00Z'
---

## Implementation Plan: profile-and-settings-ui

### Objective

Deliver the first Settings screen in this app: view/edit language, daily goal, and notification toggle (via `013-user-preferences-service`'s real `PATCH /api/v1/users/me` and its extended `AuthUserResponse`/`SessionUserResponse`), a fully-functional local sound toggle gating the existing `AnswerFeedbackPlayer`, and logout (reusing `SessionRepository.clearSession()`).

### Prior Decision Lookup

Scanned `memory-bank/standards/decision-index.md` — no ADR constrains a Flutter settings screen specifically. ADR-7 (write-once-then-sanctioned-update) is already fully absorbed server-side by bolt 013; this bolt only needs to call the resulting endpoint, not re-litigate the invariant.

### Deliverables

**New feature folder** `lib/features/settings/` (first new top-level feature folder since `auth`/`lesson`, per the unit brief):
- `state/settings_controller.dart` — `SettingsController extends ChangeNotifier`, mirroring `LessonController`/`SignInController`'s pattern (chosen over a plain `StatefulWidget`, like the onboarding screens use, because this screen has multiple independent async mutations with optimistic-update/revert-on-failure semantics — closer in shape to `LessonController` than to the linear onboarding flow).
- `screens/settings_screen.dart` — the screen itself.
- `settings_dependencies.dart` — DI bag (mirrors `AuthDependencies`/`LessonDependencies`): `sessionRepository`, `userPreferencesApi`, `soundPreferenceRepository`.

**New shared services** (`lib/shared/services/`):
- `user_preferences_api.dart` — `UserPreferencesApi` interface: `Future<UpdatedPreferences> updatePreferences({String? language, int? dailyGoalMinutes, bool? notificationEnabled})`. Modeled on `LessonApi`'s shape (authenticated, throws on failure) rather than `AuthApi`'s sealed-result shape, since it needs `SessionRepository` for a fresh-token-per-request exactly like `HttpLessonApi`.
- `http_user_preferences_api.dart` — `HttpUserPreferencesApi`, mirrors `HttpLessonApi`'s `_authHeaders`/error-mapping structure exactly (401 → rethrow as a credentials failure; 422 `invalid_preference_value` → surfaced with that error code so the UI can show a specific message; network failure → generic).
- `user_preferences_api_exception.dart` — `UserPreferencesApiException(message, {errorCode})`, mirrors `LessonApiException`'s shape under its own honest name (not reused directly — that class's docstring specifically scopes it to `LessonApi`).
- `sound_preference_repository.dart` — `SoundPreferenceRepository`, backed by the existing `SecureStorageService` (no new package/dependency added — `shared_preferences` isn't in `pubspec.yaml` and doesn't need to be, since `SecureStorageService` is already this project's one local key-value abstraction and is already used for a non-secret value, the onboarding pending selection). `getSoundEnabled()` defaults to `true` when unset.

**Gating `AnswerFeedbackPlayer`**:
- New `SoundGatedAnswerFeedbackPlayer implements AnswerFeedbackPlayer` decorator (`lib/shared/services/answer_feedback_player.dart`) wrapping the real player + `SoundPreferenceRepository`; checks the current preference before delegating `playCorrect`/`playIncorrect`. `dispose()` delegates through unconditionally.
- `LessonDependencies` wraps `SystemAnswerFeedbackPlayer()` in this decorator instead of using it directly; takes a new `SoundPreferenceRepository` constructor parameter.
- `main.dart` constructs one `SoundPreferenceRepository` (from `authDependencies.storage`, already public) and passes it to both `LessonDependencies` and `SettingsDependencies` — the same instance, so a toggle flip is visible on the very next graded answer without needing a restart.

**Reading current settings (FR-1)** — no new GET endpoint (per bolt 013's own Stage-4 correction): extend `session_api.dart`'s `SessionUser`/`SessionCheckResult` parsing with `notificationEnabled: bool` (from the now-extended `SessionUserResponse`). `SettingsScreen` calls `SessionApi.checkSession(token)` on load, exactly like the dashboard's `FutureBuilder` pattern.

**Reverse-mapping `daily_xp_target` back to a goal preset**: the onboarding screen's `_goalOptions.xpPerDay` (10/20/30/50) is cosmetic marketing copy, decoupled from the backend's real `daily_xp_target` (20/40/60/80, per `MINUTES_TO_XP_TARGET` in `value_objects.py`). Settings must map the session's real `dailyXpTarget` back to a minutes preset using the *real* backend table (`{20: 5, 40: 10, 60: 15, 80: 20}`), not the onboarding screen's cosmetic field — flagging this explicitly since it would be an easy, silent bug to match on the wrong field.

**Navigation**:
- Entry point: a second `IconButton` (Settings icon) next to the existing "Manage Downloads" button in `SkillTreeDashboardScreen`'s top row, pushed via `Navigator.push(MaterialPageRoute(...))` — exact same idiom as `_openDownloadManagement()`. No change to the named-route table.
- Logout: `Navigator.of(context).pushNamedAndRemoveUntil(AuthRoutes.signIn, (route) => false)` after `sessionRepository.clearSession()` — clears the *entire* stack (dashboard + settings + anything else), not just a replace, since Settings is reached via `push` on top of the `home` route rather than via `pushReplacementNamed` like every onboarding screen. This is the one new navigation idiom in this codebase; every existing screen only ever needed `pushReplacementNamed` because the onboarding flow never has more than one screen deep to unwind.

### Flagged Gap: FR-1's "Signed in with {Google|Apple}"

Requirements assumed this needs "not a new field" — checked, and neither is true today: `SessionUserResponse`/`AuthUserResponse` never carried `auth_provider`, and the client's `SessionState` only stores `token`/`expiresAt`, nothing about which provider was used. **Recommended fix** (honors "not a new [backend] field" — the backend already knows this, it just doesn't need to start serializing it): extend `SessionState` with an optional `authProvider: String?`, populated purely client-side at the moment `SignInController` calls `sessionRepository.saveSession(...)` (it already knows literally which provider — `google` or `apple` — it just called, from the `AuthProvider provider` parameter already passed into `signIn()`). No change to `AuthApi`/`AuthResult`/the backend at all.

**Accepted limitation**: a session created *before* this bolt ships (i.e., anyone already signed in when this update lands) has no stored provider and will show a generic "Signed in" (no provider name) until their next sign-in. This is a one-time, self-healing gap, not a permanent one — flagging it rather than silently shipping a crash/placeholder.

### Dependencies

- `013-user-preferences-service` (complete): real `PATCH /api/v1/users/me` contract + extended `AuthUserResponse`/`SessionUserResponse`.
- No new third-party packages.

### Acceptance Criteria

- [ ] Settings screen shows current language, daily goal (as a preset label, correctly reverse-mapped), notification toggle, sound toggle, and "Signed in with {provider}" (or a graceful generic fallback for pre-existing sessions)
- [ ] Editing language/daily-goal/notification calls the real `PATCH /api/v1/users/me`; a failed call reverts the displayed value to the last known-good one (not the failed attempt) and shows an error
- [ ] Toggling sound persists locally and immediately gates `AnswerFeedbackPlayer` on the very next graded answer, with no app restart needed
- [ ] Logout clears the session and lands on sign-in with the entire authenticated stack unwound — no back-navigation into any authenticated screen
- [ ] Zero regression to `SkillTreeDashboardScreen`/`LessonScreen`/existing tests
