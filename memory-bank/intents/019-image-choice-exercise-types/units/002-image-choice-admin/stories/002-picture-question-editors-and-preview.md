---
id: 002-picture-question-editors-and-preview
unit: 002-image-choice-admin
intent: 019-image-choice-exercise-types
status: draft
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 052-image-choice-admin
implemented: false
---

# Story: 002-picture-question-editors-and-preview

## User Story

**As a** content admin
**I want** an editor for each picture question type, with a preview
**So that** I can build picture questions and see them as a learner will, without a developer

## Acceptance Criteria

- [ ] **Given** "add exercise", **When** opened, **Then** it offers "Image choice" and "Audio image choice"
- [ ] **Given** the image choice editor, **When** opened, **Then** it has the prompt and 2 to 4 picture slots, each with a picture, its alt text and a "correct" marker
- [ ] **Given** the audio image choice editor, **When** opened, **Then** it has the instruction, the existing audio field (record, upload or link) and the same picture slots
- [ ] **Given** 4 slots, **When** the editor is shown, **Then** adding another is not offered; **Given** 2 slots, removing one is not offered
- [ ] **Given** a slot with no picture or no alt text, no slot marked correct, or no audio on the audio type, **When** saving, **Then** save is blocked and the reason shows beside the field
- [ ] **Given** a valid question of either type, **When** saved and reopened, **Then** it round-trips through the API unchanged
- [ ] **Given** the preview, **When** shown, **Then** it has the prompt, or the instruction and play button, above the pictures in a 2×2 grid
- [ ] **Given** the site's tests, **When** run, **Then** both editors, their blocking rules and the round trip are covered

## Technical Notes

- The picture slots are one editor used by both types, beside `ChoicesEditor.tsx`.
- Choice ids are made by the site, as for the other choice editors.
- A server `422` on a field shows beside that field, as for the other types.

## Dependencies

### Requires
- 001-picture-upload-with-shrinking

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| The correct slot is removed | No slot is marked correct, and save is blocked until one is |
| A picture fails to load in the preview | Its alt text shows in its place |

## Out of Scope

- Reordering slots by drag
