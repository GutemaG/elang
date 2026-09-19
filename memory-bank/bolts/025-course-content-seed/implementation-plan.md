---
stage: plan
bolt: 025-course-content-seed
created: '2026-09-20T19:10:00Z'
---

## Implementation Plan: course-content-seed

### Objective

Seed three starter courses, so a learner who speaks English, Amharic or Afaan Oromo can study in their own language: English to Afaan Oromo, Amharic to Afaan Oromo, and Afaan Oromo to Amharic. Each course has one category ("Foundations & Greetings"), 2 skills x 2 lessons, and is loaded into the dev database, which will then hold four playable courses.

### Real-Source Findings (re-read at Plan stage)

- The seed already supports this: `seed_lesson_content.py` upserts courses (bolt 024) and reads an optional `course_slug` on every vocab and category entry, defaulting to English to Amharic. Skills, lessons and exercises reach their course through their category, so new content is data only.
- Exercise shapes and validators are unchanged from bolt 022: `multiple_choice` (choices + correct id), `listening` (audio url + choices + correct id), `sentence_construction` (word bank + correct sequence), `match_pairs` (left/right tiles + correct pairs). Word banks are whitespace-separated tiles, so Latin and Fidel both work.
- Vocab is now per course, so each new course gets its own vocab items (`word` is the learning-language word, `translation` the from-language word).
- Three existing seed tests assume one course and must be adjusted, not deleted: the row counts (5 categories, 10 skills, 20 lessons, 89 exercises, 40 vocab), the "content has Ethiopic script" check (Afaan Oromo is Latin script), and category/vocab totals in the end-to-end test. They will be scoped to the English to Amharic course, and new tests cover the new courses.
- Audio: every listening exercise keeps the single placeholder MP3, as before.
- No native-speaker review is possible here (NFR-3). See the confidence list at the end.

### Deliverables

- A new data module `seed_course_content.py` holding the three courses, their category, skills, lessons, exercises and vocab, built from one shared word list by small builders, so the three directions cannot drift.
- `seed_lesson_content.py` appends them to its `COURSES`/`CATEGORIES`/`CURRICULUM`/`VOCABULARY` lists.
- Totals added: 3 courses, 3 categories, 6 skills, 12 lessons, 51 exercises (4 per lesson, plus a match-pairs in the second lesson of each skill), 48 vocab items (one per vocab-linked multiple-choice exercise, per course).
- Existing tests adjusted as above; new structure, content and idempotency tests.
- The content seeded into `backend/dev.db` (backed up first) and checked through the real API for all three source languages.

### Content (full list for review)

Amharic and Afaan Oromo are authored by me and are NOT native-speaker reviewed. All three courses teach the same 16 words in the same 4 lessons; only the language of prompts and answers differs.

**The 16 words (English / Amharic / Afaan Oromo)**

Skill 1: Greetings & Basics
- Lesson 1, "Hello & Goodbye":
  - hello / ሰላም / Akkam
  - goodbye / ደህና ሁን / Nagaatti
  - thank you / አመሰግናለሁ / Galatoomi
  - please / እባክዎ / Maaloo
- Lesson 2, "Yes, No & Friends":
  - yes / አዎ / Eeyyee
  - no / አይ / Lakki
  - good / ጥሩ / Gaarii
  - friend / ጓደኛ / Hiriyaa

Skill 2: Food & Drink
- Lesson 3, "Coffee, Tea & Water":
  - coffee / ቡና / Buna
  - tea / ሻይ / Shaayii
  - water / ውሃ / Bishaan
  - milk / ወተት / Aannan
- Lesson 4, "Bread & Food":
  - bread / ዳቦ / Daabboo
  - food / ምግብ / Nyaata
  - meat / ስጋ / Foon
  - egg / እንቁላል / Hanqaaquu

**Every lesson** has 4 exercises, in this order: 1) multiple choice, from-language to learning language (vocab-linked, the first word); 2) multiple choice, learning language to from-language (vocab-linked, the second word); 3) listening on the third word (plays the placeholder audio, asks what it means); 4) sentence building. The second lesson of each skill (lessons 2 and 4) also has a 5th exercise, a match-pairs of its four words. So each course has 2 match-pairs exercises and 4 lessons with at least 3 exercise types.

**Sentence-building exercises** (the answer is in the learning language; the bank adds two distractor tiles from the same lesson)
- Lesson 1: "Thank you, goodbye". Afaan Oromo: Galatoomi nagaatti. Amharic: አመሰግናለሁ ደህና ሁን.
- Lesson 2: "Hello, friend". Afaan Oromo: Akkam hiriyaa. Amharic: ሰላም ጓደኛ.
- Lesson 3: "Coffee, please". Afaan Oromo: Buna maaloo. Amharic: ቡና እባክዎ.
- Lesson 4: "I want bread". Afaan Oromo: Daabboo nan barbaada. Amharic: ዳቦ እፈልጋለሁ.
- The prompt is the same sentence in the from-language (English, Amharic, or Afaan Oromo). Distractors are other words of that lesson.

**The three courses**
- English to Afaan Oromo (learn Afaan Oromo from English): prompts in English, answers in Afaan Oromo (Latin script). Prompt wording as in bolt 022: "How do you say 'Hello' in Afaan Oromo?", "What does 'Akkam' mean?", "What does this word mean?", "Translate: '...'", "Match each word to its meaning".
- Amharic to Afaan Oromo (learn Afaan Oromo from Amharic): prompts in Amharic (Fidel), answers in Afaan Oromo. Wording: "'ሰላም' በኦሮምኛ እንዴት ይባላል?", "'Akkam' ምን ማለት ነው?", "ይህ ቃል ምን ማለት ነው?", "ተርጉም፦ '...'", "እያንዳንዱን ቃል ከትርጉሙ ጋር አዛምድ".
- Afaan Oromo to Amharic (learn Amharic from Afaan Oromo): prompts in Afaan Oromo, answers in Amharic (Fidel). Wording: "Afaan Amaaraatiin 'Akkam' akkamitti jedhama?", "'ሰላም' maal jechuudha?", "Jechi kun maal jechuudha?", "Hiiki: '...'", "Jechoota hiikaa isaanii waliin wal simsiisi".

**Names**
- Courses: "English to Afaan Oromo", "Amharic to Afaan Oromo", "Afaan Oromo to Amharic" (order 2, 3, 4 after English to Amharic).
- One category each, "Foundations & Greetings", with a subtitle in the language being learned: Afaan Oromo courses "Nagaa fi jalqaba"; Amharic course "ሰላምታ እና መሠረታዊ ቃላት".
- Skills "Greetings & Basics" and "Food & Drink"; lesson titles in English as listed above (the app interface stays English).

**Lower-confidence items to check first with a native speaker**
- Afaan Oromo: Akkam as "hello", Nagaatti as "goodbye", Galatoomi (thank you, and its gender/number form), Daabboo as "bread" (Buddeena is another word), Hanqaaquu (egg), Aannan (milk), "nan barbaada" (I want), and the category subtitle "Nagaa fi jalqaba".
- All Afaan Oromo prompt wording: "Afaan Amaaraatiin ... akkamitti jedhama?", "maal jechuudha?", "Hiiki:", "wal simsiisi".
- Amharic prompt wording for the Amharic-to-Afaan-Oromo course: "በኦሮምኛ እንዴት ይባላል?", "ተርጉም፦", "አዛምድ", and the subtitle.
- Word order in the one-line sentences (Buna maaloo, Akkam hiriyaa).

### Dependencies

- Bolt 024 (complete): courses table, per-course categories and vocab, seed support for `course_slug`.
- The existing seed helpers and content tests.

### Technical Approach

- Build the data from one shared 16-word list plus per-language tables (word, prompt wording, sentence, distractors), expanded into the standard exercise shapes by builders in the new module; deterministic slugs that include the course, so re-runs update in place and never collide with existing content.
- Each course: category order 1 (unique per course), skills 1 and 2, lessons 1 and 2, exercise order 1 to 5.
- Update the three existing tests to scope to English to Amharic; add tests for structure, script (each course's answers are in the right script and prompts in the from-language's script), links, uniqueness, idempotency, and row counts across all four courses.
- Back up `dev.db`, run the seed, and check the tree, a lesson and Practice-related data for a user on each new course through the real API.

### Acceptance Criteria

- [ ] Three available courses seeded: English to Afaan Oromo, Amharic to Afaan Oromo, Afaan Oromo to Amharic
- [ ] Each has 1 category, 2 skills, each skill 2 lessons, each lesson at least 4 exercises from at least 3 types, and at least one match-pairs
- [ ] Prompts are in the from-language and answers in the learning language, in the correct script
- [ ] Vocab-linked multiple-choice exercises resolve to that course's own vocab items
- [ ] Re-running the seed creates nothing new
- [ ] All answer keys, sequences and pair ids pass the structural checks
- [ ] Existing tests pass, with only the three course-scoping adjustments
- [ ] dev.db seeded and verified through the API for each course
- [ ] The not-native-reviewed caveat is recorded in the walkthrough
