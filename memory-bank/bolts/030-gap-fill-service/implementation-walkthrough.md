---
stage: implement
bolt: 030-gap-fill-service
created: '2026-09-20T14:20:00Z'
---

## Implementation Walkthrough: 001-gap-fill-service

### Summary

`gap_fill` is now a fifth exercise type served through the existing lesson-content endpoint: a learning-language sentence with one word removed, the words to choose between, and which one is right. It reuses `ChoiceAnswerKey`, so the `AnswerKey` union is unchanged. Every lesson in all four courses now ends with a gap-fill — sixteen new exercises in total.

One planned behaviour was dropped after reading the code: gap-fill does **not** set `vocab_item_id`. See Deviations.

### Structure Overview

The change follows the seams `match_pairs` established in bolt 011, minus the answer-key work. The type is declared once in the domain enum and constrained twice in the database layer (migration and ORM); content crosses the boundary as JSON and is reconstructed into a value object, then mapped to a discriminated-union response. Seed content is generated for the three courses whose curriculum is built by a function, and hand-written for the one whose curriculum is a literal.

### Completed Work

- [x] `backend/app/domain/lesson/value_objects.py` - adds `ExerciseType.GAP_FILL` and the `GapFillContent` value object, joins it to the `ExerciseContent` union, and records on the `AnswerKey` union why it deliberately stays at three members for five types
- [x] `backend/app/infrastructure/db/lesson_models.py` - widens the `ck_exercises_type` literal and notes that the constraint is declared in two places
- [x] `backend/app/infrastructure/db/migrations/versions/d1b7e4f2a903_...py` - widens the same constraint in the database, batch mode for SQLite; the downgrade narrows it back and says what that means for rows already seeded
- [x] `backend/app/infrastructure/db/lesson_repositories.py` - reconstructs gap-fill content from JSON, and makes the match-pairs branch explicit (see Key Decisions)
- [x] `backend/app/infrastructure/api/lesson_schemas.py` - adds `GapFillExerciseResponse` and joins it to the discriminated union
- [x] `backend/app/infrastructure/api/exercise_mapping.py` - maps the domain object to that response, and likewise makes match-pairs explicit
- [x] `backend/app/infrastructure/db/seed_course_content.py` - per-language authored blank positions on each sentence, a gap-fill instruction in all three from-languages, a three-option choice builder, and the generated gap-fill exercise
- [x] `backend/app/infrastructure/db/seed_lesson_content.py` - four hand-written gap-fills for the English to Amharic course
- [x] `database-schema.md` - the widened constraint and the two-places note
- [x] `backend/tests/integration/test_seed_course_content.py` - updated counts (see Deviations)
- [x] `backend/tests/integration/test_seed_category_content.py` - updated row counts
- [x] `backend/tests/integration/test_seeded_categories_end_to_end.py` - updated exercise total

### Key Decisions

- **The sentence is stored as the text either side of the gap**, as planned. Nothing during Implement argued against it: the gap-at-the-start case (three of the four hand-written exercises) is simply an empty string, with no special handling anywhere.
- **Both fall-through branches are now explicit.** The plan predicted this as the bolt's likeliest source of a baffling error, and it was right in one direction and wrong in the other. `_content_from_json` and `to_exercise_response` both ended in an unguarded match-pairs branch; a gap-fill row would have been read as match-pairs and died on a missing `left_tiles` key. Both now test the type explicitly and `_content_from_json` raises a named error for an unmapped type. But `_answer_key_from_json`'s fall-through lands on `ChoiceAnswerKey`, which is *correct* for gap-fill — that file needed no edit at all on the answer-key side.
- **A separate three-option choice builder.** The existing `_choices` assumes four options and derives the correct id from `position % 4`; with two distractors it would have named a tile that does not exist. That is a silent wrong-answer-key bug, not a crash, so gap-fill got its own small builder rather than a shared one bent to fit.
- **Gap-fill is appended last, at order_index 5, or 6 where a match-pairs already holds 5.** An existing test asserts exercise order is consecutive from one within each lesson, which a fixed index of 6 would have broken in lessons without a match-pairs. The slug is always `:6` regardless, so it does not move depending on what else the lesson contains.

### Deviations from Plan

1. **Gap-fill does not set `vocab_item_id`.** The intent approved it at Checkpoint 2 and the plan carried it. Implementing it failed an existing test — `test_vocab_is_linked_only_from_multiple_choice_and_none_is_shared` — which turned out to be guarding something real: `list_exercises_by_vocab_item_ids` keeps the **first row per `vocab_item_id`**, so a vocab item maps to exactly one exercise. A gap-fill sharing a word with the multiple-choice exercise that already teaches it would either never be served in Practice or would displace that exercise, decided by a UUID comparison. Linking adds no SRS coverage; it only makes which exercise Practice serves arbitrary. Dropped, with the reasoning recorded at both seed sites. Raised for the user at the Stage 2 checkpoint, since it contradicts an approved requirement. Genuinely widening SRS coverage would mean seeding vocab items for the words that have none — new scope, not a correction.

2. **`seed_category_content.py` was left untouched.** It holds sixteen further lessons for the English to Amharic course. The acceptance criterion is at least one gap-fill per course, which the four hand-written ones satisfy; adding sixteen more means sixteen authored Amharic blank positions, which is content work rather than mechanism. Recorded as a follow-up.

3. **Eleven existing assertions were updated, not one.** The plan predicted a single count assertion would break. Fourteen tests failed: exercise totals (143 → 159), per-course counts (18 → 22), lesson length (4 → 5) and two lesson-completion payloads, which the API rejects when `total_count` disagrees with the lesson. Every one is an arithmetic consequence of sixteen new exercises — twelve generated plus four hand-written — and each was updated with a comment naming the old value and why it moved. One test that might have been expected to break did not: the one asserting order is consecutive from one, because of the ordering decision above.

### Dependencies Added

None.

### Developer Notes

`ck_exercises_type` is declared **twice** — in the migration and on `ExerciseModel.__table_args__`. Widening one alone leaves the ORM and the database disagreeing, and the tests will not necessarily catch it.

Verified by hand on a scratch database, not just in the suite: upgrade → downgrade → re-upgrade, checking `sqlite_master` after each step. The constraint reads five types, four, then five.

Two pre-existing mypy errors remain in the backend, in `app/domain/lesson/services.py` and in a part of `lesson_repositories.py` this bolt did not touch. Neither is new and neither was fixed here.
