---
id: 024-courses-service
unit: 001-courses-service
intent: 010-multi-language-courses
type: ddd-construction-bolt
status: complete
stories:
  - 001-course-model-and-migration
  - 002-active-course-per-user
  - 003-course-list-api
  - 004-course-scoped-skill-tree-and-progress
  - 005-course-scoped-practice
created: '2026-09-20T13:20:00Z'
started: '2026-09-20T13:50:00Z'
completed: '2026-09-19T22:20:58Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-20T14:15:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-20T14:50:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-20T15:20:00Z'
    artifact: adr-12-courses-as-top-content-level.md
  - name: implement
    completed: '2026-09-20T17:10:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-20T18:40:00Z'
    artifact: ddd-03-test-report.md
requires_bolts: []
enables_bolts:
  - 025-course-content-seed
  - 026-course-picker-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 4
  avg_uncertainty: 3
  max_dependencies: 2
  testing_scope: 4
---

# Bolt: 024-courses-service

## Overview

Add `courses` and `categories.course_id` (data-preserving migration), save one active course per user (including signup with a language pair), expose course list and switch endpoints, and scope the skill tree, progress and Practice to the active course.

## Objective

A course level exists end to end on the backend; a user can switch courses; each course keeps separate progress and Practice; query counts stay constant.

## Stories Included

- **001-course-model-and-migration** (Must)
- **002-active-course-per-user** (Must)
- **003-course-list-api** (Must)
- **004-course-scoped-skill-tree-and-progress** (Must)
- **005-course-scoped-practice** (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- [x] **1. Domain Model**
- [x] **2. Technical Design**
- [x] **3. ADR Analysis**
- [x] **4. Implement**
- [x] **5. Test**

## Dependencies

### Requires
- None

### Enables
- `025-course-content-seed`, `026-course-picker-ui`

## Success Criteria

- [ ] Migration preserves all existing data and downgrades cleanly
- [ ] One shared course-scoping rule for tree read, access check, completion and Practice
- [ ] Fate of `users.selected_language` and vocab-per-course decided in an ADR
- [ ] Query counts constant
- [ ] Full backend suite passes

## Notes

Prior Decision Lookup against `memory-bank/standards/decision-index.md` at Stage 1 (ADR-10 additive widening and ADR-11 categories envelope are relevant). Backup `backend/dev.db` before migrating it.
