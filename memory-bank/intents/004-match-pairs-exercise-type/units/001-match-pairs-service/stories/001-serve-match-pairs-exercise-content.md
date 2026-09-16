---
id: 001-serve-match-pairs-exercise-content
unit: 001-match-pairs-service
intent: 004-match-pairs-exercise-type
status: complete
priority: must
created: '2026-09-17T04:30:00Z'
assigned_bolt: null
implemented: true
---

# Story: 001-serve-match-pairs-exercise-content

## User Story

**As a** Buna learner
**I want** a `match_pairs` exercise's term/translation pairs served the same way any other exercise's content is
**So that** the client can render it with no special-case fetching logic

## Acceptance Criteria

- [x] **Given** a lesson containing a `match_pairs` exercise, **When** the client fetches lesson content, **Then** the exercise's content includes shuffleable `left_tiles`/`right_tiles` plus a separate `correct_pairs` answer-key field (corrected from this story's original `{left, right}`-pairs-as-ground-truth wording — see Technical Notes)
- [x] **Given** the existing lesson-content endpoint, **When** it serves a `match_pairs` exercise, **Then** no new endpoint or response envelope is introduced — the existing per-exercise content shape is simply extended with one more variant
- [x] **Given** the seeded curriculum, **When** it is (re-)seeded, **Then** at least one `match_pairs` exercise exists with a plausible Amharic-term ↔ English-translation pair set

## Technical Notes

- Added `MATCH_PAIRS = "match_pairs"` to `ExerciseType` in `backend/app/domain/lesson/value_objects.py`, alongside `MULTIPLE_CHOICE`, `LISTENING`, `SENTENCE_CONSTRUCTION`
- **Corrected during Implement** (2026-09-17): added both `MatchPairsContent` (`left_tiles`/`right_tiles`, reusing `Choice`) and `PairAnswerKey` (`correct_pairs`) as separate value objects, not one merged/self-revealing content blob — `Exercise.answer_key` is mandatory and every existing type keeps content/answer separate. See `memory-bank/bolts/011-match-pairs-service/ddd-01-domain-model.md`.
- Seed data added to `backend/app/infrastructure/db/seed_lesson_content.py` (Coffee & Tea lesson, order_index 5), idempotent re-run pattern.
- A migration WAS needed (also corrected during Implement): `exercises.type` has a `CheckConstraint` that doesn't auto-widen for new JSON content — delivered as migration `c726efa81972` via `op.batch_alter_table`.

## Dependencies

### Requires
- None

### Enables
- 002-grade-match-pairs-attempts (needs the content/answer shape this story defines)
- `002-match-pairs-ui`'s stories (needs this content to render)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A `match_pairs` exercise with only 2 pairs (minimum viable) | Serves and grades correctly, no special-casing for small N |
| Duplicate translation text across pairs (e.g. two Amharic terms both translating loosely to "hello") | Out of scope for this story — seed data must avoid ambiguous pairs; not a system-level validation concern |

## Out of Scope

- Grading logic (see 002-grade-match-pairs-attempts)
- Audio pairs (text ↔ text only for v1, per requirements.md)
