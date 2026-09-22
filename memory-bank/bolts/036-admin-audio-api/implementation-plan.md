---
stage: plan
bolt: 036-admin-audio-api
created: '2026-09-22T14:00:00Z'
---

## Implementation Plan: content-admin-api

### Objective

The backend gives the admin site two ways to get audio into a listening
exercise, and the R2 keys never leave the server:
1. **Upload:** a short-lived signed upload link to R2, for a recording or a
   file.
2. **Link:** a checked audio link that the admin pasted.

The admin site then saves the resulting https address as the exercise's
`audio_url` through the existing `PUT /exercises/{id}`, which already
refuses anything that is not `https://`.

### What the code and setup showed

1. **No S3 client exists in the backend, and adding boto3 is heavy.** A
   presigned PUT is one SigV4 signature: an HMAC chain over a canonical
   request. That is roughly 60 lines using only the standard library. Since
   the backend deploys to Vercel as a serverless function, I will **write
   the presigner rather than add boto3/botocore**. It can be verified
   exactly against AWS's published SigV4 query-signing test vector.
2. **The upload can't be tied to an exercise id.** A new listening exercise
   cannot be created without an `audio_url`, because validation requires
   one. So the audio has to exist first. The upload is therefore keyed by
   the **lesson**, which always exists.
3. **The R2 settings exist only in `backend/.env`**, and the current comment
   in `.env.example` says "never on Vercel". That comment is now wrong: to
   presign, the deployed backend needs the keys. They stay server-side
   environment variables, and are never sent to the browser.
4. **`httpx` is already a dependency** (the Apple verifier uses it), so the
   link check needs nothing new.
5. **The R2 public address still returns 404.** I checked again just now.
   Uploads can be proven through the S3 API, but "plays from its public
   URL" cannot be verified until the bucket's public access is fixed.

### Deliverables

**`POST /api/v1/admin/audio/uploads`**
- **Request**: `{lesson_id, content_type, size}`.
- **Response**: `{upload_url, method: "PUT", headers: {"Content-Type": ...},
  key, public_url, expires_in}`.
- **The key** is built by the backend and is ASCII only:
  `{learning_language}/{lesson_id}/{random 12 hex}.{ext}`, e.g.
  `am/1c9e…/a41f0c2b7d19.m4a`. The language is the lesson's course's
  learning language; the extension comes from the content type.
- **Allowed types**: `audio/mp4` and `audio/x-m4a` (`.m4a`), `audio/mpeg`
  (`.mp3`), `audio/webm` (`.webm`), `audio/ogg` (`.ogg`). Anything else
  returns `422 content_type`.
- **Size**: 1 byte to 5 MB. Anything else returns `422 size`.
- **What is signed**: `host`, `content-type` and `content-length`. The
  browser must therefore send exactly that type and exactly that size, so
  the link cannot be reused for a different or larger file.
- **Expiry**: 10 minutes.
- **Not configured**: if `AUDIO_BASE_URL` or any `R2_*` setting is missing,
  the response is `503 audio_storage_not_configured`.
- **Logging**: one `admin_write action=presign entity=audio id=<key>` line.

**`POST /api/v1/admin/audio/links`**
- **Request**: `{url}`. **Response**: `{url, content_type}` when the link is
  acceptable.
- **The checks, in order:**
  1. The link is `https://` with a host.
  2. Every address the host resolves to is public. Loopback, private,
     link-local and reserved addresses are refused, which blocks SSRF.
  3. A `HEAD` request is sent with a 5 s timeout. If the server refuses
     `HEAD`, it falls back to a `GET` of the first byte only
     (`Range: bytes=0-0`).
  4. Up to 3 redirects are followed by hand, and every redirect target is
     checked again.
  5. The response must be 2xx with an `audio/*` content type.
- **Refusals** return `422 invalid_audio_link`, with the reason in
  `details.reason`: `not_https`, `private_address`, `unreachable`,
  `timeout`, `bad_status` or `not_audio`.

**Code**
- `app/infrastructure/external/r2_storage.py`: an `R2Settings` object read
  from config, and `presign_put(...)`, pure SigV4 using `hmac`/`hashlib`
  from the standard library.
- `app/infrastructure/external/audio_link_checker.py`: the checker, using
  `httpx.AsyncClient` with an injectable transport so tests never touch the
  network, and an injectable resolver for the address check.
- `app/application/admin_audio_use_cases.py`: validation, key building and
  logging.
- Two routes added to `admin_routers.py`, still behind the router-level
  admin guard.
- `app/config.py`: `audio_base_url`, `r2_account_id`, `r2_bucket`,
  `r2_access_key_id` and `r2_secret_access_key`.
- `.env.example`: the R2 comment is corrected, to "set on Vercel too; these
  sign upload links on the server and are never sent to the browser".
- **R2 CORS rule** for bucket `ethio-lang`, documented in the walkthrough
  for you to paste into R2 → Settings → CORS:
  - allow `PUT` from the admin site's origin and `http://localhost:5173`
  - allowed header `content-type`

### Dependencies

- `httpx`, which is already present. No new packages.
- R2 credentials, which are already in your local `.env`. On Vercel they are
  set when you deploy the admin site (Operations).

### Technical Approach

- **Endpoint**: the presigned URL is
  `https://{account}.r2.cloudflarestorage.com/{bucket}/{key}`, path-style,
  with region `auto` and service `s3`.
- **Checking the presigner with no network:**
  1. A unit test reproduces AWS's documented presigned-URL example exactly.
     That example uses fixed credentials, a fixed date and a known expected
     signature.
  2. A second test checks that our signed headers include `content-type`
     and `content-length`.
- **Live check, which needs your OK:** in Stage 3 I would like to prove the
  real round trip against your bucket:
  1. Presign a 1 KB test clip.
  2. `PUT` it.
  3. Confirm it exists through the S3 API.
  4. Confirm a wrong size is refused.
  5. Delete the clip.

  This writes to, and then cleans up, your `ethio-lang` bucket.
- **DNS rebinding:** the address check resolves the host once. A host that
  resolves to a different address between the check and the request is a
  residual risk. It is accepted for an admin-only endpoint used by one to
  three trusted people, and it is recorded rather than engineered away.

### Acceptance Criteria

- [ ] An upload request returns a PUT link valid for 10 minutes or less, an
  ASCII key under the language folder, and `public_url = AUDIO_BASE_URL/key`
- [ ] A disallowed content type returns `422 content_type`; a size of 0 or
  over 5 MB returns `422 size`; an unknown lesson returns 404
- [ ] The presigner matches AWS's published SigV4 query-signing example
  exactly
- [ ] The signature binds `content-type` and `content-length`
- [ ] Missing R2 or `AUDIO_BASE_URL` settings return 503; no response and no
  log line ever contains the access key secret
- [ ] Link check: an https audio link is accepted
- [ ] Link check: `http://` returns `not_https`; a private or loopback
  address returns `private_address`; a non-audio response returns
  `not_audio`; errors and slow hosts return `unreachable` / `timeout`; a
  redirect to a private address is refused
- [ ] Both endpoints return 403 for a non-admin (covered automatically by the
  existing route-parametrized access test)
- [ ] With your OK: a real presigned PUT to `ethio-lang` succeeds, a
  wrong-size PUT is refused, and the test object is deleted
- [ ] The full suite is green and ruff is clean
