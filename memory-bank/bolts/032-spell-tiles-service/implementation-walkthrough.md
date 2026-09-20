---
stage: implement
bolt: 032-spell-tiles-service
created: '2026-09-20T19:20:00Z'
---

## Implementation Walkthrough: 001-spell-tiles-service

### Summary

`spell_tiles` is now a sixth exercise type end to end on the backend: domain value object,
widened `CHECK` constraint in both its declarations, Alembic revision, repository
reconstruction, response schema and mapping, and seeded content in all four courses. It adds
no member to the `AnswerKey` union, reusing `SequenceAnswerKey`.

The plan's approach held: adding the enum value first turned the parametrized dispatch test
into a five-item worklist, and working that list found a real defect the plan had predicted
the opposite of.

### Structure Overview

The type follows the same seam list as `gap_fill` before it. The one structural difference is
that tile identity matters here — a spelled word repeats characters — so every mapping from
tile to position is keyed by index or id, never by text.

### Completed Work

- [x] `backend/app/domain/lesson/value_objects.py` - `ExerciseType.SPELL_TILES`;
      `SpellTilesContent`; `SequenceAnswerKey`'s docstring now covers both its types and
      states the "a correct ordering, not the only one" rule; the `AnswerKey` union comment
      updated from five types to six
- [x] `backend/app/infrastructure/db/lesson_models.py` - `ck_exercises_type` widened to six
      values, class docstring extended
- [x] `backend/app/infrastructure/db/migrations/versions/f4c2a81e7b56_...py` - new revision
      on `d1b7e4f2a903`, batch-mode, with the same downgrade caveat
- [x] `backend/app/infrastructure/db/lesson_repositories.py` - `_content_from_json` gains a
      `SPELL_TILES` branch above the guarded `raise`; **`_answer_key_from_json` needed an
      edit after all** (see Deviations)
- [x] `backend/app/infrastructure/api/lesson_schemas.py` - `SpellTilesExerciseResponse`,
      added to the discriminated union
- [x] `backend/app/infrastructure/api/exercise_mapping.py` - explicit `SPELL_TILES` branch,
      and `gap_fill`'s branch made explicit so the function now ends in a `raise`
- [x] `backend/app/infrastructure/db/seed_course_content.py` - `_scatter` and `_spell_tiles`
      helpers; a seventh exercise per generated lesson; `"spell"` wording for en/am/om
- [x] `backend/app/infrastructure/db/seed_lesson_content.py` - four hand-authored
      `spell_tiles` entries in the en→am course, slug `:7`
- [x] `backend/tests/unit/test_exercise_type_dispatch.py` - a `spell_tiles` sample, using a
      word with repeated characters rather than the shared two-choice fixture
- [x] `database-schema.md` - widened constraint, plus a new per-type `content`/`answer_key`
      shape table and a note on why this type's tiles are id-only
- [x] Five existing count assertions updated across three integration test files

### Key Decisions

- **Which word gets spelled: `indexes[3]`.** Traced through `_lesson()`: exercises 1–3 answer
  with `indexes[0..2]`, so the fourth word is the only one a lesson never drills directly.
  It also avoids the sole unspellable entry in `_WORDS` — `goodbye` is two tokens in Amharic
  (`ደህና ሁን`) and sits at `indexes[1]`, which this rule never selects.
- **Distractors skip each other word's first character.** Afaan Oromo words are capitalised,
  so an uppercase tile anywhere but position one would announce itself as a distractor.
- **A separate `_spell_tiles` helper, not `_choices` or `_gap_choices`.** Both identify a
  tile by its text. The new helper keys its id lookup by the character's index in the word,
  so duplicates keep distinct ids by construction. The docstring says so.
- **`_scatter` rather than `random`.** The seed must be idempotent, so tile order is a pure
  function of the lesson's order index.
- **`to_exercise_response` now ends in a `raise`.** It previously ended in an unguarded
  `gap_fill` branch (see Deviations).

### Deviations from Plan

Two, both found by reading rather than by a failing test.

1. **`_answer_key_from_json` did need an edit — the plan predicted it would not.** Its first
   branch tested `SENTENCE_CONSTRUCTION` alone, and everything else fell through to
   `ChoiceAnswerKey`. A `spell_tiles` row would have fallen through and died on a missing
   `correct_choice_id`. The plan said "confirm, do not assume", which is the only reason this
   was checked. Fixed by naming both sequence types in that branch, and the comment bolt 030
   left there — *"keep the shared list above in mind before assuming it covers a future type
   too"* — has been rewritten to record that the trap it warned about did in fact fire.

2. **`to_exercise_response`'s guard was not where the plan assumed.** Bolt 030 made
   `match_pairs` explicit but left `gap_fill` as the unguarded final branch, so the trap had
   moved rather than closed — a `spell_tiles` exercise would have failed on an `isinstance`
   assertion naming `GapFillContent`. Every type is now explicit and the function ends in a
   `raise`, matching `_content_from_json`.

Both are the same class of defect the dispatch test exists to catch, and neither was caught
by it: the test builds its sample *through* these functions, so a type that reaches the wrong
branch fails confusingly rather than precisely. Worth remembering when a seventh type arrives.

### Dependencies Added

None.

### Developer Notes

- The seeded content exercises the duplicate-tile risk for real: every Afaan Oromo word
  selected repeats characters (`Maaloo`, `Hiriyaa`, `Aannan`, `Hanqaaquu` — up to three of
  one character) while no Amharic one does. A test that only reads Amharic content would
  prove nothing about tile identity.
- Largest seeded exercise is `Hanqaaquu` at 11 tiles, inside the 12 the client must lay out.
- The migration was verified by hand on a scratch SQLite database, since the test suite uses
  `Base.metadata.create_all` and never runs migrations: six types → five → six, then an
  insert of a `spell_tiles` row (accepted) and of a bogus type (rejected).
- Count churn was 11 assertions across three files, one fewer than bolt 030's. Each was read
  individually; all eleven were genuine count changes (22→26 per course, 159→175 total, 5→6
  per lesson, two completion payloads). No hidden defect this time.
