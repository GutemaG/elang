---
id: 003-offline-packs-with-pictures
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
status: draft
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 054-picture-offline-and-credits
implemented: false
---

# Story: 003-offline-packs-with-pictures

## User Story

**As a** Buna learner with patchy data
**I want** a downloaded lesson to carry its pictures and clips
**So that** picture questions work with no network

## Acceptance Criteria

- [ ] **Given** a lesson with both types, **When** downloaded, **Then** every picture and the audio question's clip are saved on the device, and the pack refers to them by local path
- [ ] **Given** that pack with no network, **When** played, **Then** every picture shows and the clip plays
- [ ] **Given** any picture or clip that fails to download, **When** downloading, **Then** no pack is saved and the download reports failure, as today
- [ ] **Given** a cached copy (not a download) holding either type, **When** opened offline, **Then** the learner sees "download required"
- [ ] **Given** a downloaded pack, **When** removed, **Then** its pictures and clips are deleted from the device
- [ ] **Given** the downloads screen, **When** it shows a pack's size, **Then** the size includes its pictures
- [ ] **Given** the pack store, **When** a pack with both types is saved and loaded, **Then** it round-trips unchanged

## Technical Notes

- `lesson_pack_downloader.dart`, and both halves of `lesson_pack_store.dart` (save, load, delete, size), which today check only `ListeningExercise` (finding 4).
- The cached-copy rule in `lesson_screen.dart` (finding 5).

## Dependencies

### Requires
- 002-picture-questions-in-lessons-and-practice

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Two choices share a picture URL | Downloaded once or twice, but both show |
| Low storage mid-download | Fails as a whole; nothing half-saved |

## Out of Scope

- Downloading on the web build
