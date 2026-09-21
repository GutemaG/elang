---
id: 005-audio-upload-and-link-api
unit: 001-content-admin-api
intent: 017-content-admin-web
status: generated
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 036-admin-audio-api
implemented: false
---

# Story: 005-audio-upload-and-link-api

## User Story

**As a** Buna admin
**I want** the server to give me a safe way to put recordings on R2, or to accept a link I already have
**So that** audio reaches learners without the R2 keys ever leaving the server

## Acceptance Criteria

- [ ] **Given** an exercise id, a content type and a size, **When** `POST /admin/audio/uploads` is called, **Then** it returns a presigned PUT URL valid for at most 10 minutes, the chosen ASCII key (e.g. `am/<lesson-slug>-<n>-<random>.m4a`) and the final public URL (`AUDIO_BASE_URL` + key)
- [ ] **Given** a content type outside `audio/mp4`, `audio/x-m4a`, `audio/mpeg`, `audio/webm`, `audio/ogg`, or a size over 5 MB, **When** it is requested, **Then** it returns `422`
- [ ] **Given** the upload completed, **When** the admin saves the exercise with the returned public URL, **Then** it is stored as `audio_url`
- [ ] **Given** a pasted URL, **When** `POST /admin/audio/links` is called, **Then** an `https://` URL that answers with an `audio/*` content type within 5 s is accepted; `http://`, non-audio, unreachable or slow URLs return `422` with a readable reason
- [ ] **Given** any response or log line, **When** it is inspected, **Then** no R2 access key or secret appears
- [ ] **Given** `R2_*` or `AUDIO_BASE_URL` is unset, **When** an upload is requested, **Then** it returns `503` saying audio storage is not configured

## Technical Notes

- A new `app/infrastructure/external/r2_storage.py` behind a small port so tests use a fake. boto3 `generate_presigned_url('put_object', ...)` against the account's S3 endpoint.
- Content type and length must be part of the signature so the browser cannot upload something else.
- The link check must not become an SSRF hole: https only, no private or loopback IPs, a short timeout, and HEAD first with a ranged GET fallback.
- R2 bucket CORS (allow PUT from the admin origin) is configuration, not code; document the exact rule in the bolt's notes.

## Dependencies

### Requires
- 001-admin-authorization

### Enables
- 004-audio-record-upload-link
