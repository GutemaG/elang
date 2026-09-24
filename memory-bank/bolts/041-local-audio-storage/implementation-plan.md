---
stage: plan
bolt: 041-local-audio-storage
created: '2026-09-24T07:09:11Z'
---

## Implementation Plan: content-admin-api

### Objective

Audio can be saved and played now, before R2 serves files, without the admin
site needing to know which store it is using. Moving to R2 later is a
settings change plus a copy-and-rewrite script, not a code change.

### What the code showed

1. **Serving already works.** `main.py` mounts `backend/media` at `/media`
   (git-ignored, so absent when deployed). The four Audio Lab clips are
   stored as `/media/audio/am/hello.m4a` and so on.
2. **The app already plays such paths.** `http_lesson_api.dart` resolves
   `audio_url` against its own API base, so a phone pointed at this backend
   plays `/media/...` clips.
3. **Validation already accepts them locally.** `_is_allowed_audio_url`
   allows `/media/` paths when `environment == "local"`.
4. **Only saving is missing.** `POST /admin/audio/uploads` answers `503`
   unless every R2 setting is present.

### Deliverables

- **`LocalAudioStorage`** (`app/infrastructure/external/local_audio_storage.py`):
  - `presign_put(key, content_type, size, expires_in)` returns the same
    `PresignedUpload` as R2: a link to `PUT /api/v1/audio-files/{key}` with
    `type`, `size`, `expires` and an HMAC-SHA256 `sig` in the query, the
    header `Content-Type` to send, and `public_url` `/media/audio/{key}`.
  - `verify(...)` checks the signature in constant time and the expiry.
  - `save(key, body)` writes atomically (temp file, then rename) and never
    overwrites.
- **The receiving route** `PUT /api/v1/audio-files/{key:path}`, outside the
  admin router, since the link carries no bearer token (same as R2). It:
  - checks the key against `^[a-z]{2,3}/[A-Za-z0-9_-]{1,64}/[0-9a-f]{12}\.(m4a|mp3|webm|ogg)$`
  - verifies the signature and expiry
  - requires the request's `Content-Type` to match the signed type
  - reads at most the signed size plus one byte, and requires exactly the
    signed size
  - answers `201` with `{key, public_url}`
- **Store selection** in `get_audio_storage()`: R2 when fully configured;
  otherwise local when `environment == "local"`; otherwise `None` (`503`, as
  today).
- **The upload link must be absolute** for the browser, so it is built from
  the request's own base URL.

### Refusals

| Case | Answer |
|---|---|
| Bad key shape (for example `../`, or a missing hex id) | `404`, as for any unknown path |
| Bad or altered signature | `403 invalid_upload_link` |
| Expired link | `403 upload_link_expired` |
| `Content-Type` differs from the signed type | `422` |
| Body size differs from the signed size | `422` |
| File already exists | `409` |
| Local store not active (not local, or R2 configured) | `404` |

### Out of scope

- The admin site's record/upload screens (bolt 039).
- The script that moves clips to R2 (written when R2 serves files).

### Tests (Stage 3)

- Unit: sign and verify round trip; tampered key, type, size or expiry;
  expired; key pattern accepts real keys and rejects traversal.
- Integration over HTTP: presign then `PUT` then `GET /media/...` returns the
  same bytes; each refusal above writes nothing; store selection (local
  env, deployed env, R2 configured).
- Existing suite stays green.
