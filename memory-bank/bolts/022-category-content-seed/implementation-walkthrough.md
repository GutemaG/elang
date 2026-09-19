---
stage: implement
bolt: 022-category-content-seed
created: '2026-09-19T23:30:00Z'
---

## Implementation Walkthrough: category-content-seed

### Summary of changes

Added four categories of Amharic content (Family & People, Numbers & Time, Travel & Places, Colors/Body & Health) to the seed and loaded them into the dev database. The seed now holds 5 categories, 10 skills, 20 lessons, 89 exercises and 40 vocab items (72 exercises and 32 vocab items are new).

### Structure

- **New module** `backend/app/infrastructure/db/seed_category_content.py`: holds the four categories' content as compact lesson definitions and a small set of builders that expand each into the standard exercise shapes. Each lesson is declared once (its words, which two words the multiple-choice exercises test, which word the listening exercise tests, one sentence to build, optionally a match-pairs); the builder produces the four or five exercises, so shapes cannot drift between lessons.
- **Existing seed** `seed_lesson_content.py`: appends the new categories, skills and vocab to its own lists so the one existing idempotent loop seeds everything. The loop itself is unchanged. The placeholder audio URL is now defined once in the new module and reused.
- **Per lesson**: 2 vocab-linked multiple-choice exercises (one English to Amharic, one Amharic to English), 1 listening, 1 sentence construction; the second lesson of each skill adds a match-pairs, so each category has two. Correct-answer positions are rotated so they are not always the first choice, and match-pairs right columns are rotated so the answer key is not positional.
- **Ids**: deterministic slugs as before, so re-runs update in place.

### Decisions made during implementation

- Content lives in its own module instead of growing the existing 500-line seed file, since the data is about five times larger than the original.
- Vocab slugs are derived from lesson key plus word index, which guarantees uniqueness by construction.
- The match-pairs answer key is derived from the English meaning of each word, never from position, so it stays correct if the word lists are edited.

### Deviations from the plan

None. Counts match the plan exactly (72 new exercises, 32 new vocab items).

### Applied to the dev database

Backed up to `backend/dev.db.bak-pre-022`, then ran the seed. Verified afterwards:
- 5 categories, each with 2 skills; 20 lessons; 89 exercises; 40 vocab items.
- The existing user's data is untouched (1 user, 2 progress rows). They see both Foundations skills completed and the first skill of every new category active.
- A brand-new user sees one active skill in each of the five categories.

### Content caveat (NFR-3)

All Amharic was authored by the agent and is NOT native-speaker reviewed. Lower-confidence items to check first: ሐምራዊ, ብርቱካናማ, ትናንት, ህመም (also ሕመም), ቀጥታ ሂድ, ራሴን ያመኛል, ነገ እንገናኛለን, ዳቦው ነጭ ነው, and the ነኝ / ነው / ናት forms. Listening exercises still play the single shared placeholder MP3.

### What the app shows until bolt 023

The current dashboard renders one banner ("Foundations & Greetings", from the deprecated fields) followed by all ten skills in one list, so the new categories are playable but not yet visually grouped.

### Test status at end of this stage

Full backend suite passes (387 tests), `ruff check` clean. Test details belong to Stage 3.
