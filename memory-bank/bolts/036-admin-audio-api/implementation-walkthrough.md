---
stage: implement
bolt: 036-admin-audio-api
created: '2026-09-22T14:40:00Z'
---

## Implementation Walkthrough: content-admin-api

### Summary

The admin API gains two audio endpoints:
- **`POST /audio/uploads`** returns a 10-minute presigned R2 PUT link for one
  lesson's clip. The link is bound to the exact content type and size, and
  comes with the address the clip will have once uploaded.
- **`POST /audio/links`** checks that a pasted https link answers with audio,
  refusing private addresses and following redirects safely.

The presigner is written with the standard library. No new dependencies.

### Structure Overview

- **Two infrastructure adapters:**
  - the R2 presigner: a generic SigV4 query signer, plus a bucket wrapper
    read from settings
  - the link checker: httpx with an injectable transport and resolver
- **One use-case module** for the input rules, the key naming and the audit
  line.
- **Two routes on the existing admin router.** They sit behind the same
  router-level admin guard, so the route-parametrized access test from bolt
  035 already covers them.

### Completed Work

- [x] `backend/app/infrastructure/external/r2_storage.py` - new:
  - the SigV4 presigner
  - `R2Storage`, built from settings, which is absent unless every setting
    is present
  - `presign_put`, which signs host, content type and content length
- [x] `backend/app/infrastructure/external/audio_link_checker.py` - new:
  - checks, in order: https only, public addresses only, `HEAD` with a
    ranged `GET` fallback, up to 3 redirects each checked again, 5 s
    timeout, `audio/*` only
  - every refusal carries a reason
- [x] `backend/app/application/admin_audio_use_cases.py` - new:
  - the allowed types and their extensions, and the 5 MB limit
  - the key `{language}/{lesson_id}/{random}.{ext}`
  - one `admin_write action=presign` line per link
- [x] `backend/app/infrastructure/db/admin_content_repository.py` - finds
  the lesson's course language, which becomes the key's folder
- [x] `backend/app/infrastructure/api/admin_routers.py` - the two routes,
  plus overridable dependencies for the storage and the checker
- [x] `backend/app/infrastructure/api/admin_schemas.py` - upload and link
  request/response schemas
- [x] `backend/app/domain/lesson/exceptions.py` - `InvalidAudioLinkError`
  (422, with a reason) and `AudioStorageNotConfiguredError` (503)
- [x] `backend/app/infrastructure/api/error_handlers.py` - both mapped
- [x] `backend/app/config.py` - `audio_base_url` and the four `r2_*`
  settings
- [x] `backend/.env.example` - the R2 comment now says to set the keys on
  Vercel too, server-side only

### Key Decisions

- **SigV4 by hand, not boto3**: this keeps botocore out of the Vercel
  function.
  - It is checked against AWS's published presigned-URL example. The
    example's expected signature is reproduced exactly (verified already
    during implementation; the Stage 3 test pins it).
- **The signature binds `content-length`**: a link issued for a 40 KB
  recording cannot be used to upload a 5 GB file. The browser sets
  `Content-Length` from the body itself, so only `Content-Type` is returned
  as a header to send.
- **The key uses the lesson id and a random suffix, not a slug**: admin-made
  lessons have no slug. The random part means re-recording never overwrites
  a clip that a phone may have cached.
- **The storage is `None` rather than raising at startup**: the rest of the
  API works on a server without R2 settings, and only uploads answer 503.

### Deviations from Plan

None.

### Dependencies Added

None.

### Developer Notes

- **R2 CORS rule** for bucket `ethio-lang`. Paste it in R2 → ethio-lang →
  Settings → CORS policy, and add the admin site's real origin once it is
  deployed (bolt 037):

  - AllowedOrigins: `http://localhost:5173` and the admin site's origin
  - AllowedMethods: `PUT`
  - AllowedHeaders: `content-type`
  - MaxAgeSeconds: `3600`

- **The public URL is still broken.** It returned 404 when checked at plan
  time, so clips uploaded now will not play until the bucket's public access
  is fixed.
- **Checks run at this stage:** the admin and unit suites pass (593), and
  ruff is clean. The two new routes already appear in the admin-only access
  test and return 403 for a non-admin.
