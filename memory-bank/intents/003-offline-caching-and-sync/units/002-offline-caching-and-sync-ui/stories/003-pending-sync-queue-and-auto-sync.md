---
id: 003-pending-sync-queue-and-auto-sync
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
status: done
priority: must
created: '2026-09-16T20:45:00Z'
assigned_bolt: 010-offline-caching-and-sync-ui
implemented: true
---

# Story: 003-pending-sync-queue-and-auto-sync

## User Story

**As a** Buna user who completed lessons while offline
**I want** that progress to reach the server automatically the moment I'm back online
**So that** I never have to think about syncing myself, and never lose progress

## Acceptance Criteria

- [x] **Given** one or more offline-completed lessons queued locally, **When** connectivity returns, **Then** each entry syncs automatically, in the order it was completed, with no user action required
- [x] **Given** a sync entry succeeds, **When** confirmed by the server, **Then** it's removed from the local queue; a duplicate/retried send of an already-synced entry never double-applies (relies on `001-offline-sync-service` story 003's idempotency)
- [x] **Given** a sync attempt fails due to a server error (not just no connectivity), **When** that happens, **Then** it retries automatically with backoff and the entry stays queued rather than being dropped
- [x] **Given** the device goes offline again mid-sync, **When** connectivity returns again later, **Then** sync resumes from where the queue actually stands, with no entry lost or double-counted
- [x] **Given** the queue has been unsynced for 30+ days, **When** the connectivity indicator (story 004) reflects this, **Then** it escalates to a clearly more visible warning state, without ever auto-dropping entries

## Technical Notes

- The queue has no size or time cap by design (see `requirements.md` FR-3 resolution) — entries are small metadata (`attemptId`, lesson/skill id, `client_completed_at`, Beans/XP delta), so retention cost is negligible next to the cost of losing progress.
- Sync calls each queued entry through `001-offline-sync-service`'s (amended) completion endpoint using the entry's own `client_completed_at`, per that unit's story 002.
- Connectivity detection is shared infrastructure with story 004 (the indicator) — build the connectivity monitor once, consume it from both.

## Dependencies

### Requires
- 002-offline-lesson-taking (produces the queue entries)
- `001-offline-sync-service` stories 002 (timestamped completion) and 003 (idempotent replay)

### Enables
- 004-connectivity-and-sync-status-indicator (surfaces this story's state)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Multiple entries complete within the same session, app is force-closed before any sync | On next launch, the full queue is still present and syncs correctly once online |
| Connectivity flaps rapidly (on/off/on within seconds) | Sync engine doesn't spam retries into a failure loop; backoff prevents thrashing |
| A queued entry's lesson was later deleted/changed server-side before sync | Server-side handling of this is `001-offline-sync-service`'s concern; client surfaces whatever error comes back rather than assuming success |

## Out of Scope

- The visible indicator UI itself (story 004)
- A batch-sync endpoint (only if `001-offline-sync-service` story 003 decides to add one — this story works either way)
