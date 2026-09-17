---
id: 002-vocab-progress-retrofit
unit: 001-srs-tracking-service
intent: 008-srs-and-practice
status: ready
priority: must
created: '2026-09-17T17:00:00Z'
assigned_bolt: null
implemented: false
---

# Story: 002-vocab-progress-retrofit

## User Story

**As a** Buna learner
**I want** my answers on vocab-linked exercises to be tracked over time
**So that** words I struggle with can resurface later instead of only ever appearing once in fixed lesson order

## Acceptance Criteria

- [ ] **Given** a lesson completion includes a vocab-linked exercise the user has never answered before, **When** `complete_lesson` runs, **Then** a `user_vocab_progress` row is created at box 1
- [ ] **Given** a lesson completion includes a vocab-linked exercise the user has answered before, **When** `complete_lesson` runs, **Then** the existing row is updated per the Leitner rule (`003-leitner-box-algorithm`), not duplicated
- [ ] **Given** a delayed offline completion is replayed through the existing idempotent-sync mechanism (`003-offline-caching-and-sync`) for an `attempt_id` already processed, **When** it is retried, **Then** vocab progress is **not** updated a second time — same idempotency guarantee XP/Beans already have
- [ ] **Given** a lesson with no vocab-linked exercises, **When** completed, **Then** no `user_vocab_progress` writes occur and no error results

## Technical Notes

- Read `complete_lesson`'s real current implementation and its idempotency short-circuit (`existing = await attempt_repo.get(attempt_id); if existing is not None: return existing.outcome`) at Stage 4 — the vocab-progress side-effect must sit inside that same idempotency boundary, not after it in a way that could run twice.
- Per-exercise correctness (needed to know box-up vs. box-reset) must be derivable from what `complete_lesson` already receives — verify at Technical Design whether per-exercise correctness data is already passed in or needs a new parameter (client currently reports aggregate `correct_count`/`total_count`, not necessarily per-exercise detail — check the real request shape before assuming).

## Dependencies

### Requires
- `001-vocab-item-content-model`

### Enables
- `003-leitner-box-algorithm` (the actual transition math this story's writes apply)
- `002-practice-ui` (needs real progress data to have anything due)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Client doesn't currently report per-exercise correctness to `complete_lesson` | This story may require widening the completion request contract — a real Technical Design finding, not assumed here; flag and resolve at Construction, don't silently skip per-exercise tracking |

## Out of Scope

- The box-transition math itself (see `003-leitner-box-algorithm`)
