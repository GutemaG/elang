---
stage: plan
bolt: 050-image-choice-service
created: '2026-09-25T07:45:54Z'
---

## Implementation Plan: image-choice-service (content types and upload links)

### Objective

Add `image_choice` and `audio_image_choice` to the backend: stored,
validated field by field, returned by the lesson and practice APIs, and
allowed by the database. Give admins an upload link for pictures that works
like the audio one, with local storage in development. This is the
contract bolts 052 (admin site) and 053 (app) build against.

### Decisions

- **D1: The question text is the exercise's existing `prompt`.** Every
  exercise already has a top-level `prompt`. For `image_choice` it holds
  the word or question ("ቡና", or "Which one is 'coffee'?"). For
  `audio_image_choice` it holds the instruction ("Tap what you hear"), as
  it does for `listening`. So `content` holds no second prompt, and the
  admin site's prompt field and the app's prompt splitting work as they
  are.
- **D2: The JSON shape.**
  - `image_choice` content: `{"choices": [{"id", "image_url", "alt_text"}, ...]}`
  - `audio_image_choice` content: `{"audio_url", "choices": [same]}`
  - Answer key for both: `{"correct_choice_id"}`, the existing
    `ChoiceAnswerKey`.
  - The field is `image_url`, matching `audio_url`. The lesson API returns
    the same names.
- **D3: Domain objects.**
  - A new `PictureChoice(id, image_url, alt_text)`, beside `Choice`.
  - `ImageChoiceContent(choices)` and
    `AudioImageChoiceContent(audio_url, choices)`.
  - Named limits `MIN_PICTURE_CHOICES = 2` and `MAX_PICTURE_CHOICES = 4`,
    enforced in the content objects.
  - `ChoiceAnswerKey`'s cross-check accepts both new contents. There is no
    new `AnswerKey` member.
- **D4: Validation.** The same first-offending-field style as today.
  - The picture list gets its own check beside `_check_tiles`, because
    `choices` means a text tile for the other types.
  - Each picture choice has exactly `id`, `image_url` and `alt_text`.
  - The id is non-empty and not repeated.
  - Alt text is non-empty after trimming, and at most 200 characters.
  - `image_url` is a full https address. Where local media is allowed,
    it may also be a `/media/images/...` path.
  - The count must be 2 to 4, reported on `content.choices`.
  - `audio_url` follows the listening rule.
- **D5: Database.** A new migration after the current head
  `a7d3c9e1f042` widens `ck_exercises_type` with `batch_alter_table`, as
  the three before it did. The downgrade narrows it again, with the same
  caveat about existing rows. `ExerciseModel.__table_args__` and
  `database-schema.md` change with it. It runs on local SQLite only; Neon
  waits for your go-ahead.
- **D6: The upload link.**
  - `POST /api/v1/admin/images/uploads` takes `{lesson_id, content_type,
    size}` and returns `{upload_url, headers, key, public_url,
    expires_in}`. This is the same request and response as audio's, so the
    admin site reuses its upload code.
  - A new `admin_image_use_cases.py` allows `image/webp` (`.webp`) and
    `image/jpeg` (`.jpg`), 1 byte to 1 MB, with the audio link's 10
    minutes.
  - Keys are `{language}/{lesson_id}/{12 hex}.{ext}`. On R2 they share the
    audio bucket and layout; the extension tells them apart.
  - An audit log line is written for each link.
- **D7: Local storage in development.**
  - The local audio store becomes a local media store, set up per kind:
    - **Audio:** unchanged. The same folder, `/media/audio` prefix, PUT
      route, extensions and 5 MB limit, so existing links, files and tests
      keep working.
    - **Images:** `backend/media/images/`, served at `/media/images`,
      uploaded through `PUT /api/v1/image-files/{key}`, `webp` or `jpg`
      only, 1 MB.
  - The kind is part of the signature, so an audio link cannot be used to
    upload a picture, or the other way round.
  - `/media` is already served, so pictures need no new mount.
- **D8: The admin content tree** shows the audio status for
  `audio_image_choice` as well as `listening`.
- **D9: R2 CORS is checked, not changed.** I'll fetch an existing public
  object with an `Origin` header and record whether R2 answers with
  `Access-Control-Allow-Origin`. This needs no keys and writes nothing. If
  the answer is no, I'll describe the bucket setting and leave the change
  to you.

### Deliverables

- **Domain:**
  - `value_objects.py`: the two enum values, `PictureChoice` and the two
    content objects, added to the `ExerciseContent` union.
  - `exercise_parts.py`: JSON to domain for both types, the content-key
    table, the picture check, the URL rules and the cross-check.
- **Database:** `lesson_models.py` constraint, the new migration, and
  `database-schema.md`.
- **API:**
  - `lesson_schemas.py`: `PictureChoiceResponse`,
    `ImageChoiceExerciseResponse` and `AudioImageChoiceExerciseResponse`,
    added to the discriminated union.
  - `exercise_mapping.py`: both types, still ending in a `raise` for an
    unknown type.
- **Upload:**
  - `admin_image_use_cases.py`
  - `admin_routers.py`: the images route and the audio status
  - `admin_schemas.py`
  - `local_audio_storage.py`: made per-kind
  - `media.py`: the images folder and prefix
  - `audio_file_routers.py`: the image PUT route beside the audio one
- **Tests:** listed under Acceptance Criteria.

### Dependencies

- None outside this repository. R2's signing (`r2_storage.py`) is reused
  unchanged.

### Out of Scope

- The admin site (bolt 052), the app (bolt 053) and the sample content
  (bolt 051).
- Running anything against Neon or production R2.

### Acceptance Criteria

- [ ] An `image_choice` question with 2, 3 or 4 picture choices saves
      through the admin API, and the lesson API returns it unchanged
      (story 001).
- [ ] An `audio_image_choice` question with a clip and 2 to 4 choices saves
      and is returned (story 001).
- [ ] Each of these is refused with a `422` naming the field:
  - fewer than 2 or more than 4 choices
  - a repeated id
  - an empty or missing `image_url`, or a non-https one
  - `/media/images/...` outside local development
  - empty, blank or over-long `alt_text`
  - an extra or missing key in a choice
  - a missing `audio_url` on the audio type
  - an answer key naming no choice

  (story 001)
- [ ] The migration upgrades and downgrades on SQLite, and the model's
      constraint matches it (story 001).
- [ ] A word whose only question is a picture question is returned by
      `GET /practice/due-items` with that question (story 001).
- [ ] `POST /admin/images/uploads` returns a PUT link for `image/webp` or
      `image/jpeg` and 1 byte to 1 MB, valid for 10 minutes, with key
      `{language}/{lesson}/{hex}.webp|jpg` (story 002).
- [ ] It refuses other types, a size of 0 or over 1 MB, and an unknown
      lesson; non-admins are refused (story 002).
- [ ] In local development the picture is stored in
      `backend/media/images/` and served from `/media/images/...`. An audio
      link cannot upload a picture, and a picture link cannot upload audio
      (story 002).
- [ ] Every existing backend test still passes; the baseline is 1037.
      `ruff` passes, and `mypy` adds no errors to its 4 existing ones.
- [ ] The R2 CORS check is recorded (story 002).

### Test Plan

- **Unit:**
  - The content objects' limits.
  - A table of validation cases, one for each refusal above, each
    checking the field it names.
  - The type dispatch (`test_exercise_type_dispatch.py`), extended to
    eight types.
  - The image presign use case.
  - The local store: a signature per kind, and the image key pattern.
- **Integration:**
  - The admin create, read and update round trip for both types.
  - The lesson endpoint and practice due items.
  - The migration upgrading and downgrading.
  - `POST /admin/images/uploads`.
  - The local image PUT, served back from `/media/images`.
