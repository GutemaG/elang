---
id: 002-offline-gap-fill-verification
unit: 002-gap-fill-ui
intent: 015-gap-fill-exercise-type
status: complete
priority: must
created: '2026-09-20T12:45:00Z'
assigned_bolt: 031-gap-fill-ui
implemented: true
---

# Story: 002-offline-gap-fill-verification

## User Story

**As a** Buna learner who has downloaded a lesson pack for offline use
**I want** a `gap_fill` exercise inside that pack to work exactly as it does online
**So that** offline lessons stay fully usable whatever exercise types they contain

## Acceptance Criteria

- [ ] **Given** a lesson pack containing a `gap_fill` exercise, **When** the learner downloads it, **Then** the download succeeds with no special-casing (text-only content, no audio to fetch)
- [ ] **Given** a `gap_fill` exercise, **When** it is written to a pack and read back, **Then** it round-trips with every field intact — covered by an explicit test, because `lesson_pack_store.dart` maps JSON by hand and is the one seam the sealed class does not protect
- [ ] **Given** a downloaded pack, **When** the learner takes that lesson offline, **Then** the exercise plays with zero network calls
- [ ] **Given** an offline completion of a lesson containing a `gap_fill` exercise, **When** connectivity returns, **Then** it syncs through the existing `SyncEngine`/`PendingSyncQueueStore` with zero changes to that code

## Technical Notes

- Mostly a verification story. `LessonPackDownloader`, `SyncEngine` and `PendingSyncQueueStore` are exercise-type-agnostic by construction, so this should pass without changes to them.
- `lesson_pack_store.dart` is the exception and **does** need real work: both the serialize map and the deserialize `case`. An omission there fails silently at runtime, which is why the round-trip test is an acceptance criterion rather than a nicety.
- If something does not work without changes to the offline path, that is a real finding to fix here — not to wave through. The same discipline was applied when `003-offline-caching-and-sync`'s device verification turned up the seed audio-URL bug.
- Expect already-downloaded packs to be invalidated once the seed adds gap-fill exercises to existing lessons: `updated_at` bumps `content_version`. That is correct behaviour, not a regression.

## Dependencies

### Requires
- `001-gap-fill-exercise-screen`

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A pack mixing `gap_fill` with a `listening` exercise that needs audio | Whole-pack semantics unchanged — a failed audio fetch still fails the whole pack (the existing "no partial pack" design) |
| A pack downloaded before this intent shipped, without gap-fill content | Invalidated by the `content_version` bump and re-downloaded; no crash, no stale-content mix |

## Out of Scope

- New offline capability of any kind — this verifies that existing behaviour extends, it does not extend it
