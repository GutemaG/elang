---
id: 001-practice-entry-point-and-due-count
unit: 002-practice-ui
intent: 008-srs-and-practice
status: complete
priority: must
created: '2026-09-17T17:05:00Z'
assigned_bolt: null
implemented: true
---

# Story: 001-practice-entry-point-and-due-count

## User Story

**As a** Buna learner
**I want** to see how many words are due for review and a clear way to start practicing them
**So that** I'm prompted to reinforce weak vocabulary, not just push forward

## Acceptance Criteria

- [ ] **Given** the user has due vocab items, **When** they view the entry point, **Then** the due-count is visible and matches the backend's due-count endpoint
- [ ] **Given** the user has zero due items, **When** they view the entry point, **Then** it reflects that clearly (e.g. `0`, or a distinct "all caught up" state — Plan-stage UI decision) rather than being hidden entirely
- [ ] **Given** the device is offline, **When** the user views the entry point, **Then** it is visibly disabled (not hidden), consistent with this app's existing "disable, don't hide" convention

## Technical Notes

- Read `main.dart`'s and `SkillTreeDashboardScreen`'s real current structure at Plan stage before deciding placement (tab vs. dashboard element) — not fixed by Inception.
- Reuse existing connectivity-detection (`003-offline-caching-and-sync`'s connectivity/sync-status indicator) rather than building new offline-detection.

## Dependencies

### Requires
- `001-srs-tracking-service`'s due-count endpoint

### Enables
- `002-practice-session-assembly-and-completion`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Due-count fetch fails (network blip while technically online) | Same error-handling convention already used for the dashboard's existing data fetches — no new pattern |

## Out of Scope

- Session assembly/rendering (see `002-practice-session-assembly-and-completion`)
