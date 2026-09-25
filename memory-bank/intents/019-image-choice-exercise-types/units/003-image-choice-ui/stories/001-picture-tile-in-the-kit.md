---
id: 001-picture-tile-in-the-kit
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
status: complete
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 053-picture-tile-and-lesson
implemented: true
---

# Story: 001-picture-tile-in-the-kit

## User Story

**As a** Buna learner
**I want** picture answers to look and react like every other answer tile
**So that** picture questions feel like part of the same lesson

## Acceptance Criteria

- [x] **Given** `PictureTile`, **When** built, **Then** it has `AnswerTile`'s six states (idle, selected, correct, incorrect, used, disabled) with the same press, shelf, shake and colours, and the picture in place of the label
- [x] **Given** 2, 3 or 4 tiles, **When** laid out by the grid, **Then** they sit 2×2, three as two then one, every tile the same size and 12 px apart
- [x] **Given** any picture, **When** shown, **Then** it is fitted inside the tile without cropping and decoded at tile size
- [x] **Given** a picture still loading, **When** shown, **Then** the tile shows a quiet placeholder; **Given** one that fails, **Then** the tile shows its alt text and still takes a tap
- [x] **Given** a screen reader, **When** a tile is focused, **Then** it reads the alt text with the button and selected state
- [x] **Given** the gallery, **When** opened, **Then** it shows the tile in every state, and grids of 2, 3 and 4, with a loading and a failed picture
- [x] **Given** 320 and 360 px at 1.0× and 1.3× text, **When** laid out, **Then** nothing overflows and every tile is at least 48 px
- [x] **Given** the rules test, **When** run, **Then** it passes with no new allow-list entries

## Reference Design (FR-11 of intent 018)

- Fetched in Plan: Duolingo's picture-choice grid, and at least one other app's; record what is taken and adapted.

## Technical Notes

- In `lib/shared/widgets/exercise/`, sharing `AnswerTile`'s state styling rather than copying it.
- Tests use in-memory pictures so no network is needed.

## Dependencies

### Requires
- Bolts 044 and 045 (the kit, done)

### Enables
- 002-picture-questions-in-lessons-and-practice

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A very wide or very tall picture | Letterboxed inside the tile, not cropped |
| Reduced motion | No shake, as in the kit |

## Out of Scope

- Captions under pictures (answer 2a)
