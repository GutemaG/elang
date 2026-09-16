---
id: 002-offline-lesson-taking
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
status: done
priority: must
created: '2026-09-16T20:45:00Z'
assigned_bolt: 009-offline-caching-and-sync-ui
implemented: true
---

# Story: 002-offline-lesson-taking

## User Story

**As a** Buna user with no connectivity
**I want** to take a lesson I've already downloaded, exactly as if I were online
**So that** losing signal never interrupts my learning

## Acceptance Criteria

- [x] **Given** a downloaded lesson pack and no connectivity, **When** the user starts that lesson, **Then** it loads and runs with zero network calls, using the same `LessonController`/exercise screens as the online path
- [x] **Given** the user answers exercises offline, **When** each is graded, **Then** Beans/XP/feedback behave identically to the online path (same client-side grading from `002-core-lesson-loop`'s ADR-5)
- [ ] **Given** the lesson completes offline, **When** completion is recorded, **Then** it's captured with a `client_completed_at` timestamp and queued locally (feeds into story 003) instead of calling the completion endpoint immediately — **deferred to bolt 010**: `clientCompletedAt` is captured and sent correctly, but there's no local queue yet, so a lesson finished while genuinely offline still calls the network completion endpoint directly (and fails) rather than queuing; explicitly scoped this way in bolt 009's implementation-plan.md since there's nothing to queue *to* before story 003 exists
- [x] **Given** the user attempts a lesson that was never downloaded while offline, **When** they try to start it, **Then** they see a clear "download this lesson first" state, not a spinner that never resolves or a crash

## Technical Notes

- This story should require minimal changes to `LessonController` itself — it already grades client-side; the main addition is routing lesson-content fetch through the local cache first and routing `completeLesson` through the new local queue (story 003) when offline, instead of calling the network directly.
- Must not fork the exercise engine into an "online" and "offline" variant — one engine, one grading path, different only in where content comes from and where the completion result goes.

## Dependencies

### Requires
- 001-download-lesson-packs (needs a cached pack to run against)

### Enables
- 003-pending-sync-queue-and-auto-sync (this story produces the entries that story 003 syncs)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Connectivity returns mid-lesson (was offline, now online) | Lesson continues uninterrupted on the offline path already in progress; does not switch modes mid-attempt |
| App killed mid-offline-lesson | Same durability expectation as the existing online mid-lesson-kill NFR from `002` — no crash, no corrupted state, lesson safely restartable |
| Beans reach 0 while offline | Same interruption/refill-screen behavior as online, using locally cached Beans state |

## Out of Scope

- The sync queue/engine itself (story 003)
- Any new exercise type or grading rule (unchanged from `002-core-lesson-loop`)
