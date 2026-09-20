---
stage: test
bolt: 030-gap-fill-service
created: '2026-09-20T15:10:00Z'
---

## Test Report: 001-gap-fill-service

### Summary

- **Tests**: 547/547 passed (509 at the end of Implement, +38 here)
- **Lint**: `ruff check` and `ruff format --check` clean across `app/` and `tests/`
- **Migration**: verified by hand, upgrade → downgrade → re-upgrade (see Notes)

### Test Files

- [x] `tests/unit/test_exercise_type_dispatch.py` - **new**. Parametrized over `ExerciseType` itself: every type is reconstructed as its own content class, gets its own answer-key class, maps to its own response-union member, and appears in the ORM `CHECK` constraint. A sixth type fails here the moment it joins the enum. Also pins the specific regression: gap-fill content is `GapFillContent` and not `MatchPairsContent`, and gap-fill shares `ChoiceAnswerKey`.
- [x] `tests/unit/test_lesson_value_objects.py` - `TestGapFillContent`: rejects a sentence empty on both sides, requires two choices, accepts a gap at the start, the end and the middle, and asserts the missing word is absent from the stored content.
- [x] `tests/integration/test_lesson_repositories.py` - a `gap_fill` row round-trips out of a real SQLite database with both sides of the gap, its choices, a `ChoiceAnswerKey`, and a null `vocab_item_id`.
- [x] `tests/integration/test_lesson_endpoints.py` - `TestGapFillExercise`: the lesson-content endpoint serves `sentence_before`, `sentence_after`, `choices` and `correct_choice_id`, and never leaks the raw `answer_key` column name.
- [x] `tests/integration/test_seed_course_content.py` - seven structural checks over the generated courses: one gap-fill per lesson; the missing word is a real choice and is *not* left in the sentence; text on at least one side and both sides trimmed; distinct choice ids and texts naming a real correct id; the answer is not always in the same position; no gap-fill is vocab-linked; and the blank index is keyed per language, with the three-token-vs-two-token sentence asserted directly.
- [x] Eleven assertions updated during Implement (counts), each carrying a comment naming the old value.

### Acceptance Criteria Validation

- ✅ **`ExerciseType.GAP_FILL` and `GapFillContent` in the content union**: covered by the parametrized dispatch tests
- ✅ **`AnswerKey` union unchanged**: asserted directly — gap-fill resolves to `ChoiceAnswerKey`
- ✅ **No fall-through to match-pairs**: asserted, and the assertion was verified meaningful (see Notes)
- ✅ **Migration widens the constraint, round-trip verified**: by hand, on a scratch database
- ✅ **ORM constraint lists all five types**: parametrized test reads `ExerciseModel.__table_args__`
- ✅ **Served through the existing endpoint**: HTTP test
- ✅ **A gap-fill in each of the four courses**: three generated courses covered by the per-lesson test; the English to Amharic four are hand-written and covered by the total-count assertions
- ✅ **Per-language authored blank positions**: asserted, including that a shared index could not work
- ⚠️ **`vocab_item_id` set where the blanked word is a vocabulary item**: **not met, deliberately.** Inverted to "no gap-fill is vocab-linked", with a test asserting it. See Issues.
- ✅ **Re-running the seed changes nothing**: existing idempotency tests, with updated counts
- ✅ **`database-schema.md` updated**
- ✅ **Full backend suite green, no file under `lib/` touched**

### Issues Found

1. **The approved `vocab_item_id` requirement was wrong, and an existing test caught it.** `test_vocab_is_linked_only_from_multiple_choice_and_none_is_shared` failed as soon as gap-fill linked a word. It was guarding a real invariant: `list_exercises_by_vocab_item_ids` keeps the first row per `vocab_item_id`, so a vocab item maps to exactly one exercise. A gap-fill sharing a word would either never reach Practice or would displace the multiple-choice exercise, decided by a UUID comparison. Resolved by dropping the link and asserting its absence. Raised at the Stage 2 checkpoint and accepted. Widening SRS coverage properly means seeding vocab items for the words that have none — separate scope.

2. **The test database never exercises the migration.** `conftest.py` builds tables with `Base.metadata.create_all`, so the suite validates the ORM constraint and nothing else. The migration was therefore checked by hand rather than trusted. Worth knowing before assuming a green suite proves a migration.

3. **Two pre-existing mypy errors remain**, in `app/domain/lesson/services.py` and in an untouched part of `lesson_repositories.py`. Neither is new; neither was fixed here.

### Notes

**The new dispatch tests were verified to be meaningful, not just green.** I temporarily restored the pre-bolt fall-through — removing the explicit `MATCH_PAIRS` guard and the gap-fill branch — and re-ran them. Three failed, with `KeyError: 'left_tiles'`, which is precisely the confusing failure the plan predicted a gap-fill row would produce. The fix was then restored and the file re-verified. A test that passes both with and without the fix would have proved nothing.

**Migration round-trip**, on a scratch SQLite database outside the repo, reading `sqlite_master` after each step:

- upgrade → head: constraint lists five types, including `gap_fill`
- downgrade → -1: four types, `gap_fill` gone
- upgrade → head: five again

**What this bolt does not cover.** Rendering and client-side grading belong to bolt `031-gap-fill-ui`, including both halves of `lesson_pack_store.dart` — the one seam the Dart sealed class does not protect. The sixteen further English to Amharic lessons in `seed_category_content.py` have no gap-fill yet; that is content work, recorded as a follow-up.

**Content caveat.** The gap-fill instruction wording in Amharic and Afaan Oromo is agent-authored and not native-speaker reviewed, inheriting `010-multi-language-courses`' NFR-3 release blocker along with the rest of the seeded content.
