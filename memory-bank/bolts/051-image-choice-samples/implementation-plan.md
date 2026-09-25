---
stage: plan
bolt: 051-image-choice-samples
created: '2026-09-25T11:37:52Z'
---

## Implementation Plan: image-choice-service (sample picture questions)

### Objective

Give both picture question types real sample content in the English to
Amharic course: free-licensed pictures, shrunk and committed with a
credits file, and a local-only seed that adds 3 `image_choice` and 2
`audio_image_choice` questions, each linked to its own vocabulary word so
practice shows it. Nothing goes to Neon or production R2.

### Decisions

- **D1: The picture set is OpenMoji, release 17.0.0, licensed CC BY-SA 4.0.**
  - It offers 618 px colour PNGs, which Pillow can shrink straight to
    512 px WebP. Twemoji's PNGs are only 72 px, and its SVGs would need a
    rasteriser (cairo) that is hard to install on Windows. Wikimedia
    Commons pictures vary in style and licence from file to file.
  - `openmoji.json` in the same release names each picture's designer, so
    each credit names a real author, not only "OpenMoji".
  - Share-alike covers the shrunk files themselves, which stay CC BY-SA
    4.0. The credits file says what was changed.
  - The release is pinned, so re-running the build gives the same files.
- **D2: The sample words.** Five new vocabulary words, none of them in any
  seed today:

  | Type | Word | Meaning | Picture (OpenMoji) |
  |---|---|---|---|
  | `image_choice` | ውሃ | Water | droplet `1F4A7` |
  | `image_choice` | ውሻ | Dog | dog `1F415` |
  | `image_choice` | ቤት | House | house `1F3E0` |
  | `audio_image_choice` | አንድ | One | keycap 1 |
  | `audio_image_choice` | አስር | Ten | keycap 10 |

  - Distractor pictures: cat `1F408`, sun `2600`, and keycaps 2 and 5.
    That is 9 pictures in all, each credited.
  - Each `image_choice` shows 4 pictures from water, dog, house, cat and
    sun. Each `audio_image_choice` shows the keycaps 1, 2, 5 and 10. The
    right answer moves one place per question, as in the Audio Lab.
  - The audio questions reuse the Audio Lab's recordings, `am/one.m4a`
    and `am/ten.m4a`. Those clips are git-ignored and exist only on this
    machine; on a fresh clone the questions still seed, but their clip is
    missing until it is recorded again.
- **D3: The words shown.**
  - `image_choice` prompt: `Choose the picture: 'ውሃ'`. This is the
    `Instruction: 'word'` form the app already splits.
  - `audio_image_choice` prompt: `Tap the picture you hear`.
  - Alt text describes the picture in English, for example "A drop of
    water" or "The number 10".
- **D4: Where the files live.**
  - The pictures and the credits file go in a new tracked folder,
    `backend/sample_pictures/`, since `backend/media` is git-ignored.
  - The seed copies them into `backend/media/images/samples/`, where the
    backend already serves them as `/media/images/samples/<file>`. Those
    paths pass bolt 050's local-media rule. The copy runs every time,
    overwriting, so a rebuilt picture reaches `media`.
- **D5: The credits file is JSON, `backend/sample_pictures/credits.json`,
  for bolt 054 to bundle into the app.** It holds one entry per picture:
  - `file`
  - `subject`
  - `author`
  - `source` ("OpenMoji")
  - `source_url`, the picture's page on openmoji.org
  - `licence` ("CC BY-SA 4.0")
  - `licence_url`
  - `changes` ("Resized to 512 px and converted to WebP")

  Adding a picture means adding an entry; the app will list it with no
  code change.
- **D6: The pictures are built by a committed script.**
  `backend/scripts/build_sample_pictures.py` downloads each PNG and
  `openmoji.json` from the pinned release. It shrinks each picture to
  512 px, writes WebP at quality 80, and rewrites `credits.json`.
  - It runs with `uv run --with pillow`, so Pillow is **not** added to
    the backend's dependencies.
  - It is run once here, and the output is committed. Tests check the
    committed files without Pillow, by reading the WebP header for the
    picture's size.
- **D7: The seed, `seed_local_pictures.py`, copies `seed_local_audio.py`:**
  - It is insert-only, through `seed_content`, with the five vocabulary
    words.
  - It refuses any database but SQLite.
  - It puts a "Picture Lab" section at the top of English to Amharic.
    Audio Lab already holds position 0, and positions are unique within a
    course, so Picture Lab takes -1.
  - It has one skill, "Pictures", with one lesson, "First Pictures".
  - Every question is checked by `validate_exercise` with local media
    allowed.
- **D8: Local `dev.db`.** I'll back it up, then run the main seed, the
  audio seed and the picture seed against it, so the samples can be seen
  in the admin site and the app. Neon and production R2 are not touched.

### Deliverables

- `backend/scripts/build_sample_pictures.py`
- `backend/sample_pictures/`: 9 WebP pictures and `credits.json`
- `backend/app/infrastructure/db/seed_local_pictures.py`
- `backend/tests/integration/test_seed_local_pictures.py`
- A line in `database-schema.md` or the README naming the seed, beside the
  audio seed's line if it has one
- Local `dev.db`: backed up, then seeded

### Dependencies

- Bolt 050: the two types, local media URLs and the images folder.
- OpenMoji 17.0.0, fetched only when the build script runs.
- Pillow, only through `uv run --with pillow`, only for the build script.

### Out of Scope

- Seeding the other three courses.
- Neon, production R2 and R2 CORS.
- Showing the credits in the app (bolt 054).

### Acceptance Criteria

- [ ] Every picture is CC0, CC BY or CC BY-SA. Its source URL, author and
      licence are in `credits.json`, and the distractors are credited too.
- [ ] Every picture is WebP, at most 512 px on its longest side, and at
      most 300 KB.
- [ ] The pictures and `credits.json` are in a tracked folder, and git
      does not ignore them.
- [ ] On SQLite the seed adds 3 `image_choice` and 2 `audio_image_choice`
      questions to English to Amharic, and copies the pictures to
      `backend/media/images/samples/`.
- [ ] Every sample question passes `validate_exercise` with local media
      allowed. The correct picture matches the word, and every picture
      address has a file in `media`.
- [ ] Each question is linked to its own new vocabulary word, which has no
      other question. `GET /practice/due-items` returns it.
- [ ] Re-running adds nothing twice. Any database but SQLite is refused.
- [ ] Every picture in the seed is in `credits.json`, and every entry in
      `credits.json` is used.
- [ ] Nothing is uploaded to R2 or written to Neon.
- [ ] Every existing backend test still passes; the baseline is 1225.
      `ruff` is clean, and `mypy` adds no errors to its 4 existing ones.

### Test Plan

**`test_seed_local_pictures.py`**
- **The files:**
  - Each picture is a real WebP, read from its header, at most 512 px and
    300 KB.
  - `credits.json` has every field, an allowed licence, and https URLs.
  - The pictures and the credits match one to one.
  - `git check-ignore` does not ignore the folder.
- **The seed:**
  - It adds the questions, with the counts, types and validation above.
  - It copies the pictures, and each question's answer is the right
    picture.
  - Each question has its vocabulary link, and practice returns the
    question.
  - Running it twice changes nothing.
  - It refuses any database but SQLite.
  - The section comes first in the course.
