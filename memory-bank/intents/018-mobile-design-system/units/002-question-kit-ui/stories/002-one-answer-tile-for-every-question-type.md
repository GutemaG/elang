---
id: 002-one-answer-tile-for-every-question-type
unit: 002-question-kit-ui
intent: 018-mobile-design-system
status: draft
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 044-question-kit
implemented: false
---

# Story: 002-one-answer-tile-for-every-question-type

## User Story

**As a** Buna learner
**I want** every answer tile, word chip and match card to look and react the same way
**So that** right, wrong and selected always mean the same colours and motion

## Acceptance Criteria

- [ ] **Given** `AnswerTile`, **When** in idle, selected, correct, incorrect, used or disabled state, **Then** it matches DESIGN.md Component 4 (white/2 px `#E5DDD0`/3 px `#D5CCBD` rim; gold tint; mint; blush; dimmed; faded) using only tokens
- [ ] **Given** the row, pill and grid-cell shapes, **When** built, **Then** row fits multiple choice, listening and gap fill; pill fits the word bank and spell tiles; grid cell fits match pairs
- [ ] **Given** correct or incorrect, **When** shown, **Then** a check or cross icon appears and incorrect shakes once within `AppMotion.shake` (skipped with reduced motion)
- [ ] **Given** `onTap == null`, **When** tapped, **Then** nothing happens and the tile shows it is not interactive, as `ChoiceTile` does today
- [ ] **Given** a screen reader, **When** it reaches a tile, **Then** it reads the label with button and selected flags, as today
- [ ] **Given** the gallery, **When** opened, **Then** every state in every shape is shown

## Reference Design (FR-11)

- DESIGN.md Component 4
- Fetched in Plan: Duolingo answer tiles and word bank chips for pressed/selected/graded states

## Technical Notes

- `AnswerTile` must reproduce the exact tap semantics tests rely on (`find.byType(ChoiceTile)` in one test; plan the rename).

## Dependencies

### Requires
- 001-exercise-layout-and-question-prompt

### Enables
- 004-lesson-screen-on-the-kit
- Bolt 033 (spell tiles)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Tile label in Fidel at 1.3× text | Grows in height; never clips or overflows |

## Out of Scope

- Changing grading, feedback timing or sounds
