---
id: 003-idempotent-offline-replay
unit: 001-offline-sync-service
intent: 003-offline-caching-and-sync
status: done
priority: must
created: '2026-09-16T20:45:00Z'
assigned_bolt: 008-offline-sync-service
implemented: true
---

# Story: 003-idempotent-offline-replay

## User Story

**As a** mobile client syncing a queue of offline completions
**I want** to safely retry a sync call that failed partway or got interrupted
**So that** a flaky reconnect never double-awards XP or double-deducts Beans

## Acceptance Criteria

- [ ] **Given** a completion call with a given `attemptId` has already been fully processed, **When** the same call is sent again (retry, duplicate, or replay), **Then** the server returns the original result without re-applying XP/Beans effects
- [ ] **Given** a batch of N queued completions is synced one at a time and the connection drops after M < N succeed, **When** the client resumes and re-sends the full remaining queue (including any already-acknowledged ones, defensively), **Then** only the not-yet-processed ones have any effect
- [ ] **Given** the existing `002-core-lesson-loop` idempotency behavior (bolt 005, ADR-5) is re-tested under this story, **Then** it holds for calls arriving minutes-to-days after the original attempt, not just near-immediate retries

## Technical Notes

- This is primarily a re-verification/hardening story, not a rebuild: bolt 005 already introduced `attemptId`-based idempotency for the *online* duplicate-prevention case (e.g. double-tapping "Continue"). This story confirms the same guarantee holds when the delay is hours/days instead of seconds, and adds tests specifically for that gap.
- Decide here (or defer explicitly to this bolt's Technical Design) whether a batch-sync endpoint is worth adding, versus the client simply calling the existing per-completion endpoint once per queue entry. A batch endpoint reduces round trips but adds surface area; the per-item approach is simpler and already idempotent per item.
- No new database schema expected — idempotency should already be enforced via a unique constraint or lookup on `attemptId` from bolt 005.

## Dependencies

### Requires
- None (re-verifies/hardens the existing endpoint from `002-core-lesson-loop` bolt 005)

### Enables
- `002-offline-caching-and-sync-ui` story 003-pending-sync-queue-and-auto-sync (the client's auto-retry logic depends on this guarantee holding)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Two different devices somehow submit the same `attemptId` (shouldn't happen under the single-device assumption, but defensively) | Second submission is a no-op, not an error that blocks sync |
| Sync queue replays completions out of their original order (e.g. due to a client bug) | Each is still processed correctly on its own merits (idempotency doesn't depend on ordering); day-attribution correctness (story 002) does depend on `client_completed_at`, not arrival order |
| Server restarts mid-batch-sync | Already-processed `attemptId`s are unaffected; client safely resumes from wherever its local queue says it left off |

## Out of Scope

- A new batch-sync endpoint, unless Technical Design concludes it's worth the added complexity
- Multi-device conflict resolution (explicit non-goal)
