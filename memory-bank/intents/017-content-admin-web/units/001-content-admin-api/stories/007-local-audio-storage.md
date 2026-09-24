---
id: 007-local-audio-storage
unit: 001-content-admin-api
intent: 017-content-admin-web
status: complete
priority: must
created: '2026-09-24T07:09:11Z'
assigned_bolt: 041-local-audio-storage
implemented: true
---

# Story: 007-local-audio-storage

## User Story

**As a** Buna admin working locally before R2 is ready
**I want** recordings I upload to be saved and served by the local backend
**So that** I can build listening exercises now and move the clips to R2 later without changing the admin site

## Acceptance Criteria

- [ ] **Given** R2 is not configured and `ENVIRONMENT=local`, **When** `POST /admin/audio/uploads` is called, **Then** it returns a signed `PUT` link to the backend itself, valid for 10 minutes, with the same response shape as R2 and `public_url` = `/media/audio/{key}`
- [ ] **Given** that link, **When** the exact file (that content type, that size) is `PUT` to it, **Then** it is written to `backend/media/audio/{key}` and served at `/media/audio/{key}`
- [ ] **Given** an expired link, an altered signature, key, type or size, a body of a different length, or a key that already exists, **When** it is `PUT`, **Then** nothing is written and it is refused
- [ ] **Given** a key that is not `{language}/{lesson}/{12 hex}.{ext}`, **When** it is `PUT`, **Then** it is refused, so no upload can write outside `media/audio/`
- [ ] **Given** `ENVIRONMENT` is not `local` and R2 is not configured, **When** an upload is requested, **Then** it still returns `503`
- [ ] **Given** R2 is configured, **When** an upload is requested, **Then** R2 is used, whatever the environment
- [ ] **Given** the admin saves the exercise with the returned `/media/audio/...` address, **When** validation runs locally, **Then** it is accepted (as it already is for `/media/` paths)

## Technical Notes

- Keys match R2's layout, so moving to R2 later is: copy each file to the bucket under the same key, then rewrite `/media/audio/` to `AUDIO_BASE_URL/` in stored exercises.
- The signing secret is random per backend process: links last 10 minutes, so a restart only invalidates links nobody is using.
- The `PUT` is authorised by its signature, like an R2 presigned link, not by the admin's bearer token, so the admin site's upload code is the same for both stores.

## Dependencies

### Requires
- 005-audio-upload-and-link-api

### Enables
- 004-audio-record-upload-link (unit 002)
