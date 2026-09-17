---
id: 001-settings-screen
unit: 002-profile-and-settings-ui
intent: 005-profile-and-settings
status: complete
priority: must
created: '2026-09-17T07:55:00Z'
assigned_bolt: null
implemented: true
---

# Story: 001-settings-screen

## User Story

**As a** Buna learner
**I want** one screen where I can see and change my language, daily goal, notification preference, and sound preference
**So that** I'm not locked into whatever I picked during onboarding

## Acceptance Criteria

- [ ] **Given** the Settings screen loads, **When** rendered, **Then** it shows the current language, daily goal, notification-toggle state, sound-toggle state, and "Signed in with {Google|Apple}"
- [ ] **Given** the user changes language or daily goal, **When** they confirm, **Then** `001-user-preferences-service`'s endpoint is called and the screen reflects the new value on success (and shows an error, not a silent failure, if the call fails)
- [ ] **Given** the user toggles notifications, **When** toggled, **Then** the same backend endpoint is called; no notification is sent regardless of the resulting value (nothing exists yet to send one)
- [ ] **Given** the user toggles sound, **When** toggled, **Then** it updates immediately and locally — no network call — and `AnswerFeedbackPlayer`'s cues are silenced/restored accordingly on the very next graded answer

## Technical Notes

- New `lib/features/settings/` tree — look at `lib/features/auth/` and `lib/features/lesson/`'s existing `screens/`/`state/`/`widgets/` split before laying this one out
- Language/goal option sets must match onboarding's existing `language_selection_screen.dart`/`daily_goal_selection_screen.dart` — reuse their option lists, don't redefine them
- Sound preference storage mechanism (e.g. `shared_preferences`) is a Technical Design decision, not fixed here

## Dependencies

### Requires
- `001-user-preferences-service`'s stories (needs the real endpoint contract)

### Enables
- `002-logout` (same screen, separate story since logout is more of a distinct action than a "setting")

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Backend call to update a setting fails (network error) | Screen shows an inline error and the displayed value reverts to the last known-good server value, not the failed attempted value |
| User opens Settings while offline | Language/goal/notification show the last-fetched values (or a clear "can't load settings offline" state) — sound toggle still works fully offline since it's local-only |

## Out of Scope

- Logout (see `002-logout`)
- Any profile/name/avatar display (none exists in the domain model)
