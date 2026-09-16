---
id: 002-offline-match-pairs-verification
unit: 002-match-pairs-ui
intent: 004-match-pairs-exercise-type
status: complete
priority: must
created: '2026-09-17T04:30:00Z'
assigned_bolt: null
implemented: true
---

# Story: 002-offline-match-pairs-verification

## User Story

**As a** Buna learner who has downloaded a lesson pack for offline use
**I want** a `match_pairs` exercise inside that pack to work exactly like it does online
**So that** offline lessons remain fully usable regardless of exercise type

## Acceptance Criteria

- [x] **Given** a lesson pack containing a `match_pairs` exercise, **When** the user downloads it, **Then** the download succeeds with zero special-casing (text-only content, no audio files to fetch) — verified: `LessonPackDownloader` required no code change, real test added
- [x] **Given** a downloaded pack with a `match_pairs` exercise, **When** the user takes that lesson offline, **Then** the exercise plays with zero network calls, identical to the other offline-capable exercise types today — verified end-to-end (download → offline take)
- [x] **Given** an offline completion of a lesson containing a `match_pairs` exercise, **When** connectivity returns, **Then** the completion syncs through the existing `SyncEngine`/`PendingSyncQueueStore` from `003-offline-caching-and-sync` with zero changes to that code — verified: queued correctly, zero `SyncEngine`/`PendingSyncQueueStore` code touched

## Technical Notes

- This is primarily a verification story, not new implementation — `LessonPackDownloader`/`LessonPackStore`/`SyncEngine` are exercise-type-agnostic by construction, so this should work without code changes
- If it does NOT work without changes, that is a real finding and must be fixed here (do not silently mark this story done if a regression is found — same discipline applied when the seed-audio-URL bug was found during `003-offline-caching-and-sync`'s physical-device verification)

## Dependencies

### Requires
- 001-match-pairs-exercise-screen

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Pack containing a mix of `match_pairs` and other exercise types (e.g. one `listening` exercise needing audio) | Whole-pack download semantics unchanged — a failed audio fetch still fails the whole pack (existing "no partial pack" design from `003-offline-caching-and-sync`) |

## Out of Scope

- Any new offline-path feature (this story verifies existing behavior extends correctly, it does not add new offline capability)
