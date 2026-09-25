---
stage: implement
bolt: 052-image-choice-admin
created: '2026-09-25T12:25:00Z'
---

## Implementation Walkthrough: image-choice-admin

### Summary

The admin site can now build both picture question types.
- A picked picture is checked, shrunk to at most 512 px and 300 KB, and
  uploaded through the backend's picture link. It is saved as WebP, or as
  JPEG where the browser can't make WebP.
- The slots, the blocking rules and a 2×2 picture preview work the same
  way for both types.
- The audio type reuses the existing audio field.

### Structure Overview

- A new `pictures/` folder holds the browser-side picture work: shrinking
  (with the browser steps passed in) and uploading.
- Audio's link-then-PUT step is now `upload/link.ts`, shared by audio and
  pictures.
- The exercise model gains picture editing functions and a
  `pictureProblems` check.
- One picture-choices editor serves both types.
- The form, the preview and the editor page each gain branches for the
  new types.

### Completed Work

- [x] `admin/src/types.ts` - Both types and their bodies, `PictureTile`,
      and both types in `EXERCISE_TYPES`.
- [x] `admin/src/tree/levels.ts` - The picture upload route.
- [x] `admin/src/upload/link.ts` - The shared link-then-PUT upload. Its
      messages name the kind of store.
- [x] `admin/src/audio/upload.ts` - Now calls the shared upload with
      audio's own wording. Its behaviour is unchanged.
- [x] `admin/src/pictures/shrink.ts`:
  - The file check: type, empty, and 10 MB.
  - The scaling rule.
  - WebP-or-JPEG encoding. The WebP check runs once and its answer is
    kept.
  - The quality steps.
  - A white background for JPEG.
  - The real browser steps, with EXIF orientation applied.
- [x] `admin/src/pictures/upload.ts` - Uploads a shrunk picture. Also
      shrinks then uploads a picked file.
- [x] `admin/src/pictures/PictureImage.tsx` - One picture. With no
      address, or one that fails to load, it shows the alt text instead.
- [x] `admin/src/exercises/model.ts`:
  - `TYPE_INFO` for both types, and `blank()` with two empty slots.
  - The picture editing functions, which find slots by id.
  - `pictureProblems`.
  - Picture types in `missingAnswer` and `placeError`.
  - `setAudioUrl` for both audio types.
- [x] `admin/src/exercises/PictureChoicesEditor.tsx` - The slots. Each
      has:
  - the "correct" marker, a thumbnail, and a choose or replace button
  - alt text of up to 200 characters
  - a spinner while uploading, and a message on failure that keeps the
    old picture
  - beside it, what it still needs and any server error

  Remove is disabled at 2 slots, and "Add picture" is hidden at 4.
- [x] `admin/src/exercises/ExerciseForm.tsx` - The picture editor for both
      types, the audio field for the audio type, and a prompt placeholder
      for each type.
- [x] `admin/src/exercises/ExerciseEditorPage.tsx` - Save waits while a
      picture is uploading.
- [x] `admin/src/exercises/ExercisePreview.tsx` - A shared clip player,
      and a 2×2 picture grid with the correct picture marked.
- [x] `admin/src/tree.test.tsx` - The menu test's list gains the two new
      type names. This is the only existing test changed.

### Key Decisions

- **An upload applies to the latest question.** An upload finishes after
  a wait, so its address goes into the question as it is by then, found
  by the slot's id.
  - An edit made in the meantime is kept.
  - A slot removed in the meantime is simply not updated.
- **Save waits for uploads.** Saving mid-upload would store the old
  picture. So Save is held, and its title gives the reason.
- **`missingAnswer` covers picture questions fully.** An empty slot has
  nothing to type into, so the site says what's missing rather than
  leaving it to the server.

### Deviations from Plan

- **The audio type's "no clip" reason** is the audio field's existing
  notice, "No audio yet. Add a clip below.", which already shows beside
  the field. A separate hint would repeat it. The missing clip still
  blocks Save, and Save's title names it.

### Dependencies Added

- None.

### Developer Notes

- **Checks:**
  - `tsc -b` and `eslint` are clean.
  - All 395 existing tests pass.
  - `vite build` succeeds.
- jsdom has no canvas. The tests will stub the browser steps, and
  `forgetWebpCheck()` resets the WebP check between tests.
- Uploading from the deployed admin site to R2 relies on R2's CORS rule.
  That rule already allows the admin site's origin for audio.
