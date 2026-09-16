---
id: 004-lesson-content-service
unit: 001-lesson-service
intent: 002-core-lesson-loop
type: ddd-construction-bolt
status: complete
stories:
  - 001-serve-skill-tree-and-lesson-content
  - 005-seed-curriculum-content
created: '2026-09-15T18:00:00Z'
started: '2026-09-16T09:00:00Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-16T09:05:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-16T09:20:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-16T09:25:00Z'
    artifact: adr-3-polymorphic-exercises-table.md, adr-4-server-side-only-answer-keys.md
  - name: implement
    completed: '2026-09-16T10:15:00Z'
    artifact: implementation-notes.md
  - name: test
    completed: '2026-09-16T11:00:00Z'
    artifact: ddd-03-test-report.md
requires_bolts: []
enables_bolts:
  - 005-lesson-engagement-service
requires_units:
  - 001-auth-service
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
completed: '2026-09-16T06:46:53Z'
---

# Bolt: 004-lesson-content-service

## Overview

First bolt for the `001-lesson-service` unit. Defines the skill/lesson/exercise content model, the read-side skill-tree/lesson-content serving endpoints, and seeds a small real Amharic curriculum — the foundation everything else in this intent builds on.

## Objective

Stand up the content schema (`skills`, `lessons`, `exercises`) and its serving endpoints, and seed enough real curriculum content that the rest of the lesson loop (answer validation, completion, UI) has something real to work against.

## Stories Included

- **001-serve-skill-tree-and-lesson-content**: Serve skill tree + lesson content (Must)
- **005-seed-curriculum-content**: Seed a small real Amharic curriculum (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- ✅ **1. Domain Model**
- ✅ **2. Technical Design**
- ✅ **3. ADR Analysis** (2 ADRs created: exercise content modeling, server-side-only answer keys)
- ✅ **4. Implement**
- ✅ **5. Test**

## Dependencies

### Requires
- `001-auth-service` unit (existing, from intent `001-auth-onboarding`, complete) — session validation and the `users` row

### Enables
- `005-lesson-engagement-service` (needs the content model and seed data to validate answers/completions against)

## Success Criteria

- [x] Skill tree endpoint returns accurate locked/active/completed/crown state for a given user
- [x] Lesson content endpoint returns a full lesson's exercises in one request
- [x] At least 2 real, hand-authored Amharic skills are seeded, each with multiple lessons covering all 3 exercise types

## Notes

Deliberately scoped as its own bolt (rather than combined with engagement mechanics) because it's a genuine prerequisite — answer validation, completion, and streak logic (bolt 005) can't be built or tested without real content to operate on.
