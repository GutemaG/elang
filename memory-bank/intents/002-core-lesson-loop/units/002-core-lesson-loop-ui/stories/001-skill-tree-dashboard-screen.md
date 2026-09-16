---
id: 001-skill-tree-dashboard-screen
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 006-core-lesson-loop-ui
implemented: true
---

# Story: 001-skill-tree-dashboard-screen

## User Story

**As a** Buna user
**I want** to see my skill tree as soon as I sign in
**So that** I know what to learn next and can start a lesson

## Acceptance Criteria

- [ ] **Given** a signed-in user, **When** they reach the post-sign-in destination, **Then** they see the skill-tree dashboard instead of the current placeholder
- [ ] **Given** the skill tree data, **When** rendered, **Then** locked, active, and completed nodes are visually distinct per the Highland Pulse design (`4._home_skill_tree_dashboard`), with crown-level badges on completed nodes
- [ ] **Given** a locked node, **When** tapped, **Then** nothing happens (not interactive) — matches the design's lock affordance
- [ ] **Given** an active node, **When** tapped, **Then** the user is taken into that node's lesson (story 002)

## Technical Notes

- This story can be built against a fake/documented skill-tree API response shape first (mirroring `001-auth-onboarding`'s original mock-first approach), with real integration deferred to story 005.
- Becomes the new destination that `AuthFlowController.resolveStartDestination()` (from `001-auth-onboarding`) routes to instead of the current placeholder.

## Dependencies

### Requires
- `001-lesson-service` story 001 (API contract, from Technical Design — not full implementation) for the real skill-tree shape

### Enables
- 002-lesson-exercise-screens (tapping an active node starts a lesson)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Skill tree fetch fails (network error) | Inline error + retry, consistent with the auth flow's existing failure-handling pattern — no crash |
| Very long skill list (future-proofing) | Scrollable path, not a fixed-height layout |

## Out of Scope

- Any backend logic (owned by `001-lesson-service`)
- Real backend integration (story 005)
