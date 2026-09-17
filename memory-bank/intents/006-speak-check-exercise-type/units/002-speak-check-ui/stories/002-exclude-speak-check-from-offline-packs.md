---
id: 002-exclude-speak-check-from-offline-packs
unit: 002-speak-check-ui
intent: 006-speak-check-exercise-type
status: ready
priority: must
created: '2026-09-17T14:50:00Z'
assigned_bolt: null
implemented: false
---

# Story: 002-exclude-speak-check-from-offline-packs

## User Story

**As a** Buna learner
**I want** offline downloads to work correctly even when a lesson includes a speak-check exercise
**So that** I never hit a broken or silently-wrong experience while offline

## Acceptance Criteria

- [ ] **Given** a lesson containing a `speak_check` exercise, **When** the user tries to download it for offline use, **Then** the app does not crash and does not silently ship a speak-check exercise that can't be graded offline
- [ ] **Given** the resolved product decision (FR-5: exclude entirely), **When** `LessonPackDownloader` encounters a `speak_check` exercise, **Then** it is excluded from offline availability — exact mechanism (skip the whole lesson's download eligibility vs. skip just that exercise within an otherwise-downloadable lesson) is a Technical Design decision made once `LessonPackDownloader`'s real code is read at Construction
- [ ] **Given** a lesson with no `speak_check` exercise, **When** downloaded, **Then** behavior is completely unchanged (zero regression to existing offline downloads)

## Technical Notes

- Read `LessonPackDownloader`'s actual current per-exercise-type handling before deciding the exclusion mechanism — don't guess the granularity at Inception
- Zero regression to `009-offline-caching-and-sync-ui`/`010-offline-caching-and-sync-ui`'s existing tests is a hard requirement

## Dependencies

### Requires
- `001-speak-check-service`'s stories (the exercise type must exist to test against)

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| An already-downloaded pack from before this feature shipped, now re-synced/re-downloaded after a lesson gains a `speak_check` exercise | Should re-download cleanly and apply the exclusion, not error — same "re-download and overwrite" behavior `LessonPackDownloader.downloadLesson` already documents for content-version changes |

## Out of Scope

- Any offline queueing/deferred-scoring mechanism (explicitly excluded per FR-5's resolved decision)
