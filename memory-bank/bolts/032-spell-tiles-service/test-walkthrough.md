---
stage: test
bolt: 032-spell-tiles-service
created: '2026-09-20T19:55:00Z'
---

## Test Report: 001-spell-tiles-service

### Summary

- **Tests**: 570/570 passed (551 before this stage; 19 added)
- **New tests**: 19 across four files
- **Coverage**: not measured numerically in this project; coverage here is by seam

### Test Files

- [x] `tests/integration/test_seed_course_content.py` - 10 new tests over real seed output:
      one spell-tiles per lesson, the sequence spells one of the lesson's own words,
      **repeated characters keep one tile per occurrence**, distinct ids, non-revealing tile
      order, exactly two distractors, the 12-tile ceiling, no multi-token word, no uppercase
      distractor, no vocab link
- [x] `tests/unit/test_lesson_value_objects.py` - 4 new tests on `SpellTilesContent`: the
      two-tile minimum, repeated text with distinct ids accepted, the word absent from
      `content`, one Fidel character per tile
- [x] `tests/unit/test_exercise_type_dispatch.py` - a `spell_tiles` sample added to the
      parametrized matrix (now 6 types × 4 seams), plus 3 tests pinning down that this type
      does **not** fall through to `ChoiceAnswerKey`
- [x] `tests/integration/test_lesson_endpoints.py` - 2 new tests: the type serves over real
      HTTP with its tiles and sequence, and duplicate characters survive storage → domain →
      response as separate tiles

### Acceptance Criteria Validation

- ✅ **`ExerciseType.SPELL_TILES` exists; `AnswerKey` union unchanged**: still three members,
      asserted by the dispatch matrix
- ✅ **Dispatch test passes for six types, extended not weakened**: 27 → 30 tests, same
      parametrization over `ExerciseType`
- ✅ **Migration verified by hand up, down and up**: six types → five → six on a scratch
      SQLite file, then a `spell_tiles` insert accepted and a bogus type rejected
- ✅ **`ExerciseModel.__table_args__` widened in the same change**
- ❌→✅ **`_answer_key_from_json` unchanged**: it could not be. See Issues Found
- ✅ **`_content_from_json` and `to_exercise_response` keep their guarded `raise`**: the
      latter did not have one; it does now
- ✅ **All four courses hold spell-tiles content; re-seeding changes nothing**
- ✅ **Repeated characters keep their own tiles**, asserted from real seed output
- ✅ **No multi-token word is seeded**
- ✅ **`vocab_item_id` is null on every spell-tiles exercise**
- ✅ **No exercise exceeds 12 tiles**: worst case `Hanqaaquu` at 11
- ✅ **Tile order does not reveal the answer**
- ✅ **Full backend suite green; ruff clean; mypy unchanged** at the 2 pre-existing errors
- ✅ **No client file touched**

### Falsification

The load-bearing test was checked by reproducing the bug it guards against, rather than
trusting that it would catch it.

`_spell_tiles`'s id lookup was temporarily rewritten to the text-keyed idiom the rest of the
seed uses (`{text: id}` instead of `{word_index: id}`) — the exact mistake this intent exists
to prevent. `Maaloo`'s correct sequence came back as `['t3','t5','t5','t8','t6','t6']`: the
same tile id used twice, which no learner could tap, and two characters with no tile at all.

**Only 1 of the 10 new seed tests caught it.** The other 9 passed against the broken
implementation — tile count, id uniqueness, distractor count, the tile ceiling, non-revealing
order, all still true. That is direct evidence for the claim in the unit brief that the
repeated-character test is the one carrying the weight here, and that a suite of plausible
tests around it would have shipped the bug.

The patch was reverted and the file confirmed restored before continuing.

### Issues Found

1. **`_answer_key_from_json` fell through to `ChoiceAnswerKey`** (fixed in Implement). The
   plan predicted no edit was needed; the code said otherwise. A `spell_tiles` row would have
   died on a missing `correct_choice_id`.
2. **`to_exercise_response` had no terminal `raise`** (fixed in Implement). Bolt 030 made
   `match_pairs` explicit but left `gap_fill` unguarded, so the trap had moved rather than
   closed.
3. **A bug in my own test fixture.** The hand-written `correct_sequence` for `Maaloo` was
   `t4,t2,t1,t5,t3,t6`, which spells `Malaoo`. The round-trip assertion caught it — which is
   a small demonstration that comparing the *spelled text* rather than the id list is the
   right check, since an id-list comparison would have happily passed a wrong answer key.

### Notes

- Plan decision **D3** (grade by spelled text, not by id sequence) is recorded in
  `implementation-plan.md`, in `SequenceAnswerKey`'s docstring, in
  `SpellTilesExerciseResponse`'s docstring and in `database-schema.md`. It is a **client**
  obligation and is not yet an acceptance criterion on bolt `033`'s stories — the user chose
  to leave the story text alone at the Stage 1 checkpoint. It must be carried into `033`'s
  Plan stage.
- The seeded content is unusually good at exercising this type's risk: all four Afaan Oromo
  words repeat characters (up to three of one), and no Amharic word does. A test reading only
  Amharic content would prove nothing about tile identity.
