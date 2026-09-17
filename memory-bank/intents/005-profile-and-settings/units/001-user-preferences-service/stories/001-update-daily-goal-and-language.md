---
id: 001-update-daily-goal-and-language
unit: 001-user-preferences-service
intent: 005-profile-and-settings
status: complete
priority: must
created: '2026-09-17T07:55:00Z'
assigned_bolt: null
implemented: true
---

# Story: 001-update-daily-goal-and-language

## User Story

**As a** Buna learner
**I want** to change my daily XP goal and target language after I've already signed up
**So that** my settings aren't locked in forever from onboarding

## Acceptance Criteria

- [ ] **Given** a signed-in user, **When** they submit a new daily goal via the new endpoint, **Then** their `daily_xp_target` updates and is reflected the next time the skill-tree dashboard's daily-goal progress is read
- [ ] **Given** a signed-in user, **When** they submit a new language via the new endpoint, **Then** their `selected_language` updates
- [ ] **Given** an invalid goal or language value (not in the existing onboarding screens' option set), **When** submitted, **Then** the request is rejected (422), matching this backend's existing validation-error pattern
- [ ] **Given** `entities.py`'s `User` docstring, **When** this story ships, **Then** the "written exactly once, never overwritten" invariant comment is updated to document the new, deliberate exception — not left stale/wrong

## Technical Notes

- New endpoint, e.g. `PATCH /api/v1/users/me` (exact path/method is a Technical Design decision, not fixed here)
- Reuse the exact goal/language value sets already defined for onboarding (`DailyXPTarget`/`LanguageCode` value objects, `backend/app/domain/value_objects.py`) — do not invent new allowed values
- This is a genuine invariant amendment, not a bug fix — the ADR Analysis stage should seriously consider whether this warrants its own ADR (a prior similar amendment, ADR-5, superseded ADR-4 for a different reason; this one should get its own record if created)

## Dependencies

### Requires
- None

### Enables
- `002-profile-and-settings-ui`'s story `001-settings-screen` (needs this real endpoint to build the edit UI against)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User submits the same value they already have | Succeeds as a no-op update, not an error |
| Concurrent requests changing the same user's preferences | Last-write-wins is acceptable (no optimistic locking needed) — this is a low-contention, single-user-editing-their-own-settings scenario |

## Out of Scope

- Notification preference (see `002-store-notification-preference`)
- Any UI (see `002-profile-and-settings-ui`)
