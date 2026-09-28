---
id: 040-admin-vocabulary
unit: 001-content-admin-api
intent: 017-content-admin-web
type: simple-construction-bolt
status: complete
stories:
  - 006-vocabulary-api
  - 006-vocabulary-screen
created: '2026-09-22T10:00:00Z'
started: '2026-09-28T00:00:00Z'
completed: '2026-09-28T14:43:14Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-28T00:00:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-28T00:00:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-28T14:43:14Z'
    artifact: implementation-plan.md
requires_bolts:
  - 035-admin-content-api
  - 037-admin-web-shell
enables_bolts: []
requires_units: []
blocks: false
---

# Bolt: 040-admin-vocabulary

## Overview

Vocabulary management (Could). Also carries the fix for the "Add exercise"
type menu, which is clipped inside its section card (reported 2026-09-28).

## Objective

Vocabulary can be listed and edited per course.

## Stories Included

- **006-vocabulary-api** (Could)
- **006-vocabulary-screen** (Could)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Dependencies

### Requires
- `035-admin-content-api`
- `037-admin-web-shell`

### Enables
- None

## Notes

Could priority: plan it last and skip it if time is short. It is the one bolt spanning both units, because each half is tiny.
