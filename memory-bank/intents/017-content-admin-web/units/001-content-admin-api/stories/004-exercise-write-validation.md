---
id: 004-exercise-write-validation
unit: 001-content-admin-api
intent: 017-content-admin-web
status: complete
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 035-admin-content-api
implemented: true
---

# Story: 004-exercise-write-validation

## User Story

**As a** Buna admin
**I want** the server to refuse any exercise the app could not play
**So that** a mistake in a form can never break a lesson for learners

## Acceptance Criteria

- [ ] **Given** each of the six exercise types, **When** an existing seeded exercise is sent back unchanged, **Then** it is accepted and stored byte-identical
- [ ] **Given** an answer key pointing at a choice id that does not exist, **When** it is saved, **Then** it returns `422` naming `answer_key`
- [ ] **Given** fewer than two choices, an empty prompt, or a sequence answer using unknown tile ids, **When** it is saved, **Then** it returns `422` naming the field
- [ ] **Given** an update that changes `type`, **When** it is saved, **Then** it returns `422`
- [ ] **Given** a listening exercise, **When** `audio_url` is not an absolute `https://` URL, **Then** it returns `422`
- [ ] **Given** this story is complete, **When** the code is inspected, **Then** validation is performed by building the existing domain value objects -- there is no parallel per-type rule set

## Technical Notes

- Reuse `_content_from_json` / `_answer_key_from_json` in `lesson_repositories.py` (or lift them) plus the value objects' own invariants. If an invariant is missing today (e.g. answer key vs choices), add it to the domain so the learner path gains it too.
- `test_exercise_type_dispatch.py` is parametrized over `ExerciseType`; add the admin write round-trip to the same parametrization so a seventh type fails loudly here too.

## Dependencies

### Requires
- 003-content-tree-and-crud-api

### Enables
- 003-exercise-editors
