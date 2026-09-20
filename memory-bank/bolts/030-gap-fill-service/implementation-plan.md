---
stage: plan
bolt: 030-gap-fill-service
created: '2026-09-20T13:05:00Z'
---

## Implementation Plan: 001-gap-fill-service

### Objective

Serve a fifth exercise type, `gap_fill`, through the existing lesson-content endpoint: a learning-language sentence with one word removed plus the words to choose from, carrying everything the client needs to render and grade it locally. No new endpoint, no new answer-key shape, no change to the four existing types.

### Deliverables

1 - `ExerciseType.GAP_FILL` and `GapFillContent` in `backend/app/domain/lesson/value_objects.py`, with `GapFillContent` added to the `ExerciseContent` union and **nothing added to the `AnswerKey` union**
2 - An Alembic migration widening `ck_exercises_type` from four values to five, plus the duplicated literal in `ExerciseModel.__table_args__`
3 - Reconstruction in `lesson_repositories.py`, response schema in `lesson_schemas.py`, mapping in `exercise_mapping.py`
4 - Seeded `gap_fill` exercises in all four courses, through the existing idempotent loop, with authored per-language blank positions and `vocab_item_id` set where the blanked word is a vocabulary item
5 - `database-schema.md` updated (declared source of truth for columns and constraints)

### Dependencies

- None. This extends `001-lesson-service` code in place. No new packages, no external services.

---

### Technical Approach

#### Decision 1 — the content shape

`GapFillContent(sentence_before: str, sentence_after: str, choices: tuple[Choice, ...])`: the sentence either side of the gap, stored trimmed, with the gap's spacing supplied by the client's layout.

Three shapes were considered:

1 - **A sentinel such as `___` inside the existing `prompt` column.** Rejected: `prompt` already carries the from-language *instruction* for every existing type (`"What does '{w}' mean?"`, `"Translate: '{s}'"`), so putting renderable sentence structure there breaks that convention, and it forces the client to parse a magic string.
2 - **A token list plus a `blank_index`.** Tempting, because `_SENTENCES` already stores `answer` as per-language token lists and the blank index is literally an index into one. Rejected: it is an off-by-one waiting to happen, and if `tokens` held the full sentence the answer would sit in `content` as well as the answer key.
3 - **Two strings either side of the gap.** Chosen. No index arithmetic, no sentinel that could collide with real text, the answer appears only in the answer key, and a gap at the very start or end is just an empty string rather than a special case.

Validation in `__post_init__`, matching the existing content value objects: at least two choices, and not both sides empty.

#### Decision 2 — what `prompt` holds

The from-language instruction with the full sentence glossed, following `sentence_construction`'s existing `"Translate: '{s}'"` pattern. This needs one new key in `_TEXT` for `en`, `am` and `om`. That wording is agent-authored and inherits `010`'s NFR-3 native-speaker review blocker, like the rest of the seeded content.

#### Decision 3 — the answer key, and a free win

`gap_fill` reuses `ChoiceAnswerKey` unchanged. Reading the code makes this better than expected: `_answer_key_from_json` (`lesson_repositories.py:97`) special-cases only `SENTENCE_CONSTRUCTION` and `MATCH_PAIRS` and **falls through to `ChoiceAnswerKey`**. So the answer-key half of reconstruction needs *no edit at all* — the new type is already handled correctly by the existing fallback.

#### Trap — two unguarded fall-through branches

The same fall-through pattern is a hazard on the content side. Both of these end with an **unguarded** `match_pairs` branch rather than an explicit test:

- `_content_from_json` (`lesson_repositories.py:82-95`) — its final `return MatchPairsContent(...)` is reached by anything that is not one of the first three types
- `to_exercise_response` (`exercise_mapping.py`) — its final `assert isinstance(exercise.content, MatchPairsContent)` likewise

A `gap_fill` row would fall into both and fail on a confusing assertion or `KeyError`. Both must become explicit `if exercise_type is ExerciseType.MATCH_PAIRS:` branches, with `gap_fill` handled on its own. This is the single most likely way for this bolt to produce a baffling runtime error.

#### Migration

Copy `c726efa81972`'s pattern exactly: `op.batch_alter_table`, because SQLite cannot alter a `CHECK` in place while PostgreSQL issues a plain `ALTER`. Verify upgrade → downgrade → upgrade. Update the duplicated constraint literal in `ExerciseModel.__table_args__` in the same change — it is declared in two places and only one of them is the migration.

#### Seeding

**Three-course seed (`seed_course_content.py`).** `_SENTENCES` gains a per-language `blank` index — authored, never computed, because the same sentence has different token counts per language (`Daabboo nan barbaada` is 3, `ዳቦ እፈልጋለሁ` is 2). The builder derives `sentence_before`/`sentence_after` by joining the tokens either side, takes the blanked token as the correct choice, and draws wrong choices from the sentence's existing `distractors`.

**Blank selection rule**: prefer a blank position whose token is one of the 16 vocabulary words, so `vocab_item_id` can be set and the exercise feeds SRS/Practice. Where no token qualifies, leave `vocab_item_id` null — the column is nullable and `None` means "no SRS tracking", not "not yet linked".

**Original course (`seed_lesson_content.py`).** Same treatment, against its own curriculum structure, which is hand-written rather than generated. To be read properly at Implement.

**Ordering**: append the gap-fill exercise **last** in each lesson (`order_index` = current max + 1, so 5 or 6 depending on whether that lesson has a `match_pairs`). This leaves every existing row's `order_index` untouched. Placing it before `sentence_construction` would arguably suit the difficulty curve better, but it would renumber existing exercises for no functional gain — raise it as a content question later rather than churn rows now.

#### Known test breakage

`backend/tests/integration/test_seed_course_content.py:428` asserts `len(lesson["exercises"]) == 4`. Adding a gap-fill exercise to every lesson makes that 5. This is an expected assertion update, not a regression — but it must be updated deliberately and the new count justified, not simply relaxed.

---

### Acceptance Criteria

- [ ] `ExerciseType.GAP_FILL` exists; `GapFillContent` is in the `ExerciseContent` union
- [ ] The `AnswerKey` union has exactly the same three members as before
- [ ] `_content_from_json` and `to_exercise_response` test `MATCH_PAIRS` explicitly; neither reaches a match-pairs branch by fall-through
- [ ] A migration widens `ck_exercises_type` via `op.batch_alter_table`; upgrade → downgrade → upgrade verified on SQLite
- [ ] `ExerciseModel.__table_args__`'s literal lists all five types
- [ ] A `gap_fill` exercise is served through the existing lesson-content endpoint with its sentence either side of the gap, its choices and `correct_choice_id`
- [ ] At least one `gap_fill` exercise is seeded in each of the four courses
- [ ] Each seeded gap-fill blanks its own authored per-language position
- [ ] `vocab_item_id` is set wherever the blanked word is a vocabulary item
- [ ] Re-running the seed changes nothing
- [ ] `database-schema.md` reflects the widened constraint
- [ ] Full backend suite green; no file under `lib/` touched

---

### Risks

1 - **Fall-through branches** (above). Highest-likelihood failure in this bolt. Mitigated by making both explicit and by testing a `gap_fill` round-trip through the repository, not just the value object.
2 - **Assuming no migration is needed.** Bolt 011 made exactly this mistake on `match_pairs` and was corrected mid-Implement. Listed as a deliverable here so it cannot recur.
3 - **Content quality.** A distractor that is grammatically impossible in the gap makes the answer guessable. Blank positions and distractors are authored, so this is a content fix, not a model change — but it wants a read-through of what the builder actually produces.
4 - **Offline pack invalidation.** Seeding into existing lessons bumps `updated_at` → `content_version` → already-downloaded packs are invalidated. Correct behaviour; noted so it is not mistaken for a regression during bolt 031's verification.

### Out of Scope

- Client rendering and grading (bolt `031-gap-fill-ui`)
- Multi-gap sentences, typing into the gap
- Reordering existing exercises within a lesson
