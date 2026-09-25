---
stage: test
bolt: 051-image-choice-samples
created: '2026-09-25T13:20:00Z'
---

## Test Report: image-choice-service (sample picture questions)

### Summary

- **Tests:** all 1261 backend tests pass.
  - 1225 before the bolt, plus 36 new ones.
  - No existing test changed.
- **Coverage:** not measured.
- **Mutation check:** 9 deliberate breakages of the seed.
  - The first run caught 8.
  - The miss was closed with a new test, and all 9 are now caught.
  - Each file was checked to be restored exactly after its run.
- **`ruff check` and `ruff format`:** clean.
- **`mypy`:** the same 4 errors as before, none in the new code.

### Test Files

- [x] `backend/tests/integration/test_seed_local_pictures.py` (36, new)
  - **The pictures:**
    - Each is a real WebP, at most 512 px and 300 KB. The size is read
      from the WebP header, so no image library is needed.
    - The header reader itself is checked on all three kinds of WebP
      header, and it refuses a PNG.
    - The folder holds only the pictures and `credits.json`.
    - `git check-ignore` confirms git tracks every file.
  - **The credits:**
    - Every entry has every field.
    - Every licence is CC0, CC BY or CC BY-SA, with a Creative Commons
      link and an https source.
    - Each picture is credited exactly once.
    - Every picture a question shows is credited, distractors included,
      and every credit is used.
  - **The questions:**
    - There are 3 image choice and 2 audio image choice questions.
    - Each passes `validate_exercise` with local media allowed.
    - Each word's answer is its picture. The table of words and pictures
      is written into the test, not read from the seed.
    - The prompts are right.
    - The audio questions use the Audio Lab's clips.
    - The right answer moves from question to question.
    - Each question has its own new word, none of them in the main seed.
  - **Copying:** every picture lands where its address points, and a
    stale copy is overwritten.
  - **Seeding into SQLite:**
    - The rows match the source.
    - Each word belongs to English to Amharic and has exactly one
      question.
    - Picture Lab comes first in the course.
    - Running the seed twice changes nothing.
    - The seed refuses a Neon address before copying anything.
  - **Practice:** with all five words due, `GET /practice/due-items`
    returns each word with its picture question and pictures.

### Acceptance Criteria Validation

- ✅ **The pictures are free-licensed and credited:** CC BY-SA 4.0, and
  `credits.json` records the source URL, author and licence of each,
  distractors included. Covered by the credits tests.
- ✅ **Size and format:** 512 px or less, WebP, 300 KB or less. In
  practice they are 512×512 and 2 to 17 KB. Covered by the picture tests.
- ✅ **The pictures are in a tracked folder:** `backend/sample_pictures/`.
  Covered by the git test.
- ✅ **The seed adds at least 3 image choice and 2 audio image choice
  questions, and copies the pictures:** covered by the question, seeding
  and copying tests.
- ✅ **Each question has its own word, and practice shows it:** covered by
  the word and practice tests.
- ✅ **The seed never adds anything twice, and refuses anything but
  SQLite:** covered by the seeding tests.
- ✅ **Nothing reached R2 or Neon:** only local `dev.db` and
  `backend/media` were written.

### Issues Found

**One bug in the seed, found by the new tests and fixed:**
- The sun picture was credited but no question showed it.
  - The cause: each question's wrong pictures were taken from the start
    of the list, so the last one was never reached.
  - The fix: the wrong pictures now rotate through the list, so every
    picture appears somewhere.
  - The local `dev.db` had already been seeded with the old rows, so I
    backed it up again to `dev.db.bak-20260925T122928Z` and deleted the
    5 Picture Lab questions. No other table referred to them. Then I
    re-seeded. It still holds 186 exercises.

**One gap in the tests, found by the mutation check and closed:**
- Pairing "ten" with the wrong picture went unnoticed, because the test
  compared the seed with itself.
- A new test now lists each word's correct picture itself.

### Notes

- **The dev.db backups are not to be committed:**
  - `dev.db.bak-20260925T121153Z`, taken before the first seed
  - `dev.db.bak-20260925T122928Z`, taken before the fix
- **The build script is not run by the tests.** It needs the network and
  Pillow. The tests check its committed output instead.
