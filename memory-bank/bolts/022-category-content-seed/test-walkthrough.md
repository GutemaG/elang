---
stage: test
bolt: 022-category-content-seed
created: '2026-09-19T23:50:00Z'
---

## Test Report: category-content-seed

### Summary

- **Backend**: 392/392 passed (`uv run pytest`), `ruff check` clean. Up from 364 at the end of bolt 021: 28 new tests, plus one existing test adjusted.
- **Coverage**: 100% on the new content module (`seed_category_content.py`). `seed_lesson_content.py` is at 93%; the uncovered lines are the CLI `main()` entry, unchanged in nature from before.
- **Flutter**: not run for this bolt; no Flutter code changed (the last full run, 164/164, was at the end of bolt 021).
- **Real database**: the seed was applied to `dev.db` (backed up first) and the resulting skill tree checked for both an existing and a brand-new user (see the implementation walkthrough).

### Test Files

- `tests/integration/test_seed_category_content.py` (23 tests). Structure: the four requested categories in order 2 to 5; each has 2 skills of 2 lessons; every lesson has at least 4 exercises including the three core types; every category has at least one match-pairs; exercise order is consecutive. Integrity: slugs unique across all new data; choice exercises have 4 distinct choices with a real correct id and the correct answer is not always in the same position; sentence sequences only use word-bank tiles and always include distractor tiles; match-pairs cover every tile exactly once, are real pairings and not positional; vocab links resolve, none are shared, exactly 32 exist and only multiple-choice exercises are linked; vocab words are Amharic and translations are not; English-to-Amharic questions have an Amharic correct answer; listening exercises use the documented placeholder audio. Database: expected row counts (5 categories, 10 skills, 20 lessons, 89 exercises, 40 vocab items), every vocab link resolves to a row, a second run changes no counts, each new category has an Amharic subtitle.
- `tests/integration/test_seeded_categories_end_to_end.py` (5 tests, real seed, real DB and HTTP): every one of the 20 lessons loads and every one of the 89 exercises serializes through the same response mapping the API uses (catches any content that does not fit its exercise type); every lesson belongs to a skill in a seeded category; a new user sees five categories each with exactly one active skill; a Family & People lesson is fetched and completed over HTTP, awarding XP and creating two vocab-progress rows; finishing both lessons of the Numbers skill completes it and unlocks only its own category's next skill (Time), while the other categories' second skills stay locked.
- **Adjusted**: `tests/integration/test_seed_lesson_content.py`: the "edit content updates in place" test selected the skill with order index 1 and expected exactly one; it now selects by the skill's deterministic id, as several categories share order 1.

### Acceptance Criteria Validation

- ✅ Four new categories with 2 skills x 2 lessons each; every lesson has at least 4 exercises from at least 3 types (structure tests).
- ✅ Each new category has at least one match-pairs exercise (two each, structure test).
- ✅ Vocab-linked multiple-choice exercises resolve to new vocab items (integrity and database tests; completing a lesson created the expected progress rows).
- ✅ Re-running the seed creates no duplicates (row counts unchanged on a second run).
- ✅ All answer keys, sequences and pair ids pass the structural checks, and every exercise serializes through the real response mapping.
- ✅ Existing tests pass, with only the order-index test adjusted.
- ✅ dev.db seeded and verified.
- ✅ The not-native-reviewed caveat is recorded in the walkthrough, the module docstring and this report.

### What these tests cannot show

They guard shape, links and uniqueness. They cannot judge whether the Amharic is correct, natural or spelled the way a native speaker would write it (NFR-3). A native-speaker proof-read remains a required manual step before any real release, starting with the lower-confidence items listed in the implementation walkthrough.

### Issues Found

None outstanding. Two things were handled during the stage: an early edit to the seed hook did not apply (the unused import was auto-removed by the linter), caught by a row-count check before any tests were written; and one long test name tripped the line-length rule and was shortened.

### Follow-ups

- Native-speaker review of all new Amharic content.
- Real per-word audio to replace the shared placeholder (pre-existing limitation).
- Bolt 023 groups the dashboard by category; until then the app shows one banner above all ten skills.
