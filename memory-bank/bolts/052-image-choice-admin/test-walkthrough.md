---
stage: test
bolt: 052-image-choice-admin
created: '2026-09-25T13:20:00Z'
---

## Test Report: image-choice-admin

### Summary

- **Tests:** all 486 admin tests pass. There were 395 before the bolt and
  91 are new.
- **Checks:** `tsc -b`, `eslint` and `vite build` are clean.
- **Coverage:** not measured.
- **Mutation check:** 41 deliberate breakages of the new code (shrinking,
  uploading, the model, the slot editor, the page, the form and the
  preview).
  - The first run caught 40. The miss was closed with one more test
    case, and now all 41 are caught.
  - Each file was checked to be restored exactly after its run.
- **Test settings changed:** the whole suite runs under load on this
  machine (8 cores), and some tests ran past their time limits.
  - **What happened:** with the new tests running in parallel, whole-page
    tests sometimes ran past vitest's 5 s limit. That included two
    existing tests, the tree test and a recorder test. Some also passed
    Testing Library's 1 s wait.
  - **The change:** `vite.config.ts` now allows 15 s per test, and
    `src/test/setup.ts` waits up to 3 s. No test's own assertions changed.
  - **After the change:** the suite passed four runs in a row.

### Test Files

- [x] **`admin/src/pictures/shrink.test.ts`** (37, new)
  - **Drawn sizes:** 4000×3000, 3000×4000, square, and exactly 512. A
    small picture keeps its size, and a very thin one never gets a side
    of 0.
  - **Files:**
    - JPEG, PNG and WebP are accepted.
    - GIF, SVG, HEIC, text, PDF and a file with no type are refused.
    - An empty file is refused.
    - Exactly 10 MB is allowed; one byte more is refused.
  - **Shrinking:**
    - A 4000×3000 photo becomes 512×384 WebP, at most 300 KB.
    - Quality steps down until the picture fits, and stops at the first
      step that fits.
    - A picture still too big at the lowest step is refused.
    - A refused file is never decoded.
    - A file that won't decode, and a browser that can't encode, each
      give a message.
    - The decoded picture is released either way.
  - **Without WebP:**
    - JPEG is used instead, on white. WebP stays transparent.
    - The lack of WebP is noticed once, and later pictures go straight
      to JPEG.
    - A browser that does make WebP keeps being asked for WebP.
  - **The real browser steps**, with the canvas stubbed:
    - The EXIF orientation is applied when decoding.
    - Drawing uses the given size, and fills white only when asked.
    - A canvas that can't draw gives a message.
    - Encoding passes the type and quality.
- [x] **`admin/src/pictures/upload.test.ts`** (8, new)
  - **The link request:** it names the lesson, type and exact size, and
    the picture's address is returned.
  - **The PUT:** it sends exactly the signed headers and no session
    token.
  - **Messages:**
    - no storage configured (`503`)
    - the server's own refusal, passed on
    - an unreachable store
    - `403` (the link may have expired) and `500`
  - **Refused before anything is sent:** a file that isn't a picture, and
    one over 10 MB.
- [x] **`admin/src/exercises/pictures.test.tsx`** (23, new): the real
  editor page against the fake server. Shrinking is stubbed, since jsdom
  has no canvas.
  - **New questions:**
    - Both types start with two empty slots.
    - An image choice question is built, uploaded and created with
      exactly the right body.
    - The audio type has the audio field, and can't be created without a
      clip; once a link is checked, it can.
  - **Slots:**
    - Adding stops at 4 and removing stops at 2.
    - A new slot gets the next letter.
    - A chosen picture is shrunk, uploaded and shown from its new address.
    - If the upload fails, or the picture can't be shrunk, the slot keeps
      its old picture and nothing is uploaded.
    - Save waits while a picture uploads, and an edit made meanwhile is
      kept.
  - **Blocking rules:**
    - Each slot says what it still needs, and Save's title names the
      first thing.
    - A description of only spaces still blocks.
    - Descriptions stop at 200 characters.
    - Removing the correct picture blocks Save until another is marked.
  - **Round trip:** both stored types save back unchanged. Stored
    pictures, descriptions, the marked answer and the clip all fill the
    form.
  - **Server errors:** a `422` about one picture shows beside that
    picture, and one about the whole list shows under the list.
  - **Preview:**
    - The prompt, or the instruction and play button, appears above a
      2×2 grid, with the correct picture marked as the form changes.
    - Local pictures load from the backend.
    - A picture that fails to load shows its description.
    - Empty slots read "No picture".
- [x] **`admin/src/exercises/model.test.ts`** (23 added)
  - **Blank questions:** new questions of both types.
  - **Editing the picture list:**
    - adding and removing slots, within the limits
    - clearing the answer when the correct picture is removed
    - setting a picture or description by id, touching nothing else
    - marking the answer
    - keeping the audio question's clip through every change
  - **`pictureProblems`:** the order of its checks, and what Save names
    first.
  - **Server errors:** where each picture error lands, and how picture
    messages read in plain words.
  - **Other:** local picture addresses, and both types copied exactly.
- [x] **Changed and passing:**
  - `tree.test.tsx`: the menu list gains the two new type names.
  - `test/exercises.ts`: two fixtures added.
  - `test/setup.ts` and `vite.config.ts`: the time limits above.

### Acceptance Criteria Validation

**Story 001: picture upload with shrinking**
- ✅ **JPEG, PNG or WebP up to 10 MB is scaled to 512 px or less, never
  enlarged, and saved as WebP or JPEG:** covered by the shrink tests.
- ✅ **A 4000×3000 JPEG comes out at most 512×384 and 300 KB:** covered by
  the shrink tests.
- ✅ **Quality is lowered step by step:** covered by the shrink tests.
- ✅ **Non-pictures and files over 10 MB are refused, and nothing is
  uploaded:** covered by the shrink and upload tests.
- ✅ **Link, PUT and address; a failure keeps the old picture:** covered
  by the upload tests and the page tests.
- ✅ **A 300×200 picture keeps its size, a transparent PNG saved as JPEG
  goes on white, and EXIF rotation is applied:** covered by the shrink
  tests. These run in jsdom with the browser steps stubbed; see the notes.
- ✅ **Tests cover shrinking, the limits and the upload call.**

**Story 002: editors and preview**
- ✅ **"Add exercise" offers both types:** covered by the tree test.
- ✅ **The image choice editor has the prompt and 2 to 4 slots, each with
  a picture, a description and a "correct" marker:** covered by the page
  tests.
- ✅ **The audio image choice editor has the instruction, the existing
  audio field and the same slots:** covered by the page tests.
- ✅ **Adding isn't offered at 4 slots, and removing isn't offered at 2:**
  covered by the slot tests.
- ✅ **Save is blocked, with the reason beside the field, for a missing
  picture, description, answer or clip:** covered by the blocking and
  audio tests.
- ✅ **Both types save and reopen unchanged:** covered by the round-trip
  tests.
- ✅ **The preview shows the prompt, or the instruction and play button,
  above a 2×2 grid; a failed picture shows its description:** covered by
  the preview tests.
- ✅ **Tests cover both editors, their blocking rules and the round
  trip.**

### Issues Found

**No bugs found in the new code.** The mutation check found one gap in
the tests, now closed:
- Removing the "never 0 px" floor from the width went unnoticed, because
  only a very wide picture was tested, and that floor applies to the
  height. A 3×5000 case now covers the width.

### Notes

- **Shrinking hasn't been tried in a real browser yet.** jsdom has no
  canvas, so every rule was tested with the browser steps stubbed. A
  quick manual check would confirm it end to end:
  1. Start the backend on port 8000.
  2. Open the admin site on port 5173.
  3. Pick a large phone photo and a transparent PNG in a picture slot.
- **The deployed admin site** uploads pictures through R2 using the CORS
  rule that already serves audio. That rule was not checked or changed
  here.
