---
stage: implement
bolt: 039-admin-audio-ui
created: '2026-09-24T09:17:00Z'
---

## Implementation Walkthrough: content-admin-web

### Summary

A listening exercise's editor now has an Audio section. It shows the
current clip with a player and says where the clip plays from. Three tabs
replace the clip:
- **Record** in the browser.
- **Upload** a file, which is checked before anything is sent.
- **Link**: a pasted link, which the server checks.

Recordings and files go to the audio store when the admin chooses "Use
this…". The new address becomes the draft's `audio_url`, and the exercise's
own Save stores it.

### Structure Overview

All the audio code is in a new `admin/src/audio/` folder, in four parts:
- pure format rules
- the two network calls
- a recorder hook
- the section component

The exercise form uses the section in place of its old address field.
Nothing else in the editor changed: the draft, "Unsaved changes", Save and
server field errors all work as they did in bolt 038, and the learner preview
plays the new clip too.

### Completed Work

- [x] `admin/src/audio/formats.ts`: the rules for what can be stored.
  - It mirrors the backend's allowed types and 5 MB limit.
  - A file with no type is recognised by its extension.
  - It refuses an empty, oversized or non-audio file.
  - It picks the recording format for this browser, and reports whether
    this browser can record at all.
  - It formats sizes and durations.
- [x] `admin/src/audio/upload.ts`: the two network calls.
  - **Upload**: the presign goes through the API client. The PUT goes to
    the signed link as a plain request with exactly the returned headers and
    no bearer token. Storage-not-configured, refused, expired and
    unreachable cases all produce plain messages.
  - **Link**: asks the server to check a pasted link.
- [x] `admin/src/audio/useRecorder.ts`: the recorder hook.
  - It handles one take at a time, with a running clock and an automatic
    stop at two minutes.
  - It tells a denied microphone, a missing one and other failures apart.
  - It releases the microphone as soon as a take stops, and releases
    everything when the page is left mid-take.
- [x] `admin/src/audio/AudioField.tsx`: the Audio section.
  - **The current clip**, labelled as one of: Hosted, Local backend only,
    or Placeholder clip. When the draft's clip differs from the stored one,
    it also shows "Not saved yet".
  - **The three tab panels**: Record, Upload and Link. They stay mounted,
    so switching tabs never loses a take or a chosen file.
  - **The warnings, errors and "Uploading…" / "Checking…" states.**
- [x] `admin/src/exercises/ExerciseForm.tsx`: the listening branch now
  renders the Audio section. The form also receives the lesson id, for the
  presign, and the stored copy, for "Not saved yet".
- [x] `admin/src/exercises/ExerciseEditorPage.tsx`: passes those two
  through.
- [x] `admin/src/types.ts`: the upload-link and link-check responses.
- [x] `admin/src/tree/levels.ts`: the two audio routes.
- [x] `admin/src/shell/AppShell.tsx`: "Audio studio" is gone from "Coming
  next".
- [x] `admin/src/exercises/editor.test.tsx`: the two tests that typed into
  the removed address field now use the Link tab.

### Key Decisions

- **Upload when "Use this…" is chosen, not on Save.** This makes two clear
  steps: the clip is stored first, then the exercise points at it. A failed
  upload never leaves the exercise half-saved, and the take or file is kept
  for a retry.
- **Record AAC in mp4 whenever the browser can.** A real Edge showed that a
  plain `audio/mp4` request records **Opus in mp4**, which iPhones may not
  play, even though it is "mp4". Edge does support AAC
  (`audio/mp4;codecs=mp4a.40.2`), so that is asked for first. Plain mp4
  comes second and WebM last, and each of those shows the iPhone warning.
  The store still receives the base type `audio/mp4`.
- **The server's headers are used verbatim on the PUT.** The recording's
  own type (`audio/mp4;codecs=mp4a.40.2`) never reaches the store. The
  browser run confirmed the PUT carried only `Content-Type: audio/mp4`.
- **A link must be https.** A `/media/…` address only ever comes from an
  upload.

### Deviations from Plan

- **The recording-format order gained AAC first**, as described above. The
  plan said `audio/mp4` first.
- **The success note after a link check is not an ARIA "status" region.**
  The page's Saved / Unsaved indicator already is one, and there should be
  only one.

### Dependencies Added

None.

### Developer Notes

- **Checked in a real browser, over canned data:** headless Edge with a
  fake microphone, driven through the DevTools protocol. It recorded 4 s of
  AAC (70 KB), which played back in the page. "Use this recording" then
  presigned `{lesson_id: l1, content_type: audio/mp4, size: 71964}` and PUT
  the exact bytes with only the server's Content-Type. The current clip
  switched to the `/media/…` address, marked "Not saved yet". A refused link
  showed its reason inline, at phone width.
  - The temporary harness page was deleted.
  - That run used a fake server, not the real local backend. Uploading to
    the real backend needs a signed-in admin.
- **Checks:** `tsc`, `eslint` and the build are clean, and 330 of 330
  existing tests pass. JS is 104.5 KB gzipped, up from 100.7 KB.
