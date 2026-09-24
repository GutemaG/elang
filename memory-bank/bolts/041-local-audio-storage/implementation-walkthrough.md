---
stage: implement
bolt: 041-local-audio-storage
created: '2026-09-24T07:30:00Z'
---

## Implementation Walkthrough: content-admin-api

### Summary

Without R2, in local development, `POST /admin/audio/uploads` now hands out a
signed link to the backend itself instead of answering `503`. The file is
saved under `backend/media/audio/{key}` and plays from `/media/audio/{key}`.
With R2 configured, nothing changes. The admin site sees the same response
either way.

### Structure Overview

- **One chooser, `choose_audio_storage`.** It picks the store for both the
  endpoint that hands out links and the endpoint that receives uploads, so
  the two cannot disagree. The order is: R2 if fully configured; else the
  local store if `environment == "local"`; else nothing, which is `503` as
  before.
- **The receiving route sits outside the admin router.** The upload request
  carries no bearer token, just like an R2 presigned link, so the admin site
  uploads the same way to either store.

### Completed Work

- [x] `backend/app/infrastructure/media.py` — `MEDIA_DIR`, `AUDIO_DIR` and
  their URL prefixes, in one place. They moved out of `main.py`, which still
  re-exports `MEDIA_DIR` for the existing tests.
- [x] `backend/app/infrastructure/external/local_audio_storage.py`:
  - `LocalAudioStorage.presign_put` returns the same `PresignedUpload` as R2.
  - `verify` checks the signature before the expiry, in constant time.
  - `save` writes a temporary file, then hard-links it into place, so it
    never overwrites and never leaves half a file.
  - Also here: `KEY_PATTERN`, `choose_audio_storage`, and a signing secret
    that is random per process.
- [x] `backend/app/infrastructure/api/audio_file_routers.py` —
  `PUT /api/v1/audio-files/{key}`. It checks, in order:
  - the local store is active and the key has the right shape (`404`
    otherwise)
  - the signature and expiry (`403`)
  - the sent `Content-Type` (`422`)
  - the body size, reading at most the signed size (`422`)
  - that no file already has that name (`409`)
- [x] `backend/app/application/admin_audio_use_cases.py` — an `AudioStore`
  protocol, so the use case no longer names R2.
- [x] `backend/app/infrastructure/api/admin_routers.py` —
  `get_audio_storage` now uses the chooser, with the request's own base URL
  for the link.
- [x] `backend/app/domain/lesson/exceptions.py` and `error_handlers.py` —
  three new errors: `invalid_upload_link` (403), `upload_link_expired`
  (403) and `audio_file_exists` (409).
- [x] `backend/app/main.py` — registers the new route. Locally it mounts
  `/media` even before the folder exists (`check_dir=False`), because the
  first upload creates it.

### Key Decisions

- **Relative addresses (`/media/audio/...`).** The Flutter app resolves them
  against whichever backend it talks to, so they survive a laptop IP change
  or a tunnel. A tunnel's URL would change on every restart and break every
  saved clip.
- **The same key layout as R2.** Moving to R2 later means copying each file
  under the same key, then replacing `/media/audio/` with `AUDIO_BASE_URL/`
  in stored exercises.
- **A per-process secret.** There is no new setting to configure. Links last
  10 minutes, so a restart only voids links nobody is using. This assumes one
  process, which is how local development runs.
- **A bad key shape answers `404`, not `403`.** It is not an address this
  backend ever issues.

### Deviations from Plan

None. As planned, `invalid_upload_link` and `upload_link_expired` are
separate codes (the second subclasses the first), so the admin site can say
"ask for a new link" in both cases.

### Dependencies Added

None.

### Developer Notes

- **Checks:**
  - `ruff check` and `ruff format --check` are clean.
  - `mypy` reports the same 4 errors as at `HEAD`, all in files this bolt
    did not change, and none from this bolt.
  - The existing suite passes: **958 passed**.
- **Smoke run** against a temporary folder (not `backend/media`, not
  `dev.db`):
  - An upload returned `201` and the bytes on disk matched.
  - Every refusal answered as planned: repeat `409`, altered signature
    `403`, wrong size `422 size`, wrong type `422 content_type`, traversal
    `404`.
  - Only the one good file was written.
  - The chooser gives the local store with `local` and no R2, and `None`
    with `production` and no R2.
- **For bolt 039:** the admin site must resolve a relative `public_url`
  against `VITE_API_BASE_URL` to play it back.
