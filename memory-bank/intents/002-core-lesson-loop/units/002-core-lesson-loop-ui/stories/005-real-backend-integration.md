---
id: 005-real-backend-integration
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 007-core-lesson-loop-ui
implemented: true
---

# Story: 005-real-backend-integration

## User Story

**As a** Buna user
**I want** the lesson-loop screens to actually call the real backend
**So that** the app works end-to-end instead of against a mock

## Acceptance Criteria

- [ ] **Given** `001-lesson-service` is fully implemented and tested, **When** the app calls skill-tree/lesson/answer/completion endpoints, **Then** a real API implementation replaces the fake one used in stories 001-004, matching the exact request/response shapes from `001-lesson-service`'s Technical Design
- [ ] **Given** the backend returns an error (e.g. out of beans, locked skill, invalid attempt) or a network-level failure, **When** the client receives it, **Then** it maps to a clear UI state — no screen/controller redesign should be needed beyond the API-implementation swap, per the same design intent used successfully in `001-auth-onboarding`'s bolt 003
- [ ] **Given** a full lesson taken against the real backend, **When** completed, **Then** the skill-tree dashboard reflects the real updated state on return (not stale/mocked data)

## Technical Notes

- Same pattern as `001-auth-onboarding`'s story 005/bolt 003 — this time planned upfront as part of the original unit brief rather than discovered afterward, since we now know from experience this integration seam is needed.
- If the "no screen/controller changes" assumption breaks (as it partially did in `001-auth-onboarding`), that's an explicit finding to report during Construction, not something to force.

## Dependencies

### Requires
- `001-lesson-service` (complete — both bolts 004 and 005)
- 001-skill-tree-dashboard-screen, 002-lesson-exercise-screens, 003-out-of-beans-and-refill-modal, 004-lesson-complete-streak-and-levelup-modals (the screens this plugs into)

### Enables
- None (terminal story for this intent)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Backend unreachable (dev server not running, network error) | Same inline-error-and-retry pattern already established in `001-auth-onboarding` |
| `001-lesson-service`'s actual response shape drifted from what the fake API assumed during stories 001-004 | Explicit finding reported, fixed as part of this story, not silently patched over |

## Out of Scope

- Any change to `001-lesson-service` (backend is already complete for this intent's scope by the time this story starts)
