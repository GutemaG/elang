---
id: 002-logout
unit: 002-profile-and-settings-ui
intent: 005-profile-and-settings
status: complete
priority: must
created: '2026-09-17T07:55:00Z'
assigned_bolt: null
implemented: true
---

# Story: 002-logout

## User Story

**As a** Buna learner
**I want** to log out from Settings
**So that** I can switch accounts or stop being signed in on a shared device

## Acceptance Criteria

- [ ] **Given** the Settings screen, **When** the user taps Logout, **Then** the local session is cleared via the existing `SessionRepository.clearSession()`
- [ ] **Given** a completed logout, **When** the app is used afterward, **Then** the user lands on the sign-in screen and cannot reach any authenticated screen without signing in again
- [ ] **Given** the user taps Logout, **When** a confirmation is warranted (Technical Design decision — likely yes, to avoid an accidental tap logging someone out mid-lesson-review), **Then** the confirmation appears before the session is actually cleared

## Technical Notes

- Reuses `SessionRepository.clearSession()` exactly — no parallel session-clearing code
- Navigation after logout should mirror however the app currently routes an unauthenticated user (check `auth_routes.dart`/`splash_screen.dart`'s existing routing decision logic rather than inventing a new one)

## Dependencies

### Requires
- `001-settings-screen` (same screen, logout is one more row/action on it)

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User logs out while a lesson-completion sync is still pending (`003-offline-caching-and-sync`) | Out of scope to solve specially here — flagging as a known edge case for Technical Design to explicitly decide (e.g. warn the user, or let it sync next sign-in) rather than silently losing it |

## Out of Scope

- Account deletion
- Multi-account switching (single logout → single sign-in, no account picker)
