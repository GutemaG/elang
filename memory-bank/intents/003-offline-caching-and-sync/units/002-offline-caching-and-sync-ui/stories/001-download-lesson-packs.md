---
id: 001-download-lesson-packs
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
status: done
priority: must
created: '2026-09-16T20:45:00Z'
assigned_bolt: 009-offline-caching-and-sync-ui
implemented: true
---

# Story: 001-download-lesson-packs

## User Story

**As a** Buna user about to lose connectivity
**I want** to download a skill's lessons ahead of time
**So that** I can keep learning with no signal

## Acceptance Criteria

- [x] **Given** the skill-tree dashboard, **When** the user taps a download affordance on an unlocked skill, **Then** that skill's lesson content (all exercises) and audio assets download and are cached locally, with visible progress
- [x] **Given** a downloaded pack, **When** the app is restarted or the device is rebooted, **Then** the pack remains cached and usable offline
- [x] **Given** a cached pack less than 14 days old, **When** the app is offline, **Then** it's used as-is with no re-validation attempt (no re-validation of any kind happens yet, which trivially satisfies this — see next row)
- [ ] **Given** a cached pack 14+ days old, **When** the device is online, **Then** its content version is compared against the server (story 001 of `001-offline-sync-service`) and re-downloaded only if changed — **deferred**, `content_version` is stored and threaded through per bolt 009's implementation-plan.md, but the actual staleness comparison isn't wired up; revisit as a follow-up if not picked up in bolt 010

## Technical Notes

- Local storage via sqflite/drift per `tech-stack.md`; audio files stored as regular files with paths indexed in the local DB, not as BLOBs, for straightforward playback via the existing audio player.
- Reuses `002-core-lesson-loop`'s lesson-content response shape; this story only adds "fetch once, persist locally, serve from cache" around it, not a new content format.
- Download progress can be approximated from bytes-received on the audio downloads (the dominant payload size) rather than requiring exact per-file progress plumbing.

## Dependencies

### Requires
- `001-offline-sync-service` story 001-content-version-signal (for the staleness check)

### Enables
- 002-offline-lesson-taking (nothing to take offline without a downloaded pack)
- 005-download-management-screen (needs downloaded packs to list)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Download interrupted mid-way (connectivity drops during download) | Partial pack is not considered valid/usable; download resumes or restarts next time online, never left in a half-usable state |
| User downloads the same skill twice | Second download is a no-op if the cached version is already current |
| Device runs out of storage mid-download | Download fails gracefully with a clear error; no partial/corrupt pack left behind |

## Out of Scope

- Deleting/managing downloaded packs (story 005)
- Any backend change beyond the version signal already covered by `001-offline-sync-service`
