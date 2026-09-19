---
id: 006-seed-afaan-oromo-starter-courses
unit: 001-courses-service
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:00:00Z'
assigned_bolt: 025-course-content-seed
implemented: true
---

# Story: 006-seed-afaan-oromo-starter-courses

## User Story

**As a** learner who speaks English, Amharic or Afaan Oromo
**I want** a starter course for learning Afaan Oromo (or Amharic from Afaan Oromo)
**So that** I can switch courses and actually study in my own language

## Acceptance Criteria

- [ ] **Given** the seed runs, **When** it finishes, **Then** three available courses exist: English to Afaan Oromo, Amharic to Afaan Oromo, Afaan Oromo to Amharic
- [ ] **Given** each new course, **When** inspected, **Then** it has one category, 2 skills, each skill 2 lessons, each lesson >= 4 exercises from >= 3 types, and >= 1 `match_pairs`
- [ ] **Given** prompts and answers, **When** read, **Then** prompts are in the from-language and answers in the learning language (Afaan Oromo in Latin script, Amharic in Fidel)
- [ ] **Given** the seed is run twice, **When** the second run finishes, **Then** nothing is duplicated
- [ ] **Given** all exercises, **When** validated, **Then** they satisfy existing content validation (answer keys, sentence-construction word banks, match-pair ids)
- [ ] **Given** multiple-choice vocabulary exercises, **When** completed, **Then** course-specific vocab rows are created so Practice works in each course
- [ ] **Given** the full proposed vocabulary list, **When** the Plan stage runs, **Then** it is shown to the user for a sanity check before implementing (agent-authored, not native-reviewed)

## Technical Notes

- Reuse the concepts of the existing Greetings and Food & Drink skills. Audio uses the existing placeholder.
- Backup `backend/dev.db` before seeding it.

## Dependencies

### Requires
- `001-course-model-and-migration` (bolt 024)

### Enables
- UI `004-multi-course-end-to-end-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Word with several valid translations | Only the chosen one is an answer key |
| Word bank splits on whitespace in Fidel or Latin | Tokenisation works for both scripts |

## Out of Scope

- More than one category per new course; real audio; native review (required later)
