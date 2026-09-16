---
id: 005-download-management-screen
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
status: done
priority: could
created: '2026-09-16T20:45:00Z'
assigned_bolt: 010-offline-caching-and-sync-ui
implemented: true
---

# Story: 005-download-management-screen

## User Story

**As a** Buna user with several downloaded skills
**I want** to see what's taking up space on my device and remove packs I don't need anymore
**So that** I stay in control of my device storage

## Acceptance Criteria

- [x] **Given** one or more downloaded packs, **When** the user opens the download-management screen, **Then** each downloaded skill/lesson is listed with an approximate storage size
- [x] **Given** a listed pack, **When** the user chooses to delete it, **Then** the local cache (content + audio) is removed, freeing the reported storage (also fixed a bolt-009 bug in the same pass: `delete()` previously only removed the DB row, never the audio files on disk)
- [x] **Given** a pack is deleted, **When** checked afterward, **Then** already-synced server-side progress for that skill is completely unaffected — only the local offline-replay cache is gone (delete only ever touches local storage, never calls the backend)
- [x] **Given** a pack has pending, not-yet-synced completions tied to it, **When** the user attempts to delete it, **Then** they see a clear warning before proceeding (deleting the pack doesn't touch the sync queue, but the warning avoids confusion)

## Technical Notes

- Storage size can be approximated from file sizes already tracked by the download manager (story 001) — no need for a live filesystem scan.
- This is a `Could`-priority story — if construction time is tight, it can be deferred without blocking the rest of the unit, since FR-1/FR-2/FR-3 deliver the actual offline value.

## Dependencies

### Requires
- 001-download-lesson-packs (needs downloaded packs to manage)

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User deletes a pack for a skill they're mid-lesson in | Either disallowed while a lesson from that pack is active, or the active lesson is allowed to finish first — exact behavior is a Technical Design decision, but it must not crash or corrupt the in-progress attempt |
| User deletes all downloaded packs | Screen shows an empty state, not an error |

## Out of Scope

- Automatic cache eviction/cleanup policies (e.g. auto-delete after N days) — this story is manual management only
