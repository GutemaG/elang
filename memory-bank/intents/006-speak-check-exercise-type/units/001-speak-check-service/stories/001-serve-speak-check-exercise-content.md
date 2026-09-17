---
id: 001-serve-speak-check-exercise-content
unit: 001-speak-check-service
intent: 006-speak-check-exercise-type
status: ready
priority: must
created: '2026-09-17T14:50:00Z'
assigned_bolt: null
implemented: false
---

# Story: 001-serve-speak-check-exercise-content

## User Story

**As a** Buna learner
**I want** a lesson to include a speak-check exercise showing me a phrase to say aloud
**So that** I can practice pronunciation, not just recognition

## Acceptance Criteria

- [ ] **Given** a lesson containing a `speak_check` exercise, **When** its content is fetched, **Then** the response includes the target phrase (Amharic) and its translation
- [ ] **Given** the `exercises` table, **When** a `speak_check` row is inserted, **Then** the widened `ck_exercises_type` CHECK constraint (new migration) accepts it
- [ ] **Given** the seed content script, **When** it runs, **Then** at least one lesson includes a `speak_check` exercise

## Technical Notes

- Follow the exact `content`/`answer_key` sibling-field split every other exercise type uses (ADR-3), even though here the two are largely the same string — consistency with the existing polymorphic schema matters more than saving one field
- Migration pattern: `op.batch_alter_table` for the CHECK constraint widening, same as `c726efa81972` (`011-match-pairs-service`) — verify the SQLite/PostgreSQL divergence documented there still applies before writing it

## Dependencies

### Requires
- None

### Enables
- `002-grade-speak-check-attempt` (needs the content model to exist first)
- `002-speak-check-ui`'s story `001-speak-check-exercise-screen`

## Out of Scope

- Grading (see `002-grade-speak-check-attempt`)
- Any UI (see `002-speak-check-ui`)
