---
stage: plan
bolt: 052-image-choice-admin
created: '2026-09-25T11:37:52Z'
---

## Implementation Plan: image-choice-admin

### Objective

Let an admin build both picture question types in the admin site. They
pick a picture, and the site shrinks and uploads it. They describe it,
mark the right one, and preview the question as a learner will see it.

### Decisions

- **D1: Detecting WebP.** The site encodes with
  `canvas.toBlob('image/webp', q)`. A browser that can't encode WebP
  returns a PNG instead, so if the result's `type` is not `image/webp`,
  the site encodes JPEG from then on. The check runs once per page load,
  and its answer is cached. There is no user-agent sniffing.
- **D2: Shrinking.**
  - **Decoding:** `createImageBitmap(file, { imageOrientation:
    'from-image' })`, so phone photos come out upright.
  - **Size:** scaled so the longest side is at most 512 px, never scaled
    up, and rounded to whole pixels.
  - **Background:** a JPEG is drawn on white first, so transparent PNGs
    don't turn black.
  - **Quality:** starts at 0.85 and drops by 0.1 down to 0.35 until the
    file is at most 300 KB. If even 0.35 is too big, the picture is
    refused with a message. At 512 px that shouldn't happen, but a
    wrong-sized upload would be worse.
  - **Accepted files:** JPEG, PNG or WebP by MIME type, up to 10 MB.
    Anything else, or a file that won't decode, is refused with a
    message, and nothing is uploaded.
  - **Code shape:** the browser steps (decode, draw, encode) are passed
    in as one small object, so the rules can be tested in jsdom, which
    has no canvas.
- **D3: Uploading shares audio's path.**
  - The link-then-PUT steps in `audio/upload.ts` move into one helper
    that both audio and pictures call. Each keeps its own wording
    ("audio store" or "picture store").
  - `uploadPicture` posts to `/admin/images/uploads` and returns the
    `public_url`.
  - The audio tests stay unchanged, which shows the move kept audio's
    behaviour.
- **D4: The slot layout.** One `PictureChoicesEditor`, beside
  `ChoicesEditor.tsx`, is used by both types. Each slot is a row with:
  - the "correct" radio button and the slot's number
  - a 96 px thumbnail, or an empty dashed box
  - a "Choose picture" button, which opens a file picker for JPEG, PNG or
    WebP; it reads "Replace" once the slot has a picture
  - the alt text field, with a hint about the 200-character limit
  - remove

  How the list behaves:
  - While a picture is shrinking and uploading, its slot shows a spinner,
    and Save is blocked.
  - If that fails, the message shows under the slot, and the old picture
    stays.
  - "Add picture" is hidden at 4 slots. Remove is disabled at 2, with a
    title saying why.
  - Rows aren't reordered, since dragging is out of scope, and the order
    the admin builds is the order stored.
- **D5: The data model** follows the existing pure functions in
  `model.ts`:
  - **Types:** `PictureTile {id, image_url, alt_text}` and both body
    types are added to `types.ts`. Both types are added to
    `EXERCISE_TYPES` and `TYPE_INFO`: "Image choice" with the `image`
    icon, and "Audio image choice" with `hearing`.
  - **`blank()`:** gives 2 empty slots, `a` and `b`.
  - **Editing functions:** add, remove, set picture, set alt text and
    mark correct. Ids come from the existing `nextId`. Removing the
    correct slot clears the answer.
  - **`setAudioUrl`:** works for both audio types.
- **D6: Blocking rules.** The form checks what it can see. A new
  `pictureProblems(body)` returns one reason per slot, plus a reason for
  the audio and one for the answer:
  - "Choose a picture"
  - "Describe the picture for learners who can't see it"
  - "Mark which picture is correct"
  - "Add the clip the learner hears"

  Each reason shows beside its field, in the soft hint style already
  used for a missing answer. Save is disabled while any reason is left,
  and its title names the first one. The server's own `422` errors still
  land beside the field they name, such as `content.choices[2].alt_text`,
  through the existing `placeError`.
- **D7: Preview.**
  - **`image_choice`:** the prompt.
  - **`audio_image_choice`:** the instruction and the play button, as in
    listening.
  - **Both:** below that, a 2×2 grid of square picture tiles, with the
    correct one outlined in green.
  - **Picture addresses:** a local `/media/...` address is loaded from
    the backend, the way clips are.
  - **Failed pictures:** a picture that fails to load, or a slot with no
    picture, shows its alt text in its place.
- **D8: The content tree** needs no change. It shows each exercise's type
  name from `TYPE_INFO`, and the backend already sends the audio status
  for `audio_image_choice`.

### Deliverables

- **New in `admin/src/pictures/`:**
  - `shrink.ts`: the size and file checks, the quality steps, WebP
    detection, and the browser steps passed in
  - `upload.ts`: `uploadPicture`
- **Changed:**
  - `admin/src/audio/upload.ts`: calls the shared helper
  - `admin/src/upload/link.ts` (new): the link-then-PUT helper
- **New in `admin/src/exercises/`:**
  - `PictureChoicesEditor.tsx`: the slots
- **Changed in `admin/src/exercises/`:**
  - `model.ts`: `TYPE_INFO`, `blank`, the picture editing functions,
    `pictureProblems`, and `missingAnswer` for the new types
  - `ExerciseForm.tsx`: both new branches; the audio field is reused for
    `audio_image_choice`
  - `ExercisePreview.tsx`: the picture grid
- **Also changed:**
  - `admin/src/types.ts`: both types and `PictureTile`
  - `admin/src/tree/levels.ts`: the `imageUploads` route
  - `admin/src/test/exercises.ts`: one fixture for each new type
- **Tests:**
  - `pictures/shrink.test.ts`
  - `pictures/upload.test.ts`
  - `exercises/pictures.test.tsx`
  - additions to `model.test.ts`

### Dependencies

- Bolt 050: `POST /admin/images/uploads`, the content shape, and local
  `/media/images`.
- No new packages.

### Out of Scope

- A shared picture library, cropping, and reordering slots by dragging.
- Pasting a picture link; the stories don't ask for it.
- Neon, production R2 and R2 CORS. Uploads from the deployed admin site
  need R2's CORS rule, which already allows the admin site's origin for
  audio.

### Acceptance Criteria

**Story 001: picture upload with shrinking**
- [ ] A JPEG, PNG or WebP up to 10 MB is scaled to at most 512 px on its
      longest side, never scaled up. It is encoded as WebP, or as JPEG
      where WebP can't be encoded.
- [ ] A 4000×3000 JPEG uploads at 512×384, at most 300 KB.
- [ ] An encoding over 300 KB is retried at lower quality until it fits.
- [ ] A file that isn't a picture, or is over 10 MB, is refused with a
      message, and nothing is uploaded.
- [ ] Uploading asks for a link, PUTs the bytes, and returns the URL. A
      failure shows a message and keeps the slot's old picture.
- [ ] A 300×200 picture stays 300×200. A transparent PNG saved as JPEG is
      drawn on white. EXIF rotation is applied.

**Story 002: editors and preview**
- [ ] "Add exercise" offers "Image choice" and "Audio image choice".
- [ ] The image choice editor has the prompt and 2 to 4 slots, each with a
      picture, alt text and a "correct" marker.
- [ ] The audio image choice editor has the instruction, the existing
      audio field (record, upload or link), and the same slots.
- [ ] At 4 slots, adding is not offered. At 2, removing is not offered.
- [ ] Save is blocked, with the reason beside the field, when:
  - a slot has no picture or no alt text
  - no slot is marked correct
  - the audio type has no clip

  Removing the correct slot blocks save until another is marked.
- [ ] A valid question of either type saves, reopens, and saves again
      unchanged.
- [ ] The preview shows the prompt, or the instruction and play button,
      above a 2×2 picture grid. A picture that fails to load shows its alt
      text.
- [ ] A server `422` on `content.choices[n].alt_text` shows beside slot n.

**Baselines**
- [ ] All 395 existing admin tests pass. `eslint` and `tsc -b` stay clean.
      No existing test changes, except where a new type is added to a
      list.

### Test Plan

- **`shrink.test.ts`:**
  - the scaled sizes: 4000×3000, 3000×4000, 300×200 and exactly 512
  - accepted and refused files: type, 10 MB, and a file that won't decode
  - quality steps down until the file fits, and refusal after the last
    step
  - WebP detection falling back to JPEG, and the check running once
  - white background only for JPEG
  - EXIF orientation passed when decoding
- **`upload.test.ts`:** the link request (route, lesson, type and size),
  the PUT with exactly the signed headers and no token, the returned URL,
  and the messages for 503, an unreachable store and a refused PUT.
- **`pictures.test.tsx`** (the real editor page against the fake server):
  - **The menu:** it offers both types.
  - **Slots:** adding, removing, and the 2 and 4 limits.
  - **Uploading:** choosing a file shrinks and uploads it, and fills the
    slot. The shrinker is stubbed, since jsdom has no canvas. A failed
    upload keeps the old picture.
  - **Blocking:** each rule, including removing the correct slot.
  - **The audio type:** the audio field is present, and saving is blocked
    without a clip.
  - **Round trip:** create, reopen and save each type, and the body is
    unchanged.
  - **Server errors:** a `422` is placed beside its slot.
  - **Preview:** the prompt, the play button, the grid, the correct tile,
    and the alt text when a picture fails to load.
- **`model.test.ts` additions:** the picture editing functions, the ids,
  removing the correct slot, and `pictureProblems`.
