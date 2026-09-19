---
stage: implement
bolt: 025-course-content-seed
created: '2026-09-20T20:10:00Z'
---

## Implementation Walkthrough: course-content-seed

### Summary

Three starter courses now exist in the seed and in `dev.db`: English to Afaan Oromo, Amharic to Afaan Oromo, and Afaan Oromo to Amharic. Each has one category, two skills of two lessons, and teaches the same 16 words, so a learner of any of the three source languages has something to study. All Afaan Oromo and cross-language text is agent-authored and not native-speaker reviewed (NFR-3).

### Structure Overview

One new data module holds a single shared word list (English, Amharic, Afaan Oromo), one sentence per lesson, and the question wording for each from-language. Small builders expand it into the standard exercise shapes for each of the three courses, so the directions cannot drift apart. The existing seed script appends the result to its own course, category, skill and vocab lists and seeds everything through its one idempotent loop; no loop changes were needed because bolt 024 already reads a course reference on categories and vocab.

### Completed Work

- [x] `backend/app/infrastructure/db/seed_course_content.py` - new: the 16 words, four lesson sentences, per-language question wording, and builders for the courses, categories, skills, lessons, exercises and course-owned vocab
- [x] `backend/app/infrastructure/db/seed_lesson_content.py` - appends the new courses, categories, skills and vocab to the seed lists; the summary line now reports courses
- [x] `backend/tests/integration/test_seed_lesson_content.py` - the Ethiopic-script check is scoped to lessons of courses that involve Amharic (English to Afaan Oromo is Latin script throughout)
- [x] `backend/tests/integration/test_seed_category_content.py` - whole-seed row counts updated (8 categories, 16 skills, 32 lessons, 143 exercises, 64 vocab)
- [x] `backend/tests/integration/test_seeded_categories_end_to_end.py` - lesson and exercise totals updated (32 and 143)
- [x] `backend/tests/integration/test_seed_course_content.py` - new: structure, integrity, script per direction, seeding counts per course, English to Amharic unchanged, idempotency, vocab links stay within their course, and each course studied over HTTP (sign up on the pair, first lesson, unlock)
- [x] `backend/dev.db` - seeded after a backup (`dev.db.bak-pre-025`); the existing user, progress and English to Amharic content are unchanged

### Key Decisions

- **One shared word list for all three directions**: guarantees the same 16 words and lessons everywhere, and means a native-speaker review checks each word once.
- **Vocab per course**: each new course has its own 8 vocab items (word in the language being learned, translation in the learner's language), matching the per-course Practice rule from ADR-12.
- **Sentence tiles shuffled deterministically**: the bank puts the last answer tile first and inserts the two distractors between the rest, so the bank is never already in order.
- **Category subtitle in the language being learned**, matching how the existing category subtitle is Amharic.

### Deviations from Plan

- Totals in the plan were miscounted: the seed adds 54 exercises (18 per course: 4 lessons x 4, plus a match-pairs in the second lesson of each skill) and 24 vocab items (8 per course: two vocab-linked multiple-choice exercises per lesson), not 51 and 48. Tests assert the real numbers.
- The new test file was written during this stage, to prove the content before seeding the real database. Stage 3 will run and report it rather than write it.

### Dependencies Added

None.

### Developer Notes

- Checked read-only through the real API against `dev.db` for each course: the tree shows one category, "Greetings & Basics" active and "Food & Drink" locked; the first lesson has 4 exercises with prompts in the right language; English to Amharic still shows 5 categories and 8 words due, while the new courses show 0 (Practice is scoped per course).
- Full backend suite: 502 passed, ruff clean.
- The lowest-confidence Afaan Oromo and Amharic items are listed in `implementation-plan.md`; get those reviewed before any real release.
- Listening exercises still play the single placeholder audio.
