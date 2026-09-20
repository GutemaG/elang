---
id: 001-serve-spell-tiles-exercise-content
unit: 001-spell-tiles-service
intent: 016-spell-from-tiles-exercise-type
status: complete
priority: must
created: '2026-09-20T18:10:00Z'
assigned_bolt: 032-spell-tiles-service
implemented: true
---

# Story: 001-serve-spell-tiles-exercise-content

## User Story

**As a** Buna learner
**I want** a `spell_tiles` exercise's character tiles and correct order served the same way any other exercise's content is
**So that** the client can render it with no special-case fetching logic

## Acceptance Criteria

- [ ] **Given** a lesson containing a `spell_tiles` exercise, **When** the client fetches lesson content, **Then** the response carries the from-language prompt word, the shuffled `tiles` each with a stable id, and `correct_sequence` as tile ids in spelling order
- [ ] **Given** the existing lesson-content endpoint, **When** it serves a `spell_tiles` exercise, **Then** no new endpoint or response envelope is introduced
- [ ] **Given** the `AnswerKey` union, **When** this story is complete, **Then** it has **the same members as before** — `spell_tiles` reuses `SequenceAnswerKey`
- [ ] **Given** the `exercises` table, **When** a `spell_tiles` row is inserted, **Then** `ck_exercises_type` permits it, via a migration using `op.batch_alter_table`, whose downgrade and re-upgrade are both verified by hand
- [ ] **Given** a seeded word with repeated characters (`Galatoomi`, `Hanqaaquu`, `Daabboo`), **When** its exercise is read back, **Then** every repeated character is still present as its own tile with its own id — none collapsed
- [ ] **Given** a seeded `spell_tiles` exercise, **When** its tiles are inspected, **Then** they include two distractor characters drawn from the same lesson's other words, and `correct_sequence` omits them
- [ ] **Given** a seeded `spell_tiles` exercise, **When** its `content` is inspected, **Then** the tile order does not reveal the answer — `correct_sequence` is a permutation of a subset, not `t1..tN` in order
- [ ] **Given** a seeded `spell_tiles` exercise, **When** it is inspected, **Then** `vocab_item_id` is **null**, and a test asserts it
- [ ] **Given** the seeded curriculum, **When** it is re-seeded, **Then** at least one `spell_tiles` exercise exists in each of the four courses, and re-running the seed changes nothing
- [ ] **Given** an Amharic word and an Afaan Oromo word, **When** both are seeded, **Then** the Amharic one is split into Fidel characters (`ሰላም` → three tiles) and the Afaan Oromo one into Latin letters

## Technical Notes

- Add `SPELL_TILES = "spell_tiles"` to `ExerciseType` in `backend/app/domain/lesson/value_objects.py`, and `SpellTilesContent` to the `ExerciseContent` union. Do **not** add to the `AnswerKey` union — keep the comment there that records the deliberate asymmetry.
- ~~`_answer_key_from_json` needs **no edit**: its `correct_sequence` branch already returns a `SequenceAnswerKey`.~~ — **wrong, corrected during Construction (2026-09-20, bolt 032)**. That branch tested `SENTENCE_CONSTRUCTION` *alone*; everything else fell through to `ChoiceAnswerKey`, so a `spell_tiles` row would have died on a missing `correct_choice_id`. Both sequence types are now named in the branch. The note left there by bolt 030 — *"keep the shared list above in mind before assuming it covers a future type too"* — is why this was checked rather than assumed.
- `_content_from_json` and `to_exercise_response` both need an explicit branch, and their guarded fall-through must stay a `raise`, not become a silent default. Note `to_exercise_response` did **not** actually have a `raise`: bolt 030 made `match_pairs` explicit but left `gap_fill` as the unguarded final branch, so the trap had moved rather than closed. Bolt 032 named every type and added the `raise`.
- A migration **is** required. `exercises.type` carries a `CheckConstraint` declared in **two** places: the Alembic revision and `ExerciseModel.__table_args__`. Bolt 011 assumed otherwise and was wrong; `030` did it correctly — copy `d1b7e4f2a903` and set `down_revision` to it.
- The test DB uses `Base.metadata.create_all` and never runs migrations, so a green suite proves nothing about the revision. Verify by hand on a scratch SQLite file: six types → five → six.
- **Do not reuse `_choices`, and do not use the `id_by_token = {tile["text"]: tile["id"]}` idiom.** Both key by tile text and will silently collapse `Galatoomi`'s two `a`s. Write a separate helper and say in its docstring why it exists, as `_gap_choices` does.
- Instruction wording needs a new key in `_TEXT` for `en`/`am`/`om`, alongside `mean`/`listen`/`translate`/`match`/`gap`.
- Splitting into characters: Python iterates a `str` by code point, which is the right granularity for both Fidel and Latin here. Neither language's seeded words use combining marks — confirm that against the real `_WORDS` rather than assuming it.
- Open decision for the bolt's Plan stage, against real code: **which** of the lesson's four words is spelled. It should not be one the lesson already drills three times over.

## Dependencies

### Requires
- None

### Enables
- `002-spell-tiles-ui`'s stories (need this contract to render and grade against)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A word with three of the same character (`Hanqaaquu`) | Three tiles, three ids, all present; `correct_sequence` names each in the right position |
| A distractor character that happens to already be in the word | Choose a different distractor in the seed; a tile bank where a "distractor" is indistinguishable from a real tile makes `correct_sequence` ambiguous to a human even if not to the code |
| A two-character word (`ቡና`) | Valid — two tiles plus two distractors is still a real exercise |
| A nine-letter word (`Hanqaaquu`) | Valid — eleven tiles. Layout is the client unit's problem, not a reason to skip the word |
| A word containing a space (`ደህና ሁን`, `thank you`) | Avoid in seed content for v1; spelling a multi-word phrase from character tiles is not the exercise. Prefer single-token words |

## Out of Scope

- Client rendering and grading (owned by `002-spell-tiles-ui`)
- Decomposing a Fidel character into consonant and vowel
- Multi-word spelling
