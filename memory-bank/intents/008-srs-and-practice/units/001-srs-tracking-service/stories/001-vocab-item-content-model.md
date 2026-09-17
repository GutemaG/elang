---
id: 001-vocab-item-content-model
unit: 001-srs-tracking-service
intent: 008-srs-and-practice
status: ready
priority: must
created: '2026-09-17T17:00:00Z'
assigned_bolt: null
implemented: false
---

# Story: 001-vocab-item-content-model

## User Story

**As a** content maintainer (no end-user-facing behavior in this story alone)
**I want** vocabulary to exist as its own canonical content, linked from exercises
**So that** later stories can track and resurface it independently of any single exercise

## Acceptance Criteria

- [ ] **Given** the migration runs, **When** it completes, **Then** `vocab_items` exists with real seed content and `exercises.vocab_item_id` exists as a nullable FK
- [ ] **Given** an existing seeded exercise with a clear single vocab target, **When** the seed script runs, **Then** it is linked via `vocab_item_id`
- [ ] **Given** an exercise with `vocab_item_id IS NULL`, **When** any existing lesson/grading/offline flow touches it, **Then** behavior is completely unchanged (zero regression)

## Technical Notes

- Deterministic ids for `vocab_items`, same `uuid5(CONTENT_NAMESPACE, ...)` scheme as `skills`/`lessons`/`exercises`, so re-running the seed script stays idempotent — read `backend/app/infrastructure/db/seed_lesson_content.py`'s real current approach before writing the new seed logic.
- Not every exercise type necessarily gets a link on day one — partial coverage is fine (see requirements.md's Assumptions).

## Dependencies

### Requires
- None (first story in this bolt)

### Enables
- `002-vocab-progress-retrofit` (needs vocab-linked exercises to exist before progress can be tracked against them)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| An exercise type where one exercise tests multiple words (e.g. `sentence_construction`) | Leave `vocab_item_id` null for these unless a clear single-word mapping exists — don't force an artificial link |

## Out of Scope

- Progress tracking (see `002-vocab-progress-retrofit`)
