---
stage: test
bolt: 025-course-content-seed
created: '2026-09-20T20:30:00Z'
---

## Test Report: course-content-seed

### Summary

- **Full backend suite**: 502/502 passed (470 before this bolt, 32 new); `ruff check` and `ruff format --check` clean
- **New tests**: 32 in one file, all written in the Implement stage and run here
- **Real database**: the seed was run twice against `dev.db`; row counts were identical both times (4 courses, 8 categories, 16 skills, 32 lessons, 143 exercises, 64 vocab)

### Test Files

- [x] `backend/tests/integration/test_seed_course_content.py` - the three courses exist, are available, and have the right language pairs with no clash against English to Amharic; each has one category, two skills of two lessons, at least 4 exercises per lesson from at least 3 types, and a match-pairs; slugs unique across the whole seed; four distinct choices with a real correct id and varied position; sentence answers use only bank tiles with distractors and a shuffled bank; match pairs cover each tile once and are not positional; vocab linked only from multiple choice, 8 per course, none shared; placeholder audio; no filler text; script and language per direction (Latin only for English to Afaan Oromo, Amharic prompts with Afaan Oromo answers, Afaan Oromo prompts with Amharic answers, vocab word and translation in the right scripts); the same word appears in every direction; database counts per course (1 category, 2 skills, 4 lessons, 18 exercises, 8 vocab); English to Amharic unchanged (5 categories, 40 vocab); second run changes nothing; every vocab link stays inside its own course; and, for each of the three courses over HTTP, signup on the pair lands on the course, the first lesson completes and creates only that course's vocab progress, and finishing the first skill unlocks the second
- [x] `backend/tests/integration/test_seed_lesson_content.py`, `test_seed_category_content.py`, `test_seeded_categories_end_to_end.py` - existing tests, adjusted for the new totals and scoped script check (no test deleted or weakened)

### Acceptance Criteria Validation

- ✅ **Three available courses seeded** (English to Afaan Oromo, Amharic to Afaan Oromo, Afaan Oromo to Amharic): definition and database tests
- ✅ **1 category, 2 skills, each skill 2 lessons; each lesson at least 4 exercises from at least 3 types; at least one match-pairs per course**: structure tests
- ✅ **Prompts in the from-language and answers in the learning language, correct script**: per-direction script tests, plus a read-only look at the real API output
- ✅ **Vocab-linked exercises resolve to that course's own vocab**: vocab-link and per-course count tests, and the HTTP test proving only that course's vocab progress is created
- ✅ **Re-running the seed creates nothing new**: idempotency test and a double run on `dev.db`
- ✅ **All answer keys, sequences and pair ids pass structural checks**: integrity tests
- ✅ **Existing tests pass with only the course-scoping adjustments**: full suite green
- ✅ **`dev.db` seeded and verified through the API for each course**: done in the Implement stage
- ⏳ **Native-speaker review**: not possible here; recorded below

### Issues Found

- None in the implementation. One of my own assertions failed on first run (it expected a capital "Hello" where the prompt uses lowercase); the test was corrected, not the content.
- Language correctness, especially Afaan Oromo, cannot be tested here. The tests guard shape, links, script and uniqueness only.

### Notes

- **Needs native review before any real release** (NFR-3). Lowest-confidence items are listed in `implementation-plan.md`: Akkam as "hello", Nagaatti, Galatoomi's form, Daabboo versus Buddeena, Hanqaaquu, Aannan, "nan barbaada", the category subtitle, and all Afaan Oromo and Amharic prompt phrasing.
- The listening exercises all play the same placeholder MP3.
- Restart the backend and rebuild the app to see the new courses once the picker exists (bolt 026); until then the courses are reachable through the API and by signing up on a pair.
