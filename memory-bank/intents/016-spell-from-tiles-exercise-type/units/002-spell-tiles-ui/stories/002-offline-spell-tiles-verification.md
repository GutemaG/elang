---
id: 002-offline-spell-tiles-verification
unit: 002-spell-tiles-ui
intent: 016-spell-from-tiles-exercise-type
status: complete
priority: must
created: '2026-09-20T18:10:00Z'
assigned_bolt: 033-spell-tiles-ui
implemented: true
---

# Story: 002-offline-spell-tiles-verification

## User Story

**As a** Buna learner with no connection
**I want** a downloaded lesson containing a spell-tiles exercise to play exactly as it does online
**So that** downloading a lesson means downloading all of it

## Acceptance Criteria

- [x] **Given** a lesson containing a `spell_tiles` exercise, **When** it is downloaded, **Then** the download succeeds and the pack contains the exercise
- [x] **Given** a downloaded pack, **When** the learner takes the lesson offline, **Then** the `spell_tiles` exercise renders and grades with zero network calls
- [x] **Given** a `spell_tiles` exercise **whose word has repeated characters**, **When** it is serialized to the pack and read back, **Then** every tile survives with its own id and the built-spelling comparison still works
- [x] **Given** the completion, **When** the device is offline, **Then** it queues and syncs on reconnect through the existing `SyncEngine` path, unchanged
- [x] **Given** the deserialize case for `spell_tiles` is removed, **When** the project is built, **Then** it still compiles and fails only at runtime — confirming the asymmetry is real and that this test is what guards it

## Technical Notes

- Both halves of `lesson_pack_store.dart` need a `spell_tiles` entry. Bolt `031` lifted the four mapping functions to the top level precisely so they could be tested without a sqflite-backed store, and added the round-trip harness — reuse it rather than rebuilding it.
- The write side is a switch over the sealed `Exercise` and will not compile without its new arm. The read side is a switch over a **string** and fails only at runtime, inside a downloaded pack, offline. That asymmetry is documented in the doc comment `031` left there.
- The round-trip test must use a repeating word. A round trip of `ቡና` would pass even if ids were dropped and text used as the key, which is exactly the failure this story is here to catch.
- The last acceptance criterion is a deliberate falsification step, not a shipped test: temporarily remove the case, observe the runtime failure, restore it, and record the observed message in the walkthrough. `030` and `031` both did this and both found something.

## Dependencies

### Requires
- `001-spell-tiles-exercise-screen`

### Enables
- None (terminal story for this intent)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A pack downloaded before this type existed | `content_version` changes when the seed touches the lesson, so the pack is invalidated and re-downloaded. Expected, not a bug |
| A pack containing every one of the six exercise types | All six round-trip; worth one test that asserts the full set rather than six separate ones |
| Tile ids that collide across two exercises in one pack | Ids are scoped per exercise, as they already are for `sentence_construction` and `match_pairs` — no change needed, but do not assume it, check it |

## Out of Scope

- Any change to `SyncEngine`, `PendingSyncQueueStore` or `LessonPackDownloader`
- Audio caching (this type has no audio)
