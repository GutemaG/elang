---
id: 004-seed-four-new-categories
unit: 001-categories-service
intent: 009-course-categories
status: complete
priority: must
created: '2026-09-19T19:35:00Z'
assigned_bolt: 022-category-content-seed
implemented: true
---

# Story: 004-seed-four-new-categories

## User Story

**As a** Buna learner
**I want** real lessons in Family & People, Numbers & Time, Travel & Places, and Colors/Body & Health
**So that** I can study vocabulary beyond greetings and food

## Acceptance Criteria

- [ ] **Given** the seed runs, **Then** four new categories exist, each with 2 skills of 2 lessons
- [ ] **Given** any new lesson, **Then** it has >= 4 exercises drawn from >= 3 exercise types (multiple_choice, listening, sentence_construction, match_pairs)
- [ ] **Given** each new category, **Then** at least one match_pairs exercise exists
- [ ] **Given** "how do you say X" exercises, **Then** they link to new `vocab_items` so Practice/SRS picks them up
- [ ] **Given** the seed is run twice, **Then** no duplicates are created and edits update in place
- [ ] **Given** every seeded exercise, **Then** it passes the existing content validation (answer keys reference real choices, sequences use only bank words, pair ids consistent)

## Technical Notes

- Real Amharic in Fidel, agent-authored. NFR-3: not native-speaker reviewed; flagged in the walkthrough and final report.
- Audio uses the existing placeholder URL (carried-over limitation).
- Deterministic uuid5 slugs, same as existing seed.

## Dependencies

### Requires
- `001-category-content-model-and-migration`

### Enables
- `001-dashboard-grouped-by-category` (something to render), `002-new-category-end-to-end-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Seed run against a DB that already has the original 2 skills | Original content untouched; new content added |
| Global `order_index` uniqueness (if kept) | Seed assigns non-colliding indices |

## Out of Scope

- Native-speaker review; real audio
