---
stage: plan
bolt: 097-generate-tab-editor-and-use
created: '2026-10-12T16:30:00Z'
---

## Implementation Plan: generate-tab

### Objective

This bolt covers story 018 (FR-18) and story 019 (FR-19).

- A generated take opens in the same clip editor as a recording or an
  upload. Silence is cut automatically, the handles and sliders move the
  cut, and the volume evening and effects work as they do there. For
  example, a 5-second take whose speech ends at 2 seconds is kept as
  about 2.
- **Use this clip** stores the take exactly as Upload stores a file. It
  then becomes the field's current clip, marked "Not saved yet", and the
  page's own Save keeps it.

### What the code says (checked before planning)

- **F1 Shared hooks:** `AudioField.tsx` has two private hooks that
  `RecordPanel` and `UploadPanel` both use.
  - `useCleaning(clip)` returns `{cleaning, working, reset,
    editor(original)}`.
  - `useClipUpload(store, onUploaded)` returns `{busy, problem,
    setProblem, send(clip, type, cleaning?)}`. `send` runs `finalClip()`
    (cleaned or original), applies the 5 MB check with its message,
    then calls the store.
- **F2 Panel location:** `GeneratePanel.tsx` is in its own file. If it
  imported the hooks from `AudioField.tsx`, the two files would import
  each other.
- **F3 Editor wording:** `ClipEditor` labels the original choice
  "As recorded".
- **F4 Generated format:** a take is `audio/mpeg`, which `audioTypeOf`
  accepts as mp3.
- **F5 Save button:** `AudioField` has no busy callback. Today an upload
  shows "Uploading…" on its own button and doesn't hold the page's Save,
  and FR-19 asks for the same behaviour as uploads.

### Decisions

- **D1 Shared hooks file:** `useCleaning`, `useClipUpload` and their
  `Cleaning` type move unchanged from `AudioField.tsx` to a new
  `audio/clipHooks.tsx`. `AudioField` and `GeneratePanel` both import
  them from there, so behaviour stays identical for Record and Upload.
- **D2 Original label:** `ClipEditor` gets `originalLabel?: string`,
  defaulting to `'As recorded'`. `useCleaning(clip, originalLabel?)`
  passes it on. The Generate panel passes `'As generated'`. Record and
  Upload stay as they are.
- **D3 Panel props:** `GeneratePanel` takes `{ voice, send:
  ClipUploader, onUploaded: (url) => void }`, and `AudioField` passes its
  existing `send` and `onChange`.
- **D4 Take view:** a take now shows:
  - `clean.editor(<audio controls src={take.url} aria-label="Play the
    generated clip" />)`, which replaces bolt 096's bare player;
  - the line "{voice name} · {seconds} s · not stored yet";
  - **Use this clip**, which reads "Uploading…" while it uploads;
  - **Generate again** and **Discard**.

  Generate again replaces the take. The cut resets for the new take
  through `clean.reset()`, and the cleaned-or-original choice and the
  effects carry over, as they do for recordings.
- **D5 Use this clip:** it calls `upload.send(take.clip.blob,
  'audio/mpeg', clean.cleaning)`. On success the take and the cut are
  cleared, and the field's current clip is the stored address.
  - Errors show with the same messages as Upload, including the 5 MB
    one.
  - The button is disabled while uploading, or while the cleaned version
    is still being worked out (`clean.working`).
- **D6 No status change:** generating changes no other part of the page.
  A Workbook item's status only changes through its own Save.

### Deliverables

- `admin/src/audio/clipHooks.tsx`, a move with no change in behaviour
- `admin/src/audio/AudioField.tsx`: imports the hooks and passes `send`
  and `onChange` to `GeneratePanel`
- `admin/src/audio/ClipEditor.tsx`: `originalLabel`
- `admin/src/audio/GeneratePanel.tsx`: the editor, Use this clip and
  Generate again
- **Tests,** in `generate.test.tsx`, using the codec stand-ins
  `audio.test.tsx` already uses:
  - a take opens in the editor, with "Cleaned" and "As generated";
  - the cut is shorter than the take;
  - Use this clip presigns and uploads through the field's uploader,
    then shows the stored URL as the current clip, marked "Not saved
    yet";
  - "As generated" uploads the original mp3;
  - a failed upload shows its message and keeps the take;
  - Generate again resets the cut;
  - Discard clears the take;
  - Record and Upload still say "As recorded".

### Dependencies

- Bolt 096 (the panel), which is complete.

### Acceptance Criteria

- [ ] A take is trimmed in the clip editor exactly like a recording.
- [ ] "As generated" is offered.
- [ ] Use this clip stores the take through the field's uploader. It
  becomes the current clip, marked "Not saved yet".
- [ ] Generate again, Discard and errors behave as in D4 and D5.
- [ ] Record and Upload are unchanged, and their tests pass.
- [ ] `npm run lint`, `tsc -b`, `vitest` and `vite build` pass.

## Implement (2026-10-12T16:50:00Z)

- **`admin/src/audio/clipHooks.tsx`** (new) holds `ClipUploader`,
  `Cleaning`, `useCleaning(clip, originalLabel?)` and `useClipUpload`.
  They moved from `AudioField.tsx` with their bodies unchanged. The only
  addition is that `useCleaning` passes `originalLabel` on to the
  editor.
- **`admin/src/audio/AudioField.tsx`** imports the hooks and still
  re-exports `ClipUploader` for anything that imported it from here. It
  passes its `send` and `onChange` to `GeneratePanel`, and drops the
  imports it no longer uses.
- **`admin/src/audio/ClipEditor.tsx`** gets
  `originalLabel = 'As recorded'`.
- **`admin/src/audio/GeneratePanel.tsx`**:
  - It now takes `send` and `onUploaded`, and calls `useCleaning(take
    blob, 'As generated')` and `useClipUpload(send, onUploaded)`.
  - A take renders inside `clean.editor(...)`, with the line "{name} · {s}
    s · not stored yet".
  - **Use this clip** runs `upload.send(blob, 'audio/mpeg', cleaning)`.
    It reads "Uploading…" while it works, and is disabled while
    uploading or while the cleaned version isn't ready.
  - **Discard** clears the take.
  - Upload errors show under the take.
  - A new take resets the cut and keeps the cleaned-or-not choice and
    the effects.

### Deviations

None.

### Checks

- `tsc -b` and `eslint` (`src/audio`, `src/voices`) pass.
- The existing audio and voices tests pass (128), including the Record
  and Upload tests.

## Test (2026-10-12T17:05:00Z)

`admin/src/audio/generate.test.tsx` gets 7 new tests (21 in total).
`codec.prepareClip` is mocked the same way as in `audio.test.tsx`: by
default it returns null, and the trimming tests return the two-second
`prepared()` sample instead.

- **Editor:** a take opens in the clip editor.
  - "Cleaned" (0.73 s) is chosen, and "As generated" is offered with no
    "As recorded".
  - The trim summary reads 2.00 s → 0.73 s, and the effects group is
    shown.
- **Moving the cut:** setting End to 1.5 s gives 1.08 s.
- **Use this clip, cleaned:** the field's uploader gets an `audio/mpeg`
  clip. The stored URL becomes the current clip with "Not saved yet",
  and the take is cleared.
- **Use this clip, as generated:** the original 3-byte mp3 is stored
  untouched.
- **Failed upload:** a failed store shows its message, and the take and
  button stay.
- **Generate again:** the new take gets its own cut (back to 0.73 s),
  and "Warmer" carries over.
- **Discard:** clears the take, and nothing is stored.
- **Existing tests:** the Record and Upload tests in `audio.test.tsx`
  still assert "As recorded" and pass unchanged.

### Issues found

None.

### Results

- `vitest run`: 41 files and 818 tests pass.
- `npm run lint` and `tsc -b` are clean.
- `vite build` succeeds.
