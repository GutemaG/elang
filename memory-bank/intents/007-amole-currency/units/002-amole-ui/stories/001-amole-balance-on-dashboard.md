---
id: 001-amole-balance-on-dashboard
unit: 002-amole-ui
intent: 007-amole-currency
status: complete
priority: must
created: '2026-09-17T16:20:00Z'
assigned_bolt: null
implemented: true
---

# Story: 001-amole-balance-on-dashboard

## User Story

**As a** Buna learner
**I want** to see my Amole balance on the home dashboard
**So that** I know how close I am to affording a refill without having to run out of Beans first

## Acceptance Criteria

- [ ] **Given** the home dashboard, **When** it loads, **Then** the current Amole balance is displayed next to the existing XP/streak display
- [ ] **Given** the user completes a lesson that awards Amole, **When** they return to the dashboard, **Then** the displayed balance reflects the new total without a manual refresh action
- [ ] **Given** the user spends Amole via the out-of-Beans modal, **When** the modal closes, **Then** the dashboard's displayed balance reflects the reduced total

## Technical Notes

- Reuse the existing beans-status fetch the dashboard already performs for the Beans HUD — read `skill_tree_dashboard_screen.dart`'s actual current data flow at Plan stage before adding a second fetch path.
- Depends on `001-amole-service`'s retrofit (response shape unchanged, so this should be a pure UI addition with no API-client change expected — verify at Plan stage).

## Dependencies

### Requires
- `001-amole-service`'s stories (needs a real, changing balance to display and verify against)

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Balance is 0 | Displayed as `0`, not hidden |
| Dashboard loads before the beans-status fetch resolves | Same loading-state handling already used for the existing Beans/XP display — no new loading pattern |

## Out of Scope

- Any change to `OutOfBeansSheet` (already correct, verified during requirements-gathering)
