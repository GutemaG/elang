---
stage: plan
bolt: 022-category-content-seed
created: '2026-09-19T22:45:00Z'
---

## Implementation Plan: category-content-seed

### Objective

Extend the idempotent seed with four new categories of real Amharic content (Family & People, Numbers & Time, Travel & Places, Colors/Body & Health), each with 2 skills x 2 lessons, and load it into the dev database, so the dashboard has five categories to work with.

### Real-Source Findings (re-read at Plan stage)

- The seed is one script (`seed_lesson_content.py`): a `VOCABULARY` list, a `CURRICULUM` list (skill -> lessons -> exercises) and, since bolt 021, a `CATEGORIES` list plus a `category_slug` on each skill. Every row id is a deterministic uuid5 of a slug, and each run inserts or updates in place, never deleting. New content only needs new data entries; the `seed()` loop already handles categories, skills, lessons, exercises and vocab links.
- Exercise shapes (from the seed and the repository mapping): `multiple_choice` = `choices` + `correct_choice_id`; `listening` = `audio_url` + `choices` + `correct_choice_id`; `sentence_construction` = `word_bank` + `correct_sequence` (tile ids in order); `match_pairs` = `left_tiles` + `right_tiles` + `correct_pairs` (`[left_id, right_id]`). Vocab is linked per exercise via `vocab_slug`; only single-word multiple-choice exercises link.
- Existing tests constrain the content: every lesson must contain `multiple_choice`, `listening` AND `sentence_construction`; content must be real Amharic with no placeholder text; every listening `audio_url` must start with the documented placeholder host; at least one `match_pairs` exists and is well-formed.
- One existing test will break and must be updated: the "edit content updates in place" test selects `SkillModel.order_index == 1` and expects exactly one row. With per-category ordering (ADR-11) there will be five skills at order 1, so it must select by the seeded skill's id instead.
- Audio: still the single placeholder MP3 for every listening exercise (documented limitation carried from the original seed); this bolt does not change that.

### Deliverables

- Four new entries in `CATEGORIES` (order 2 to 5) and eight new skills, sixteen lessons, seventy-two exercises in `CURRICULUM`, plus thirty-two new entries in `VOCABULARY` (one per vocab-linked multiple-choice exercise).
- Every lesson: 2 multiple_choice (vocab-linked) + 1 listening + 1 sentence_construction. The second lesson of every skill also gets a 5th exercise, a match_pairs, giving each category two.
- The one existing test updated; new tests for structure and content integrity across the whole seed.
- The content loaded into `backend/dev.db` (backed up first), verified through the real API.

### Content (full list for review)

Amharic is authored by me and is NOT native-speaker reviewed (NFR-3). Multiple-choice exercises alternate direction: the first asks "How do you say 'X' in Amharic?" (Amharic choices), the second "What does 'Y' mean?" (English choices). Listening exercises play the placeholder audio and ask what the word means.

**Category 2: Family & People (ቤተሰብ እና ሰዎች)**
- Skill "My Family":
  - Lesson "Mother & Father": እናት mother, አባት father, ወንድም brother, እህት sister. MC: እናት, አባት. Listening: ወንድም. Sentence "I have a brother": ወንድም አለኝ.
  - Lesson "Husband, Wife & Child": ባል husband, ሚስት wife, ልጅ child, አያት grandparent. MC: ባል, ሚስት. Listening: ልጅ. Sentence "I have a child": ልጅ አለኝ. Match: all four.
- Skill "People":
  - Lesson "Friends & Teachers": ጓደኛ friend, ጎረቤት neighbor, መምህር teacher, ሰው person. MC: ጓደኛ, መምህር. Listening: ጎረቤት. Sentence "He is a teacher": እሱ መምህር ነው.
  - Lesson "I, You, He, She": እኔ I, አንተ you (m.), እሱ he, እሷ she. MC: እኔ, እሷ. Listening: እሱ. Sentence "I am a teacher": እኔ መምህር ነኝ. Match: all four.

**Category 3: Numbers & Time (ቁጥሮች እና ጊዜ)**
- Skill "Numbers":
  - Lesson "One to Five": አንድ 1, ሁለት 2, ሦስት 3, አራት 4, አምስት 5. MC: አንድ, ሦስት. Listening: አራት. Sentence "Two teas, please": ሁለት ሻይ እባክዎ.
  - Lesson "Six to Ten": ስድስት 6, ሰባት 7, ስምንት 8, ዘጠኝ 9, አሥር 10. MC: ስድስት, ስምንት. Listening: አሥር. Sentence "Five breads, please": አምስት ዳቦ እባክዎ. Match: 6, 7, 9, 10.
- Skill "Time":
  - Lesson "Today & Tomorrow": ዛሬ today, ነገ tomorrow, ትናንት yesterday, ጠዋት morning, ማታ evening. MC: ዛሬ, ነገ. Listening: ትናንት. Sentence "See you tomorrow": ነገ እንገናኛለን.
  - Lesson "Days of the Week": ሰኞ Monday, ማክሰኞ Tuesday, ረቡዕ Wednesday, ሐሙስ Thursday, አርብ Friday, ቅዳሜ Saturday, እሑድ Sunday. MC: ሰኞ, አርብ. Listening: እሑድ. Sentence "Today is Monday": ዛሬ ሰኞ ነው. Match: Monday, Wednesday, Saturday, Sunday.

**Category 4: Travel & Places (ጉዞ እና ቦታዎች)**
- Skill "Around Town":
  - Lesson "Places": ቤት home, ገበያ market, ሆቴል hotel, ትምህርት ቤት school. MC: ገበያ, ሆቴል. Listening: ትምህርት ቤት. Sentence "I want a hotel": ሆቴል እፈልጋለሁ.
  - Lesson "Directions": ቀኝ right, ግራ left, ቀጥታ straight, እዚህ here. MC: ቀኝ, ግራ. Listening: ቀጥታ. Sentence "Go straight": ቀጥታ ሂድ. Match: all four.
- Skill "Getting There":
  - Lesson "Asking Questions": የት where, ምን what, መቼ when, ስንት how much. MC: የት, ስንት. Listening: መቼ. Sentence "How much is it?": ስንት ነው.
  - Lesson "Transport": መኪና car, አውቶቡስ bus, ታክሲ taxi, አውሮፕላን airplane. MC: አውቶቡስ, ታክሲ. Listening: አውሮፕላን. Sentence "Where is the bus?": አውቶቡስ የት ነው. Match: all four.

**Category 5: Colors, Body & Health (ቀለሞች፣ አካል እና ጤና)**
- Skill "Colors":
  - Lesson "Basic Colors": ቀይ red, ሰማያዊ blue, አረንጓዴ green, ቢጫ yellow. MC: ቀይ, ሰማያዊ. Listening: አረንጓዴ. Sentence "It is red": ቀይ ነው.
  - Lesson "More Colors": ነጭ white, ጥቁር black, ብርቱካናማ orange, ሐምራዊ purple. MC: ነጭ, ጥቁር. Listening: ብርቱካናማ. Sentence "The bread is white": ዳቦው ነጭ ነው. Match: all four.
- Skill "Body & Health":
  - Lesson "Body": ራስ head, እጅ hand, እግር foot, ዓይን eye, ጆሮ ear. MC: ራስ, እጅ. Listening: ዓይን. Sentence "My head hurts": ራሴን ያመኛል.
  - Lesson "Health": ሐኪም doctor, መድኃኒት medicine, ህመም pain, ውሃ water. MC: ሐኪም, መድኃኒት. Listening: ህመም. Sentence "I need a doctor": ሐኪም እፈልጋለሁ. Match: all four.

Word banks for sentence exercises hold the correct tiles plus two distractors drawn from the same lesson. Wrong choices in multiple-choice are other words from the same category.

**Lower-confidence items to check first with a native speaker:** ሐምራዊ (purple), ብርቱካናማ (orange, the colour), ትናንት (yesterday), ህመም (pain; also spelled ሕመም), ቀጥታ ሂድ (go straight), ራሴን ያመኛል (my head hurts), ነገ እንገናኛለን (see you tomorrow), ዳቦው ነጭ ነው (the bread is white), and the agreement forms ነኝ / ነው / ናት.

### Dependencies

- Bolt 021 (complete): the `categories` table, `skills.category_id`, per-category ordering, and the seed loop that upserts categories.
- The existing seed helpers and content validation tests.

### Technical Approach

- Add data only: new `VOCABULARY`, `CATEGORIES` and `CURRICULUM` entries using small local helper functions to build exercises from the compact lesson definitions above, so each lesson is a few lines and the shapes cannot drift. Deterministic slugs so re-runs update in place.
- Skill `order_index` 1 and 2 within each category; lesson `order_index` 1 and 2 within each skill; exercise order 1 to 5.
- Update the one order-index-based seed test; add tests: five categories seeded; each new category has 2 skills, each with 2 lessons; each lesson has at least 4 exercises and at least the three required types; each category has at least one match_pairs; every multiple_choice/listening correct id exists in its choices; every sentence sequence uses only word-bank ids; every match-pair id exists on the correct side; vocab links resolve and are unique per exercise; no duplicate slugs.
- Backup `dev.db`, run the seed against it, verify through the real API for a new user (five banners' worth of categories, one active skill each).

### Acceptance Criteria

- [ ] Four new categories with 2 skills x 2 lessons each; every lesson has at least 4 exercises from at least 3 types
- [ ] Each new category has at least one match_pairs exercise
- [ ] Vocab-linked multiple-choice exercises resolve to new vocab items
- [ ] Re-running the seed creates no duplicates
- [ ] All answer keys, sequences and pair ids pass the structural checks
- [ ] Existing tests still pass, with only the order-index test adjusted
- [ ] dev.db seeded and verified through the API
- [ ] The not-native-reviewed caveat is recorded in the walkthrough
