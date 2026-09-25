---
id: 001-picture-upload-with-shrinking
unit: 002-image-choice-admin
intent: 019-image-choice-exercise-types
status: draft
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 052-image-choice-admin
implemented: false
---

# Story: 001-picture-upload-with-shrinking

## User Story

**As a** content admin
**I want** to pick any photo or drawing and have it shrunk and uploaded for me
**So that** I never have to resize pictures myself, and lessons stay light on data

## Acceptance Criteria

- [ ] **Given** a JPEG, PNG or WebP file up to 10 MB, **When** picked, **Then** it is scaled so its longest side is at most 512 px, never scaled up, and encoded as WebP, or as JPEG where the browser cannot encode WebP
- [ ] **Given** a 4000×3000 JPEG, **When** picked, **Then** the upload is at most 512×384 and at most 300 KB
- [ ] **Given** an encoding over 300 KB, **When** shrinking, **Then** quality is lowered step by step until it fits
- [ ] **Given** a file that is not a picture, or is over 10 MB, **When** picked, **Then** it is refused with a message and nothing is uploaded
- [ ] **Given** a shrunk picture, **When** uploaded, **Then** the site asks for a link, PUTs the bytes, and returns the picture's URL; a failure shows a message and keeps the slot's previous picture
- [ ] **Given** the site's tests, **When** run, **Then** shrinking, the limits and the upload call are covered

## Technical Notes

- Follows `admin/src/audio/upload.ts` for the link and PUT.
- Shrinking uses a canvas (`createImageBitmap`, `toBlob`); checking `toBlob('image/webp')`'s result type detects missing WebP support.

## Dependencies

### Requires
- 002-picture-upload-links (unit 001)

### Enables
- 002-picture-question-editors-and-preview

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A 300×200 picture | Uploaded at 300×200, not enlarged |
| A PNG with transparency, encoded as JPEG | Drawn on white first |
| A phone photo with an EXIF rotation | Shown upright |

## Out of Scope

- Cropping
