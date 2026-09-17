---
unit: 002-profile-and-settings-ui
intent: 005-profile-and-settings
phase: inception
status: complete
created: '2026-09-17T07:50:00Z'
updated: '2026-09-17T07:50:00Z'
unit_type: frontend
default_bolt_type: simple-construction-bolt
---

# Unit Brief: Profile & Settings UI

## Purpose

Flutter client work: the first Settings screen in this app. Views and edits language/daily-goal/notification (via `001-user-preferences-service`'s new endpoint), toggles sound (client-local, gates the existing `AnswerFeedbackPlayer` directly), and logs out (reuses the existing `SessionRepository.clearSession()`).

## Scope

### In Scope
- New `lib/features/settings/` feature tree
- Settings screen: view current values, edit language/daily-goal/notification, toggle sound
- Logout action, returning to the sign-in screen
- Client-local persistence for the sound preference

### Out of Scope
- The backend endpoint/invariant amendment itself (owned by `001-user-preferences-service`)
- Any profile/name/avatar UI (none exists in the domain model)
- Any real notification delivery

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | View Current Settings | Must |
| FR-5 | Sound Toggle (Client-Local, Fully Functional) | Must |
| FR-6 | Logout | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `SoundPreference` (client-local) | Whether `AnswerFeedbackPlayer` cues are audible | `enabled: bool`, persisted locally |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| LoadSettings | Fetch current language/goal/notification (from backend) + sound (local) | — | Rendered settings screen |
| UpdatePreference | Change language/goal/notification via `001-user-preferences-service`'s endpoint | new value | Updated backend state, refreshed screen |
| ToggleSound | Flip the local sound preference | — | `AnswerFeedbackPlayer` muted/unmuted immediately |
| Logout | Clear session, navigate to sign-in | — | Signed-out state |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 2 |
| Must Have | 2 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-settings-screen | View and edit language/daily-goal/notification/sound from one screen | Must | Planned |
| 002-logout | Log out from Settings | Must | Planned |

---

## Dependencies

### Requires
| Unit | Reason |
|------|--------|
| `001-user-preferences-service` | Needs the real endpoint contract for editing language/goal/notification |

### Depended By
| Unit | Reason |
|------|--------|
| None | Terminal unit for this intent |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None | — | — |

---

## Technical Context

### Suggested Technology
Flutter/Dart, new `lib/features/settings/` tree (screens/, state/) + `lib/shared/services/` for any new local-preference store (sound) and the settings API client — same layering convention as `lib/features/lesson/` and `lib/features/auth/`.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `001-user-preferences-service` | API | REST over HTTPS (new endpoint) |
| `AnswerFeedbackPlayer` | In-process | Direct method call/mute flag |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| Sound preference | Client-local (likely `shared_preferences` or similar lightweight store — Technical Design decision) | 1 bool | Until app uninstall/user changes it |

---

## Constraints

- Reuses `SessionRepository.clearSession()` exactly — no parallel logout implementation.
- Reuses the onboarding screens' existing language/daily-goal option sets — no new values.

---

## Success Criteria

### Functional
- [ ] All 4 settings are viewable and editable (3 via backend, 1 local) from one screen
- [ ] Logout clears session and returns to sign-in; no authenticated screen is reachable afterward without signing in again

### Non-Functional
- [ ] No regression to any existing screen (full Flutter test suite still passes)

### Quality
- [ ] Widget test coverage for the settings screen and logout flow
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 014-profile-and-settings-ui | simple-construction-bolt | 001, 002 | Settings screen + logout |

---

## Notes

First new top-level `lib/features/` folder since `auth`/`lesson` — worth a quick look at how `auth`/`lesson` structure their `screens/`/`state/`/`widgets/` split before laying this one out, for consistency.
