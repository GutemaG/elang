---
stage: test
bolt: 041-local-audio-storage
created: '2026-09-24T07:37:47Z'
---

## Test Report: content-admin-api

### Summary

- **New tests**: 66/66 pass (43 unit, 23 integration over HTTP).
- **Whole backend suite**: 1024 passed. That is the 958 from before plus
  these 66.
- **Lint and types**: `ruff check` and `ruff format --check` are clean on
  `app` and `tests`. `mypy` reports the same 4 errors as at `HEAD`, all in
  files this bolt did not touch.
- **Falsification**: nine deliberate breakages, and every one was caught.
  A tenth only showed that one check is backed up by another (see below).
- **Isolation**: every file lands in a pytest temporary folder. Settings are
  built with `_env_file=None`, so the developer's `.env`, which holds R2
  keys, cannot decide which store a test gets. `backend/media` and `dev.db`
  were not touched.

### Test Files

- [x] `backend/tests/unit/test_local_audio_storage.py`
  - **Links**
    - A link has the same shape as an R2 one: an absolute `PUT` address on
      this backend, a `Content-Type` header to send, a `/media/audio/{key}`
      address, and `expires_in` of 600.
    - It carries type, size, expiry and a 64-hex signature, and never the
      secret.
    - A fresh link verifies, and is still valid at its last second.
    - It expires one second later (`upload_link_expired`).
    - An altered type, size or signature is `invalid_upload_link`, not the
      expired error.
    - A pushed-back expiry is also `invalid_upload_link`, not a live link.
    - A link for one key does not open another.
    - A link from another process (another secret) is refused.
  - **Keys**
    - Real key shapes pass.
    - 13 bad ones fail: `..` traversal, absolute paths, backslashes, extra
      folders, a short or uppercase id, the wrong extension, a trailing
      slash, uppercase language, spaces and empty.
    - A bad key never becomes a path.
  - **Saving**
    - Writes the exact bytes.
    - Never replaces a saved file.
    - Leaves no temporary file.
    - Losing a race for the name (forced) keeps the winner's bytes and
      cleans up.
    - A bad key is refused before the disk is touched.
  - **Choosing a store**
    - Local development without R2 gives this backend, with the base URL's
      trailing slash stripped. Every link in one process is signed alike.
    - `production`, `staging` or `preview` without R2 gives none.
    - R2 wins whenever it is fully configured, locally or deployed.
    - Half-configured R2 falls back to local.
- [x] `backend/tests/integration/test_local_audio_upload.py`
  - **Uploading**
    - The admin endpoint's link points at this backend and its address at
      `/media/audio/...`.
    - An upload with no bearer token, only the link, is saved and plays back
      byte for byte from its address.
    - That address saves onto a real seeded listening exercise, and the tree
      then reports its audio as `local`.
    - mp3, webm (with a codecs parameter) and ogg uploads work too.
  - **Refusals**, each leaving the media folder unchanged:
    - altered signature `403`
    - link moved to another key `403`
    - expired link `403 upload_link_expired`
    - wrong `Content-Type` `422 content_type`
    - short, long, 50-times-larger and empty bodies `422 size`
    - the same link used twice `409 audio_file_exists`, first file intact
    - four keys this backend never issues `404`, and nothing written
      outside the folder
  - **Which store**
    - Once the server is deployed without R2, uploads answer `503` and a
      link signed earlier finds the route closed (`404`).
    - Once R2 is configured, uploads go to R2 and the local route closes.
  - **The app**
    - `create_app` registers the route and, locally, serves `/media` before
      the folder exists.
    - Deployed with no media folder, it serves none.

### Falsification

Each breakage was applied to the source, the two new test files were run,
and the source was restored byte for byte, confirmed with `cmp`:

| Breakage | Result |
|---|---|
| Expiry not checked | 2 fail |
| Signature not checked | 8 fail |
| Content type not checked | 1 fails |
| Size only capped, not matched | 2 fail (the short and empty bodies) |
| Save overwrites (`os.replace` instead of the link) | 4 fail |
| Any key accepted | 18 fail |
| Local store in production | 4 fail |
| Local preferred over R2 | 3 fail |
| Type left out of the signature | 1 fails |

One more breakage was tried: removing only the `exists()` pre-check. It
failed no test, and that is correct: the hard link still refuses to replace
a file, and that link is the real guard. The `os.replace` row is the fair
version of this breakage.

### Acceptance Criteria Validation

- ✅ **Local, no R2: a signed 10-minute link to this backend, with the same
  shape as R2 and `public_url` `/media/audio/{key}`**:
  `TestUploadingLocally`, `TestLinks`
- ✅ **The exact file is written and served at `/media/audio/{key}`**:
  upload and play back, byte for byte
- ✅ **Expired, altered, wrong type or size, or an existing key: nothing
  written**: `TestRefusals`
- ✅ **No key can write outside `media/audio/`**: `TestKeys` and the four
  `404` cases
- ✅ **Not local, no R2: still `503`**: `TestWhichStore` and `TestChoosing`
- ✅ **R2 configured: R2 is used**: same
- ✅ **The returned address saves on an exercise locally**: the seeded
  listening exercise, now reported as `local` audio

### Issues Found

- **None in the code.** One test assumption was wrong: this FastAPI version
  (0.141) nests included routers, so `app.routes` does not list them. The
  test now asks the OpenAPI schema instead.

### Notes

- **Real browser upload still to prove.** The browser-to-backend upload
  (CORS preflight, recording types) will be proven in bolt 039, when the
  admin site records and uploads. CORS already allows any `localhost` origin
  and every method and header in local development.
