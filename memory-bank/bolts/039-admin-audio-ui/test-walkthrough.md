---
stage: test
bolt: 039-admin-audio-ui
created: '2026-09-24T09:34:00Z'
---

## Test Report: content-admin-web

### Summary

- **Tests**: 395/395 pass (`npm test`, Vitest on jsdom). That is 330 before
  this bolt, plus 35 format tests and 30 page tests.
- **Types, lint and build**: `tsc -b` and `eslint` are clean, and the build
  succeeds. JS is 104.5 KB gzipped, up from 100.7 KB.
- **Falsification**: 18 deliberate breakages, every one caught. Each source
  file was restored byte for byte.
- **A real browser**: headless Edge with a fake microphone, over canned data.
  It recorded AAC and played it back, and the upload requests had exactly
  the right shape. See the implementation walkthrough.
- **Backend**: unchanged.

### Test Files

- [x] `admin/src/audio/formats.test.ts` (35)
  - The allowed types and the 5 MB limit equal the backend's.
  - Base types drop the codec.
  - The aliases `audio/mp3` and `audio/m4a` are accepted, and a file with no
    type is recognised by its extension.
  - These are refused: WAV, `video/webm` (even when named `.webm`), a
    picture, and a file with no type and no known extension.
  - Exactly 5 MB passes and one byte more fails. An empty file fails. An
    audio format that can't be stored gets a different message from a file
    that isn't audio.
  - The recording format goes AAC, then plain mp4, then WebM, then the
    browser's own choice. Without MediaRecorder there is no recording.
  - Sizes and durations are formatted.
- [x] `admin/src/audio/audio.test.tsx` (30): the editor page as an admin
  uses it. It fakes a microphone (a MediaRecorder, `getUserMedia` and object
  URLs) and a store on another host.
  - **The section**
    - The current clip plays from the backend and is labelled Local, Hosted
      or Placeholder.
    - There are three tabs, with Record selected.
    - A new exercise says "No audio yet".
    - A take survives switching tabs.
  - **Recording**
    - It records AAC with no warning. Nothing is sent until the take is
      used.
    - Stop turns the microphone off.
    - Discard frees the take. Record again starts a new take.
    - Using a take:
      - The presign sends `{lesson_id, content_type: audio/mp4, size}` with
        the session token.
      - The PUT goes to the signed link with its query, with **exactly**
        `{Content-Type: audio/mp4}`, no token, and the blob itself.
      - The clip and the learner preview switch to the backend-resolved
        address, marked "Not saved yet".
      - Save sends the new `audio_url`, after which "Not saved yet" clears.
    - WebM gets the iPhone warning and is uploaded as `audio/webm`. Plain
      mp4 gets the mp4-without-AAC warning.
    - A recording over 5 MB is refused before any request.
    - It stops by itself at 2:00 and turns the microphone off.
    - Leaving the page mid-take turns the microphone off.
  - **When recording is not possible**
    - A denied microphone and a missing microphone each get their own
      message, and Link still works.
    - A browser without MediaRecorder says so, and Upload still works.
  - **Uploading a file**
    - A chosen file plays and is uploaded only when used, as that exact
      file with its type.
    - An `.m4a` with no type goes as `audio/mp4`.
    - These are refused before any request, with no player created: over
      5 MB, a picture, WAV, an empty file.
  - **Failures**
    - `503`: "nowhere to store audio… Paste a link instead". Nothing is
      PUT, and the take is kept.
    - A `422` is shown in plain words.
    - A `403` from the store: the expired-link message, and the clip and the
      "saved" state are unchanged. A retry then succeeds.
    - Any other status is named.
    - An unreachable store gets the connection and CORS message, with the
      take kept.
  - **Links**
    - A link is checked by the server, becomes the clip, and the field
      clears.
    - A refusal appears inside the Link panel, leaves the clip and the
      "saved" state alone, and clears on the next keystroke.
    - Enter checks the link. An empty field can't be checked.
- [x] `admin/src/exercises/editor.test.tsx`: the two tests that used the
  removed address field now go through the Link tab.
- [x] `admin/src/test/fakeServer.ts`: now also records each request's
  headers and raw body. A handler that throws acts as a network failure.

### Falsification

Each breakage was applied, the audio and editor tests run, and the source
restored:

| Breakage | Tests failing |
|---|---|
| The PUT carries the bearer token | 3 |
| The PUT sends the blob's own type | 2 |
| The presign asks for the codec type | 2 |
| Plain mp4 preferred over AAC | 2 |
| Exactly 5 MB refused | 1 |
| No file-extension fallback | 4 |
| A chosen file uploads at once | 2 |
| Microphone left on after Stop | 2 |
| Microphone left on when the page is left | 1 |
| No stop at two minutes | 1 |
| A failed upload loses the take | 3 |
| A link used without the server check | 1 |
| The upload link saved instead of the public address | 3 |
| Every microphone problem called a failure | 1 |
| Never "Not saved yet" | 2 |
| No iPhone warning | 2 |
| A discarded take is not freed | 1 |
| Local clips played from the site, not the backend | 8 |

### Acceptance Criteria Validation

**Story 004, record, upload or link audio**
- ✅ **A listening editor offers Record, Upload and Link, and a play
  button for the current clip**: the section tests
- ✅ **Start, stop, play back, discard and re-record before anything
  uploads**: the recording tests, which check that no request is sent
- ✅ **A denied microphone is explained, and Upload and Link still work**:
  the permission tests
- ✅ **mp4 when the browser can record it; otherwise WebM with an iPhone
  warning**: AAC in mp4 is preferred (see Issues Found), and both fallbacks
  warn
- ✅ **Saved clips are PUT to the presigned URL, the public URL is saved as
  `audio_url`, and the new clip plays from it**: the use-a-take and
  use-a-file tests, and the real-browser run
- ✅ **A pasted link runs the server check, and a rejection shows
  inline**: the link tests
- ✅ **A file over 5 MB or a non-audio file is refused before any upload**:
  the refused-file tests
- ⏳ **The clip plays in the app on a real phone**: a manual check, not yet
  done. See Notes.

### Issues Found

- **Plain `audio/mp4` recordings are not iPhone-safe.** In a real Edge,
  asking for `audio/mp4` recorded Opus inside mp4. The recorder now asks for
  AAC first, and the fallbacks carry the iPhone warning. This was found and
  fixed in Stage 2.
- **In local development the backend uses R2, not the local store.**
  `backend/.env` has all four R2 settings, so the running backend's
  `choose_audio_storage` picks R2. The local upload route rightly answers
  `404`, which was checked against the running backend. So on this machine
  today:
  - The browser PUTs to R2, which needs a CORS rule allowing
    `http://localhost:5173`.
  - The saved address is on `AUDIO_BASE_URL`, which still answers `404`.

  The user's first real try failed this way: "Could not reach the audio
  store". **Fixed on 2026-09-24** by commenting out `R2_ACCESS_KEY_ID` in
  `backend/.env`, as bolt 041 intended. The backend reloaded, and its upload
  route now checks signatures (a bad one answers `403`, not `404`). Nothing
  in the code needed to change. To go back to R2, uncomment the line once R2
  has its CORS rule and public URL.
- **In the tests**: a `type="url"` field trims pasted spaces in jsdom, as
  browsers do, so the trim case was dropped from the page test. The server
  trims too.

### Notes

- **The running backend's CORS preflight passes.** A preflight for a PUT
  from `http://localhost:5173` with a `Content-Type` header is allowed.
- **Manual checks left to the user.** Both need Google sign-in on the admin
  site:
  1. **In the browser**: record or upload a clip, choose "Use this…", press
     Save, and play it back. This works once uploads go to the local store,
     or once R2 has its CORS rule and public URL.
  2. **On a phone**: open the lesson in the app and play the clip.
     - With the local store, the device must be able to reach the backend:
       the emulator through `10.0.2.2`, or a phone on the same Wi-Fi.
     - Playing over the internet waits for the R2 public URL.
