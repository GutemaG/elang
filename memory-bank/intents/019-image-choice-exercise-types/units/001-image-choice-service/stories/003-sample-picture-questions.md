---
id: 003-sample-picture-questions
unit: 001-image-choice-service
intent: 019-image-choice-exercise-types
status: complete
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 051-image-choice-samples
implemented: true
---

# Story: 003-sample-picture-questions

## User Story

**As the** owner
**I want** real sample picture questions in the Amharic course, using free-licensed pictures that are properly credited
**So that** both types can be seen and tested end to end before authors write their own

## Acceptance Criteria

- [x] **Given** the sample words, **When** pictures are chosen, **Then** each is CC0, CC BY or CC BY-SA, and its source URL, author and licence are recorded in a committed credits file
- [x] **Given** each chosen picture, **When** processed, **Then** it is at most 512 px on its longest side, WebP or JPEG, and at most 300 KB
- [x] **Given** the pictures, **When** committed, **Then** they live in a tracked folder, since `backend/media` is git-ignored
- [x] **Given** a local SQLite database, **When** the sample seed runs, **Then** it adds at least 3 `image_choice` and 2 `audio_image_choice` questions to the English to Amharic course, copying the pictures into `backend/media/images/`
- [x] **Given** each sample question, **When** seeded, **Then** it is linked to a vocabulary word that has no other question, so practice shows it
- [x] **Given** the seed, **When** re-run, **Then** it adds nothing twice; **When** pointed at any database but SQLite, **Then** it refuses
- [x] **Given** production, **When** this story is done, **Then** nothing has been uploaded to R2 or written to Neon; both wait for the owner's go-ahead

## Technical Notes

- Follows `seed_local_audio.py`: a local-only section of the English to Amharic course. The audio questions can reuse its recorded clips.
- The picture set is chosen at Plan, by licence and fit (OpenMoji CC BY-SA 4.0, Twemoji CC BY 4.0 or Wikimedia Commons), and recorded in the credits file.
- The credits file's format should be easy for the app to read (story 005 of unit 003).

## Dependencies

### Requires
- 001-picture-question-content-types
- 002-picture-upload-links (the local images folder and URL prefix)

### Enables
- 005-picture-credits-in-the-app (unit 003)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A picture that needs no attribution (CC0) | Still listed in the credits file |
| A distractor picture | Credited like any other |

## Out of Scope

- Seeding the other three courses
