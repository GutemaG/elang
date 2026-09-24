---
stage: plan
bolt: 039-admin-audio-ui
created: '2026-09-24T09:10:00Z'
---

## Implementation Plan: content-admin-web

### Objective

A listening exercise's editor lets an admin set its clip in three ways:
record it in the browser, upload a file, or paste a link. Recorded and
uploaded clips go to the audio store and play straight away. Until R2 serves
files, the store is the local backend (bolt 041). The admin never types an
address by hand unless it is a link.

### What the code showed

1. **The API is already there** (bolts 036 and 041).
   - `POST /api/v1/admin/audio/uploads` takes `{lesson_id, content_type, size}`
     and returns `{upload_url, method: "PUT", headers, key, public_url,
     expires_in}`.
     - `upload_url` is always absolute: R2's signed URL, or
       `http://localhost:8000/api/v1/audio-files/{key}?…` locally.
     - `public_url` is absolute on R2 and relative locally
       (`/media/audio/{key}`).
     - The server accepts these types: `audio/mp4`, `audio/x-m4a`,
       `audio/mpeg`, `audio/webm` and `audio/ogg`.
     - Size must be between 1 byte and 5 MB.
     - With no storage configured it answers `503`.
   - `POST /api/v1/admin/audio/links` takes `{url}` and returns
     `{url, content_type}`. A refused link answers `422` with
     `details.reason`: `not_https`, `unreachable`, `private_address`,
     `timeout`, or not audio.
   - The signed PUT must carry **exactly** the returned `headers`, meaning
     the base type (`audio/webm`, not the blob's `audio/webm;codecs=opus`),
     and **no** bearer token.
2. **Saving the exercise** already accepts an `https://` address, or a
   `/media/` path in local development. The editor already resolves `/media/…`
   against `VITE_API_BASE_URL` when playing a clip (`playableUrl`).
3. **The listening form today** is a plain "Audio address" field with a
   player. One editor test types into that field. The round-trip tests do not
   touch it.
4. **jsdom has no `MediaRecorder`, `getUserMedia` or `URL.createObjectURL`**,
   so the tests use fakes of these.

### Deliverables

**The Audio section of a listening exercise**
- **Current clip**: a player for the saved (or newly chosen) clip, with a
  label showing where it plays from:
  - "audio store" for an https address
  - "local backend only" for a `/media/` path
  - "No audio yet" when there is none
- **Three tabs**: Record, Upload and Link.
  - **Record**
    1. Ask for the microphone.
    2. Start and Stop, with a running timer. Recording stops by itself at
       2 minutes, well under 5 MB.
    3. Then play the take back, and choose Discard, Record again, or
       **Use this recording**.
  - **Upload**
    1. Choose a file (`accept="audio/*"`).
    2. The file is checked before anything is sent: an allowed type (by MIME
       type, or by `.m4a`, `.mp3`, `.webm` or `.ogg` when the browser gives
       none) and 5 MB at most. A refused file is explained, and nothing
       uploads.
    3. Then play it, and choose **Use this file** or pick another.
  - **Link**
    1. Paste an `https://` address and press **Check link**.
    2. The server check runs. If the link is accepted, it becomes the
       current clip. If not, the reason is shown under the field in plain
       words.
- **"Use this recording" / "Use this file"** does two things:
  1. It uploads straight away: first the presign, then the PUT to the signed
     link with exactly its headers, while "Uploading…" is shown.
  2. It puts the returned `public_url` into the draft as `audio_url`. The
     current clip then plays from that address, and the page shows
     **Unsaved changes**. The exercise's **Save** stores it, the same as any
     other edit.
- **Microphone problems** are explained on the Record tab, and Upload and
  Link keep working:
  - permission denied
  - no microphone
  - no MediaRecorder support
- **Recording format**:
  - `audio/mp4` when `MediaRecorder.isTypeSupported('audio/mp4')`.
  - Otherwise `audio/webm`, with a visible warning that iPhones may not play
    it and uploading an m4a or mp3 is safer.
- **Upload errors** are shown in plain words, and the take or file is kept
  so it can be retried:
  - storage not configured (`503`)
  - type or size refused (`422`)
  - an expired or refused signed link
  - a network failure
- The **AppShell "Coming next"** list drops "Audio studio".

**Code layout** (new `admin/src/audio/`)
- `formats.ts` (pure):
  - the allowed types and the 5 MB limit
  - the base type of a blob or file, including the file-extension fallback
  - the recording type to choose
  - a check for a chosen file
- `upload.ts`: `uploadClip(api, lessonId, blob, type)`. It sends the
  presign through the existing `ApiClient`, then does a plain `fetch` PUT,
  and returns the `public_url`.
- `useRecorder.ts`: the MediaRecorder state machine (idle, asking,
  recording, recorded, denied, unsupported). It stops the mic tracks and
  frees object URLs when done.
- `AudioField.tsx`: the section above. It replaces the listening block in
  `ExerciseForm.tsx`. `ExerciseForm` gains a `lessonId` prop from the page.
- `types.ts` gains `AudioUploadResponse` and `AudioLinkResponse`.

### Dependencies

- **Bolt 036 (the admin audio API)** and **bolt 041 (local audio storage)**:
  the presign, the link check and the local signed PUT. No backend change is
  planned.
- **Bolt 038 (the exercise editors)**: the draft, unsaved-changes and Save
  flow, `playableUrl`, and field errors for `audio_url`.
- **No new npm packages.** MediaRecorder and fetch are built into the
  browser.

### Technical Approach

- **The upload happens on "Use this…", not on exercise Save.** This makes
  two clear steps: the clip is stored, then the exercise points at it. It
  also means a failed upload never leaves the exercise half-saved. The
  trade-off: a clip uploaded and then abandoned without saving stays in
  storage unused, which is harmless at this scale.
- **The PUT goes outside `ApiClient`.** It must not carry the bearer token
  (R2 would refuse the extra header), it sends a raw blob, and it must use
  the server's `headers` verbatim. Because the header is set explicitly, the
  blob's `;codecs=…` never reaches the store.
- **Links accept `https://` only**, because the server's check does.
  `/media/…` addresses only come from uploads. An existing `/media/` clip
  still shows and plays as the current clip.
- **Tests fake the browser** so no real mic or network is used:
  - a small fake `MediaRecorder` with a controllable `isTypeSupported`
  - `navigator.mediaDevices.getUserMedia`, which grants or rejects
  - `URL.createObjectURL`
  - The FakeServer gains the two audio routes, plus a handler for the
    absolute upload URL.

### Acceptance Criteria

- [ ] A listening exercise's editor offers Record, Upload and Link, and a
  player for the current clip.
- [ ] With the mic granted, an admin can start, stop, play back, discard and
  re-record before anything uploads. Nothing is sent until "Use this
  recording".
- [ ] With the mic denied, or with no mic or no recorder, a message explains
  it, and Upload and Link still work.
- [ ] `audio/mp4` is recorded when supported. Otherwise WebM is recorded,
  with the iPhone warning shown.
- [ ] "Use this…" presigns with the right `lesson_id`, base type and exact
  size. It then PUTs the blob to `upload_url` with exactly the returned
  headers and no `Authorization`. The returned `public_url` becomes
  `audio_url`, the new clip plays from its resolved address, and Save sends
  it.
- [ ] A pasted link runs the server check. An accepted link becomes the
  clip, and a refused one shows its reason inline without changing the
  clip.
- [ ] A file over 5 MB, or a non-audio file, is refused before any request.
- [ ] Upload failures (`503`, `422`, a refused PUT, the network) show a plain
  message and keep the take or file for a retry.
- [ ] The existing tests (330) still pass, and `tsc`, `eslint` and the build
  are clean.
- [ ] Manual checks for the Test report:
  - **A real browser**: record in Chrome or Edge against the local backend,
    upload, play back, and save.
  - **A phone**: the app fetches the lesson and plays the clip. The local
    `/media/` path works only on a device that can reach the local backend
    (the emulator via `10.0.2.2`, or a phone on the same Wi-Fi). Checking on
    a phone over the internet waits for the R2 public URL.
