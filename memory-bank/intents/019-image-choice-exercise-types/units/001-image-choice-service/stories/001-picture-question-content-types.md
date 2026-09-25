---
id: 001-picture-question-content-types
unit: 001-image-choice-service
intent: 019-image-choice-exercise-types
status: complete
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 050-image-choice-service
implemented: true
---

# Story: 001-picture-question-content-types

## User Story

**As a** content admin
**I want** the backend to store and serve questions whose answers are pictures
**So that** learners can be taught concrete words by meaning, not only by translation

## Acceptance Criteria

- [x] **Given** an `image_choice` question with a prompt and 2, 3 or 4 choices of `{id, image_url, alt_text}`, **When** it is saved through the admin API, **Then** it saves, and the lesson API returns it with the same content
- [x] **Given** an `audio_image_choice` question with an instruction, an `audio_url` and 2 to 4 picture choices, **When** saved, **Then** it saves and the lesson API returns it
- [x] **Given** either type with fewer than 2 or more than 4 choices, a repeated choice id, an empty `image_url`, an empty `alt_text`, or an answer key naming no choice, **When** saved, **Then** it is refused with a `422` naming the field (for example `content.choices[2].alt_text`)
- [x] **Given** an `audio_image_choice` with no `audio_url`, **When** saved, **Then** it is refused with a `422` on `content.audio_url`
- [x] **Given** an `image_url`, **When** validated, **Then** it follows the audio rule: a full https address, or a `/media/images/...` path only where local media is allowed
- [x] **Given** the database, **When** the new migration runs on SQLite, **Then** `exercises.type` accepts both new types, and the migration downgrades cleanly
- [x] **Given** a vocabulary word whose only linked question is a picture question, **When** it is due, **Then** `GET /practice/due-items` returns that question
- [x] **Given** the other six types, **When** the backend suite runs, **Then** their tests pass unchanged

## Technical Notes

- Seams are listed in `system-context.md`. Both types reuse `ChoiceAnswerKey`; there is no new `AnswerKey` member.
- A picture-choice check sits beside `_check_tiles` in `exercise_parts.py`, with `_CONTENT_KEYS` entries for both types.
- `database-schema.md` gains the two content shapes.
- The Neon migration is not run here; it waits for the owner's go-ahead.

## Dependencies

### Requires
- None

### Enables
- 002-picture-upload-links
- 003-sample-picture-questions
- Units 002 and 003

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A prompt in `Instruction: 'word'` form | Stored as given; the app splits it |
| Alt text of only spaces | Refused as empty |
| An extra key in a choice | Refused, naming the key |

## Out of Scope

- The upload link (story 002)
