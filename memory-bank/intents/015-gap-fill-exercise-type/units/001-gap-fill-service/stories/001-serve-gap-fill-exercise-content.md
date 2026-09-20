---
id: 001-serve-gap-fill-exercise-content
unit: 001-gap-fill-service
intent: 015-gap-fill-exercise-type
status: complete
priority: must
created: '2026-09-20T12:45:00Z'
assigned_bolt: 030-gap-fill-service
implemented: true
---

# Story: 001-serve-gap-fill-exercise-content

## User Story

**As a** Buna learner
**I want** a `gap_fill` exercise's sentence, gap and word choices served the same way any other exercise's content is
**So that** the client can render it with no special-case fetching logic

## Acceptance Criteria

- [ ] **Given** a lesson containing a `gap_fill` exercise, **When** the client fetches lesson content, **Then** the response carries the learning-language sentence with one word removed, a from-language gloss of the full sentence, the `choices`, and `correct_choice_id`
- [ ] **Given** the existing lesson-content endpoint, **When** it serves a `gap_fill` exercise, **Then** no new endpoint or response envelope is introduced — the existing per-exercise shape gains one more variant
- [ ] **Given** the `AnswerKey` union, **When** this story is complete, **Then** it has **the same members as before** — `gap_fill` reuses `ChoiceAnswerKey`
- [ ] **Given** the `exercises` table, **When** a `gap_fill` row is inserted, **Then** `ck_exercises_type` permits it, via a migration using `op.batch_alter_table`, whose downgrade and re-upgrade are both verified
- [ ] **Given** the seeded curriculum, **When** it is re-seeded, **Then** at least one `gap_fill` exercise exists in each of the four courses, and re-running the seed changes nothing
- [ ] **Given** a seeded `gap_fill` exercise, **When** it is inspected, **Then** `vocab_item_id` names the word being tested, so it feeds SRS/Practice like the other vocabulary-linked types
- [ ] **Given** the same sentence in two learning languages, **When** both are seeded, **Then** each blanks its own authored position — not a shared computed index

## Technical Notes

- Add `GAP_FILL = "gap_fill"` to `ExerciseType` in `backend/app/domain/lesson/value_objects.py`, and `GapFillContent` to the `ExerciseContent` union. Do **not** add to the `AnswerKey` union.
- A migration **is** required. `exercises.type` carries a `CheckConstraint` that does not auto-widen; bolt 011 assumed otherwise and was wrong. Copy `c726efa81972`'s batch-mode pattern, and update the matching literal string in `ExerciseModel.__table_args__` — the constraint is declared in two places.
- Source material for seeding already exists: `_SENTENCES` in `seed_course_content.py` carries per-language `answer` tokens and `distractors`. The blank position is the new authored field.
- Instruction wording needs a new key in `_TEXT` for `en`/`am`/`om`, alongside the existing `mean`/`listen`/`translate`/`match`.
- Open decision, to be made at the bolt's plan stage against real code: whether the gap is a sentinel inside the existing non-null `prompt` column or structured segments inside `content`. Record the outcome; if it turns out to warrant an ADR, write one.

## Dependencies

### Requires
- None

### Enables
- `002-gap-fill-ui`'s stories (need this contract to render and grade against)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A sentence whose blanked word appears twice in it | Avoid in seed content; the model does not need to disambiguate positions in v1 |
| A distractor that is grammatically impossible in the gap, making the answer guessable | Content quality issue, fixed in the seed — blank position and distractors are authored, not computed |
| A two-token sentence where blanking one token leaves almost nothing | Acceptable for short sentences; prefer blanking the content word over the function word |
| A learning language whose sentence has fewer tokens than another's for the same meaning | Already true (`ዳቦ እፈልጋለሁ` vs `Daabboo nan barbaada`) — per-language authored blank index handles it |

## Out of Scope

- Client rendering and grading (owned by `002-gap-fill-ui`)
- Multi-gap sentences
- Typing into the gap rather than selecting
