---
id: 035-admin-content-api
unit: 001-content-admin-api
intent: 017-content-admin-web
type: simple-construction-bolt
status: planned
stories:
  - 003-content-tree-and-crud-api
  - 004-exercise-write-validation
created: '2026-09-22T10:00:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 034-admin-api-foundation
enables_bolts:
  - 037-admin-web-shell
  - 038-admin-exercise-editors
requires_units: []
blocks: false
---

# Bolt: 035-admin-content-api

## Overview

Admin content API.

## Objective

The full content tree can be read and every section, skill, lesson and exercise created, edited, reordered and deleted over `/admin/*`, with invalid exercises refused.

## Stories Included

- **003-content-tree-and-crud-api** (Must)
- **004-exercise-write-validation** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `034-admin-api-foundation`

### Enables
- `037-admin-web-shell`
- `038-admin-exercise-editors`

## Notes

Validation reuses the domain objects: no second rule set. Reorder under the categories unique constraint is the fiddly part; test it on SQLite and Postgres.
