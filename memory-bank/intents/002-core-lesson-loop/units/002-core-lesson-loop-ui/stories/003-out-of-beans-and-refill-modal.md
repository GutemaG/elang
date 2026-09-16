---
id: 003-out-of-beans-and-refill-modal
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 006-core-lesson-loop-ui
implemented: true
---

# Story: 003-out-of-beans-and-refill-modal

## User Story

**As a** Buna user who has run out of beans
**I want** a clear screen explaining why my lesson stopped and how to continue
**So that** I'm not confused or stuck

## Acceptance Criteria

- [ ] **Given** the local bean count reaches 0 mid-lesson, **When** the next wrong answer would be submitted, **Then** the lesson is interrupted and the out-of-beans modal shows, matching `out_of_beans_refill_modal` design
- [ ] **Given** the modal is showing, **When** the user chooses to wait, **Then** they see when beans will regenerate (time-based) and can dismiss back to the dashboard
- [ ] **Given** the modal is showing and the user has refill currency, **When** they choose immediate refill, **Then** beans are restored and they can resume/restart the lesson
- [ ] **Given** the user dismisses without refilling, **When** they return to the dashboard, **Then** no partial lesson credit (XP) was awarded for the interrupted attempt

## Technical Notes

- Can be built against a fake beans/refill API response first; real integration is story 005.

## Dependencies

### Requires
- 002-lesson-exercise-screens (this modal is triggered from within a lesson)
- `001-lesson-service` story 002 (API contract) for the real beans/refill shape

### Enables
- None (terminal for its own flow — returns to the dashboard)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User has partial refill currency (not enough for a full refill) | Refill option is disabled/hidden rather than allowed to fail silently |
| User backgrounds the app while the modal is showing | No crash on resume; modal state doesn't need to persist across app restarts |

## Out of Scope

- The refill currency's acquisition/economy (owned by `001-lesson-service`, minimal scope per requirements.md)
