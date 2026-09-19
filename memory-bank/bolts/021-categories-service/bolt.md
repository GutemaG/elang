---
id: 021-categories-service
unit: 001-categories-service
intent: 009-course-categories
type: ddd-construction-bolt
status: complete
stories:
  - 001-category-content-model-and-migration
  - 002-per-category-progression
  - 003-skill-tree-api-with-categories
created: '2026-09-19T19:40:00Z'
started: '2026-09-19T20:00:00Z'
completed: '2026-09-19T19:31:54Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-19T20:15:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-19T20:35:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-19T20:50:00Z'
    artifact: adr-11-categories-additive-envelope-and-per-category-order.md
  - name: implement
    completed: '2026-09-19T21:45:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-19T22:05:00Z'
    artifact: ddd-03-test-report.md
requires_bolts: []
enables_bolts:
  - 022-category-content-seed
  - 023-categories-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 021-categories-service

## Overview

Add `categories` + `skills.category_id` (with a data-preserving migration), make progression linear within a category with all categories open, and return categories from `GET /skill-tree`.

## Objective

A category level exists end to end on the backend; a new user sees one active skill per category; the API returns categories with a constant query count.

## Stories Included

- **001-category-content-model-and-migration** (Must)
- **002-per-category-progression** (Must)
- **003-skill-tree-api-with-categories** (Must)

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
- `022-category-content-seed`, `023-categories-ui`

## Success Criteria

- [ ] Migration preserves all existing data and downgrades cleanly
- [ ] One shared progression rule for tree read, access check, and completion-unlock
- [ ] Skill-tree query count constant
- [ ] Full backend suite passes

## Notes

Prior Decision Lookup against `memory-bank/standards/decision-index.md` at Stage 1 (ADR-10's additive-widening precedent is relevant to the response envelope).
