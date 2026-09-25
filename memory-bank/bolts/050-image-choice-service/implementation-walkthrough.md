---
stage: implement
bolt: 050-image-choice-service
created: '2026-09-25T08:20:00Z'
---

## Implementation Walkthrough: image-choice-service (content types and upload links)

### Summary

The backend now stores, checks and serves `image_choice` and
`audio_image_choice` questions, and the local database accepts them. Admins
can get a short-lived upload link for a picture. In local development the
picture is saved by the backend and served from `/media/images/`; with R2
set up it goes to the same bucket as the audio.

### Structure Overview

- **One dispatch on type, as before.** The new types were added at each
  place that already branches on type: domain objects, JSON reading and
  checking, the check constraint, and the response mapping. Each of those
  places still ends by refusing an unknown type.
- **Pictures are uploaded the way audio is.** A use case checks the request
  and builds the key. The chosen store signs a PUT link. For the local
  store, a receiving route checks the signature and saves the file.
- **The local store now serves one kind of file per instance.** Audio
  behaves exactly as before, and pictures are the second kind.

### Completed Work

- [x] `backend/app/domain/lesson/value_objects.py`:
  - the two new types
  - a picture choice (id, address, description)
  - the two content objects, which enforce 2 to 4 pictures
  - comments on the answer-key union updated for eight types
- [x] `backend/app/domain/lesson/exercise_parts.py`:
  - reads both types from JSON
  - checks the pictures field by field
  - allows local picture paths only in local development
  - applies the listening audio rule to the new audio type
  - lets the correct answer name a picture
- [x] `backend/app/infrastructure/db/lesson_models.py`: the type constraint
      allows eight types.
- [x] `backend/app/infrastructure/db/migrations/versions/b5e9d2c7a4f1_add_image_choice_types_to_exercises_type_check.py`:
      widens the constraint and narrows it again on downgrade.
- [x] `backend/app/infrastructure/api/lesson_schemas.py`: responses for a
      picture choice and for both new types, added to the union the
      lesson and practice APIs return.
- [x] `backend/app/infrastructure/api/exercise_mapping.py`: maps both
      types to their responses.
- [x] `backend/app/application/admin_image_use_cases.py` (new): checks the
      picture type, size and lesson, builds the key, asks the store for a
      link, and logs the request.
- [x] `backend/app/infrastructure/api/admin_routers.py`:
      `POST /admin/images/uploads`, a picture store you can swap out in
      tests, and the audio status now also shown for
      `audio_image_choice`.
- [x] `backend/app/infrastructure/api/admin_schemas.py`: the picture
      upload request and response, the same shape as audio's.
- [x] `backend/app/infrastructure/external/local_audio_storage.py`:
  - a media-kind setting for the store: audio as before, or pictures
  - the kind is part of each signature
  - a key pattern for pictures
  - a store chooser for pictures
- [x] `backend/app/infrastructure/api/audio_file_routers.py`:
      `PUT /api/v1/image-files/{key}` beside the audio route, sharing its
      checks, with the picture size limit.
- [x] `backend/app/infrastructure/media.py`: the pictures folder and its
      URL prefix.
- [x] `backend/app/main.py`: registers the picture upload route.
- [x] `database-schema.md`: the eight types, the two new content shapes,
      and what `prompt` means for them.
- [x] **Existing tests changed only to add the new types to their lists:**
  - The type-dispatch and validation tests gain a sample for each new
    type.
  - The check that the main seed covers every type now leaves out the two
    picture types. They are seeded only locally by bolt 051, until their
    pictures are on R2.
- [x] `backend/tests/integration/test_image_choice_migration.py` (new):
      holds the "one migration head" check, which moved here from the
      email migration's tests because it always pins the newest head.
      The migration's own tests are added at Test.
- [x] **Local `dev.db`:** backed up to
      `backend/dev.db.bak-20260925T081216Z`, then upgraded to
      `b5e9d2c7a4f1`. It still holds its 181 exercises.

### Key Decisions

- **The question text is the exercise's existing `prompt` (D1).**
- **The local store kept its name.** The audio store gained a media-kind
  setting instead of being renamed. As a result, every audio test and
  route passes without a change.
- **The folder is looked up when a store is made, not stored with the
  kind.** The first version kept it with the kind, and the audio upload
  tests failed: they point the audio folder at a temporary directory, and
  that setting was no longer read.
- **Different kinds sign differently.** An audio link cannot upload a
  picture, and the other way round.

### Deviations from Plan

- **The "one head" check moved** into the new migration test file. It was
  pinned to the previous migration, and was the only existing test the
  migration broke.
- **R2 CORS (D9):** this couldn't be fully checked.
  - The public r2.dev address answers every `OPTIONS` request with
    `403 This bucket cannot be viewed`, whatever the origin. It doesn't
    answer browser preflight checks.
  - A missing object answers `404` with no CORS headers.
  - A web app drawing a picture sends a plain `GET`, with no preflight.
    So the real test is a `GET` with an `Origin` header on an object that
    exists, and none is known without the R2 keys.
  - The CORS policy in the README allows the admin site and
    `localhost:5173`. It does not allow the Flutter web app's origin
    (`localhost:5000` locally, or wherever it is deployed).
  - The check is repeated once a picture is on R2 (bolt 051 or 053).
    Adding the web app's origin to the policy waits for the owner.

### Dependencies Added

- None.

### Developer Notes

- **Checks:**
  - The full backend suite passes: 1048 tests, up from 1037, all from the
    new type samples.
  - `ruff check` and `ruff format` are clean.
  - `mypy` shows the same 4 errors as before, none in changed code.
- **The user's backend on port 8000** wasn't running at the time. The new
  routes were confirmed in the app's OpenAPI schema instead.
- **Neon was not touched.** Production needs `b5e9d2c7a4f1` (and any
  earlier migration it lacks), and that waits for the owner's go-ahead.
