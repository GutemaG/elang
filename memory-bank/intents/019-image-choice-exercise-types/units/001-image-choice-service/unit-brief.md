---
unit: 001-image-choice-service
intent: 019-image-choice-exercise-types
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-09-25T06:15:00Z'
updated: '2026-09-25T13:43:28Z'
---

# Unit Brief: Image Choice Service

## Purpose

Store, validate and serve the two picture question types, give admins a
safe way to upload pictures, and seed sample questions with free-licensed,
credited pictures.

## Scope

### In Scope
- `ExerciseType.IMAGE_CHOICE` and `AUDIO_IMAGE_CHOICE`, their content value
  objects and field-level validation
- A migration widening `ck_exercises_type`
- Repository reconstruction, response schema and mapping
- `POST /admin/images/uploads` and local picture storage at `/media/images`
- Sample pictures, their credits file, and a local-only seed

### Out of Scope
- The admin site (unit 002) and the app (unit 003)
- Running the migration or the seed on Neon, uploading to production R2,
  and changing R2 CORS: each waits for the owner's go-ahead
- Cleaning up replaced pictures (left in storage, as audio is)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Image choice content type | Must |
| FR-2 | Audio image choice content type | Must |
| FR-3 | Picture storage: the link and storage | Must |
| FR-8 | Sample content: pictures, credits and seed | Must |

Performance, security and compatibility NFRs apply.

---

## Key Entities

| Entity | Shape |
|--------|-------|
| Picture choice | `{id, image_url, alt_text}`; id unique in the question, url and alt text non-empty |
| `ImageChoiceContent` | `prompt`, 2 to 4 picture choices |
| `AudioImageChoiceContent` | `instruction`, `audio_url`, 2 to 4 picture choices |
| Answer key | `ChoiceAnswerKey(correct_choice_id)`, naming one of the choices |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 3 |
| Must Have | 3 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-picture-question-content-types | Store and serve both picture question types | Must | Complete (bolt 050) |
| 002-picture-upload-links | Upload links and local storage for pictures | Must | Complete (bolt 050) |
| 003-sample-picture-questions | Sample questions with free-licensed, credited pictures | Must | Complete (bolt 051) |

---

## Dependencies

### Depends On
None: extends the lesson service and admin API in place.

### Depended By
`002-image-choice-admin`, `003-image-choice-ui`

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Cloudflare R2 | Picture storage in production | Low: same bucket and signing as audio |
| OpenMoji, Twemoji or Wikimedia Commons | Sample pictures, build time only | Low: licence recorded per picture |

---

## Constraints

- Picture URLs follow the audio rule: https, or `/media/images/...` only
  when local media is allowed.
- Keys follow the audio layout, `{language}/{lesson_id}/{token}.{ext}`,
  with `webp` or `jpg`.
- The seed is insert-only and refuses any database but SQLite, like
  `seed_local_audio.py`.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 050-image-choice-service | simple-construction-bolt | 001, 002 | The contract both clients build against |
| 051-image-choice-samples | simple-construction-bolt | 003 | Real sample questions to build and check the clients with |
