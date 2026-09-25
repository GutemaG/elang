---
id: 002-picture-upload-links
unit: 001-image-choice-service
intent: 019-image-choice-exercise-types
status: complete
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 050-image-choice-service
implemented: true
---

# Story: 002-picture-upload-links

## User Story

**As a** content admin
**I want** to upload a picture straight to storage through a short-lived link
**So that** pictures are stored and served the same way as audio, without passing through the API server

## Acceptance Criteria

- [x] **Given** a signed-in admin, **When** they ask `POST /admin/images/uploads` for a lesson with `image/webp` or `image/jpeg` and a size of 1 byte to 1 MB, **Then** they get a PUT link bound to that type and exact size, expiring in 10 minutes, and the picture's public URL
- [x] **Given** any other type, a size of 0 or over 1 MB, or an unknown lesson, **When** asked, **Then** the request is refused with a field-level error or a `404`
- [x] **Given** someone who is not an admin, **When** they ask, **Then** they are refused, as for audio
- [x] **Given** a lesson, **When** a key is made, **Then** it is `{language}/{lesson_id}/{token}.webp` or `.jpg`
- [x] **Given** local development without R2, **When** a picture is uploaded, **Then** it is stored under `backend/media/images/` and served at `/media/images/...`
- [x] **Given** the production R2 bucket, **When** checked, **Then** whether it sends CORS headers for the web app is recorded; any change waits for the owner's go-ahead (recorded in bolt 050's walkthroughs: r2.dev answers no preflight and no existing object could be fetched, so the check is repeated once a picture is on R2; the README's policy lacks the Flutter web origin)

## Technical Notes

- Follows `admin_audio_use_cases.presign_upload`: the same store protocol, signing and audit log line, with its own type table and size limit.
- The local store and PUT route gain an images prefix beside audio.
- R2 keys never leave the server.

## Dependencies

### Requires
- 001-picture-question-content-types

### Enables
- 002-image-choice-admin

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| `image/png` requested | Refused: the admin site converts PNG before uploading |
| A PUT larger than the size signed | Refused by storage |

## Out of Scope

- Deleting replaced pictures
