---
stage: test
bolt: 036-admin-audio-api
created: '2026-09-22T15:20:00Z'
---

## Test Report: content-admin-api

### Summary

- **Tests**: 958/958 passed across the full backend suite. That is 905
  before this bolt plus 53 new: 51 in the new files, and 2 more cases in the
  existing route-parametrized access test, which picked up the new routes by
  itself.
- **Lint**: `ruff check` and `ruff format --check` are clean.
- **Live check against R2**: passed, as approved. See below.

### Test Files

- [x] `backend/tests/unit/test_r2_presign.py`:
  - reproduces AWS's published SigV4 presigned-URL example **character for
    character**, signature included
  - the R2 URL is the account endpoint plus a bucket path
  - the signed headers are `content-length;content-type;host`, with region
    `auto` and a 600 s expiry
  - a different size or type changes the signature
  - the public URL is right, and the secret appears in neither the URL nor
    the repr
  - `from_settings` returns `None` when any of the five settings is blank
- [x] `backend/tests/unit/test_audio_link_checker.py`, using a mock transport
  and a fake resolver, so there is no network:
  - an https audio link is accepted, and content-type parameters are ignored
  - `http`, `ftp` and an empty host all give `not_https`
  - private, mixed, IPv6-loopback and cloud-metadata addresses give
    `private_address` **before any request is made**
  - a literal `127.0.0.1` is refused
  - an unknown host gives `unreachable`
  - a refused HEAD falls back to `GET` with `Range: bytes=0-0`
  - a safe redirect is followed
  - a redirect to a private address is refused **without requesting it**
  - too many redirects, a non-audio response, a 404, a timeout and a refused
    connection are each refused with their own reason
- [x] `backend/tests/integration/test_admin_audio_endpoints.py`, over HTTP
  with the storage and the checker swapped in through the router's
  dependency hooks:
  - **Upload link**:
    - the key pattern `am/<lesson>/<12 hex>.m4a` and the public URL are
      correct
    - it is a PUT, with the Content-Type header, a 600 s expiry, and the
      right host and path
    - the secret is absent from the response
    - every request gets its own key
    - the extension follows the type, including `audio/webm;codecs=opus`
  - **Refusals**: `video/mp4`, `text/plain`, `audio/wav` and an empty type
    give `422 content_type`; sizes 0, −1 and 5 MB + 1 give `422 size`.
    Exactly 5 MB is allowed.
  - **Other outcomes**:
    - an unknown lesson gives 404
    - unconfigured storage gives `503 audio_storage_not_configured`
    - one audit line is written with the key, and it never contains the
      secret
  - **Link check**: an accepted link is cleaned; `not_https`,
    `private_address` and `not_audio` are each returned as 422 with that
    reason

### Live check (bucket `ethio-lang`, approved at Plan)

I ran a scratch script, which is not committed, using the real
`backend/.env` credentials and **only this bolt's presigner**:

1. **PUT** 1 024 bytes to a presigned link → `200`
2. **HEAD** the object → `200`, length `1024`, type `audio/mp4`
3. **PUT** 1 000 bytes to a link signed for 1 024 → **`403`**
4. **PUT** with a different Content-Type → **`403`**
5. **HEAD** the wrong-size key → `404`: nothing was stored
6. **Public URL** of the uploaded clip → **`404`**: the bucket's public
   access is still not working (see Issues Found)
7. **DELETE** the test object → `204`
8. **HEAD** after delete → `404`: nothing was left behind
9. **Real link check** of the seed's placeholder clip → accepted as
   `audio/mpeg`
10. **Real link check** of an HTML page → `not_audio`

Steps 3 and 4 prove, on R2 itself, that the signature really binds size and
type.

### Acceptance Criteria Validation

- ✅ **PUT link valid ≤ 10 min, ASCII key under the language folder,
  `public_url = AUDIO_BASE_URL/key`**: `TestUploads`, plus live steps 1–2
- ✅ **Disallowed type or size → 422; unknown lesson → 404**: `TestUploads`
- ✅ **Matches AWS's published SigV4 example exactly**:
  `test_matches_aws_published_presigned_url_example`
- ✅ **Signature binds content-type and content-length**: unit tests, plus
  live steps 3–4 on R2
- ✅ **Missing settings → 503; the secret is never in a response or log**:
  `test_unconfigured_storage_is_503`, `test_logs_the_key_but_never_the_secret`
  and the presign unit tests
- ✅ **Link check accepts https audio; refuses http, private, non-audio,
  errors, slow hosts and redirects to private addresses**:
  `test_audio_link_checker.py`, `TestLinks`, plus live steps 9–10
- ✅ **Both endpoints 403 for a non-admin**: the route-parametrized
  `TestAccess` from bolt 035
- ✅ **Live round trip on `ethio-lang` succeeds, a wrong-size PUT is refused,
  and the test object is deleted**: live steps 1–8
- ✅ **Full suite green, ruff clean**: 958 passed

### Issues Found

- **The R2 public URL still returns 404** for an object that verifiably
  exists (live step 6). Uploading works; playing from the public address
  does not. Fix this in the Cloudflare dashboard: R2 → ethio-lang → Settings
  → Public Development URL → Enable, then use the exact address it shows as
  `AUDIO_BASE_URL`. It is outside this code, and it blocks bolt 039's
  on-phone check.
- **The admin site must send the Content-Type the API returns.** A browser
  records `audio/webm;codecs=opus`, while the link is signed for
  `audio/webm`. Live step 4 shows R2 refuses a mismatch, so the admin site
  must send the Content-Type the API returned, not the blob's own. This is a
  note for bolt 039.

### Notes

- **R2 CORS rule** still needs pasting before the browser can upload. See
  `implementation-walkthrough.md`.
- **No migration and no `dev.db` change.**
