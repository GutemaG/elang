---
stage: implement
bolt: 051-image-choice-samples
created: '2026-09-25T12:25:00Z'
---

## Implementation Walkthrough: image-choice-service (sample picture questions)

### Summary

Nine OpenMoji pictures are built, shrunk to 512 px WebP and committed with
a credits file. A new local-only seed adds a "Picture Lab" section to
English to Amharic, with 3 image choice and 2 audio image choice
questions. Each question is linked to its own new vocabulary word. The
local `dev.db` is seeded, and Neon and R2 are untouched.

### Structure Overview

- A committed build script turns the pinned OpenMoji release into the
  files in `backend/sample_pictures/`.
- The seed module copies those files into the git-ignored media folder,
  where the local backend already serves them.
- It then inserts the section through the existing insert-only
  `seed_content`, like the Audio Lab seed.

### Completed Work

- [x] `backend/scripts/build_sample_pictures.py`:
  - It downloads each picture and `openmoji.json` from OpenMoji 17.0.0.
  - It shrinks the pictures to 512 px WebP at quality 80, and refuses any
    over 300 KB.
  - It rewrites `credits.json` with each designer's name.
  - Pillow is used only through `uv run --with pillow`.
- [x] `backend/sample_pictures/`:
  - The 9 pictures, each 512×512 and 2 to 17 KB: water, dog, house, cat,
    sun, and the numbers 1, 2, 5 and 10.
  - `credits.json`, which lists each picture's file, subject, author,
    source, source URL, licence, licence URL and changes.
- [x] `backend/app/infrastructure/db/seed_local_pictures.py`: the Picture
  Lab seed.
  - It adds 5 vocabulary words, one section at position -1, one skill and
    one lesson.
  - It copies the pictures to `media/images/samples/` on every run.
  - It refuses any database but SQLite.
- [x] Local `backend/dev.db`: backed up to `dev.db.bak-20260925T121153Z`,
  then seeded. It went from 181 to 186 exercises. Neither file is
  tracked.

### Key Decisions

- **Authors come from OpenMoji's own data.** Each credit names the
  picture's designer (Vanessa Boutzikoudi, Sofie Ascherl, Martin Wehl,
  Selina Lange), not only the project.
- **The build script's list and the seed's alt text are separate.** The
  script says what to fetch, and the seed says how each picture is
  described. A test will check that both agree with `credits.json`.
- **Answers rotate** a, b, c, d, a across the five questions, as in the
  Audio Lab, so the right picture is not always first.
- **Every sample question passes `validate_exercise`** with local media
  allowed. I checked this by hand; a test will follow.

### Deviations from Plan

- The plan offered a line in `database-schema.md` or the README beside
  the audio seed's. Neither file mentions the audio seed, so the module
  docstring is the only documentation, as it is for the audio seed.

### Dependencies Added

- None. Pillow is used only when the build script runs, and is not added
  to `pyproject.toml`.

### Developer Notes

- To rebuild, run
  `uv run --with pillow python scripts/build_sample_pictures.py` from
  `backend/`. It overwrites the files; commit whatever changes.
- The audio questions play `am/one.m4a` and `am/ten.m4a`, which are
  git-ignored. On another machine the questions seed, but have no sound
  until those clips are recorded again.
- **Checks:**
  - The full backend suite passes (1225) with the new module in place.
  - `ruff` is clean.
  - `mypy` shows its same 4 errors as before.
