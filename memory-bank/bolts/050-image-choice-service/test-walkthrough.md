---
stage: test
bolt: 050-image-choice-service
created: '2026-09-25T09:30:00Z'
---

## Test Report: image-choice-service (content types and upload links)

### Summary

- **Tests:** all 1225 backend tests pass.
  - 1037 before the bolt, then 11 from adding the new types to existing
    lists at Implement, then 177 new tests here.
- **Coverage:** not measured.
- **Mutation check:** 33 deliberate breakages of the new code:
  - validation
  - the content objects and response mapping
  - the model constraint and the migration
  - the upload use case
  - the local store and its route
  - the admin router

  The first run caught 32. The miss was closed with a new test, and now
  all 33 are caught. Each file was checked to be restored exactly after
  its run.
- **`ruff check` and `ruff format`:** clean. **`mypy`:** the same 4 errors
  as before, none in the new or changed code.

### Test Files

- [x] **`backend/tests/unit/test_picture_exercises.py` (116, new)**
  - **Content objects:**
    - 2, 3 and 4 pictures are allowed; 0, 1 and 5 are refused.
    - A picture needs an id, an address and a description that isn't
      blank.
    - The audio question needs a clip.
    - JSON is read as pictures, not as text tiles.
  - **Validation, for both types.** Each refusal names its field:
    - wrong counts, and choices that aren't a list
    - a repeated id
    - an empty, blank, non-text or missing id, address or description
    - an extra field, a text tile in place of a picture, and a picture
      that isn't an object
    - a description of exactly 200 characters saves; 201 is refused
    - non-https addresses
    - a local `/media/images/...` path, which saves only where local
      media is allowed; `/media/audio/...` and a bare `/media/images/`
      are never pictures
    - an answer naming no picture, and a sequence answer
    - an unknown content key
  - **The audio question's clip:** a missing, non-https or non-text clip
    is refused. A local clip saves only in local development.
    `image_choice` may not have a clip.
  - **Other types are unchanged:** a picture isn't accepted as a
    multiple-choice tile, and validation doesn't change its input.
  - **Local store:**
    - A picture link points at the picture route and folder.
    - A link signed for audio never verifies as a picture, and the other
      way round.
    - Picture keys are checked: the allowed extensions, `..`, extra
      folders and capitals.
    - Local development stores pictures in the images folder, and
      production has nowhere to store them.
- [x] **`backend/tests/integration/test_picture_exercises_api.py` (18, new)**
  - **Saving and serving:** with 2, 3 and 4 pictures, each type saves
    through the admin API. The lesson API returns exactly the saved
    pictures, prompt, clip and answer.
  - **Edits and the tree:** an edit to either type saves and reads back
    the same. The admin tree shows the clip status for the audio question
    and none for the plain one.
  - **Refusals over HTTP:** each case below is refused with a `422`
    naming the field:
    - too few pictures
    - too many pictures
    - a repeated id
    - a blank description
    - a missing address
    - a missing clip
    - a wrong answer
  - **Local pictures:** a question using them is refused in production,
    saves in local development, and is served with its `/media/images`
    path.
  - **Practice:** a due word whose only question is a picture question is
    returned by `GET /practice/due-items` with that question and its
    pictures.
- [x] **`backend/tests/integration/test_image_upload_endpoints.py` (39, new)**
  - **Links to R2:**
    - The key, public address, method, header, 10-minute expiry and
      signed headers are correct, and the secret never appears.
    - `.webp` or `.jpg` follows the type, and the type is normalised
      before signing.
    - PNG, GIF, SVG, audio, HTML and an empty type are refused.
    - Sizes of 0, -1, 1 MB + 1 and 5 MB are refused; 1 byte and exactly
      1 MB are allowed.
    - Each upload gets its own key.
    - An unknown lesson gets `404`; unconfigured storage gets `503`.
    - The log line names the picture's key and never the secret.
    - A learner is refused.
  - **Local flow:**
    - A picture uploads, saves under `media/images/`, and then loads from
      its address. JPEG is saved as `.jpg`.
    - Audio and pictures upload side by side.
    - A picture link used on the audio route is refused, and so is an
      audio link used on the picture route.
    - These are refused, and nothing is saved:
      - an altered signature
      - a different content type
      - a body of the wrong size
      - a forged link over 1 MB, which is never read past the limit
      - keys the backend never issues
    - A route wired to the wrong kind of store stays closed.
    - The route closes outside local development.
  - **App wiring:** the app registers both picture routes.
- [x] **`backend/tests/integration/test_image_choice_migration.py` (5, 4 new)**
  - The previous schema refuses both types.
  - Upgrading allows both, keeps existing rows, and still refuses a
    made-up type.
  - Downgrading narrows the check again.
  - There is still one migration head.
- [x] **Changed at Implement and passing:** `test_exercise_type_dispatch.py`,
      `test_exercise_validation.py` and `test_user_email_migration.py`.
- [x] **Unchanged and passing:** every audio upload test, including
      `test_local_audio_upload.py`, `test_local_audio_storage.py` and
      `test_admin_audio_endpoints.py`. The admin access test also passes;
      it now covers the new route too.

### Acceptance Criteria Validation

- ✅ **An `image_choice` question with 2 to 4 pictures saves and is served unchanged.** Covered by the save-and-serve tests.
- ✅ **An `audio_image_choice` question with a clip and 2 to 4 pictures saves and is served.** Covered by the same tests.
- ✅ **Each refusal names its field.** Unit validation table and the HTTP refusals.
- ✅ **The migration upgrades and downgrades, and the model matches it.** Migration tests, plus the dispatch test on the model's constraint.
- ✅ **A word whose only question is a picture question is practised with it.** Practice test.
- ✅ **The upload link:** WebP or JPEG, 1 byte to 1 MB, 10 minutes, and the key layout. R2 link tests.
- ✅ **Refusals and non-admins.** R2 refusal tests and the learner test.
- ✅ **Local storage and loading; links for one kind never upload the other.** Local-flow tests.
- ✅ **Every existing test passes; `ruff` is clean; `mypy` adds no errors.**
- ⚠️ **The R2 CORS check is recorded:** done at Implement, but only partly
  answered.
  - r2.dev doesn't answer preflight requests, and no existing object was
    available to test.
  - The CORS policy in the README doesn't include the Flutter web app's
    origin.
  - The check will be repeated once a picture is on R2, and changing the
    policy is the owner's call.

### Issues Found

**One gap in the tests, found by the mutation check and closed:**
- The picture route's check that its store is for pictures could be
  removed without any test failing. Without it, the upload was still
  refused, but by a later check with a different error. It is a second
  line of defence, and a new test now requires the route to stay closed
  when wired to an audio store.

**No bugs were found in the new code.**

### Notes

- **Found while writing the practice test: the admin API can't link a
  question to a vocabulary word,** for any type. The seed makes the link
  (bolt 051). Questions that admins write won't appear in practice until
  such a link exists. No planned bolt adds it: bolt 040 (admin
  vocabulary) lists and edits words but doesn't link them to questions.
  It is a candidate for a later story.
- **Local `dev.db`** is at the new migration. Its backup
  `backend/dev.db.bak-20260925T081216Z` is not to be committed.
