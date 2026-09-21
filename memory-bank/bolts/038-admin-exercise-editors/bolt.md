---
id: 038-admin-exercise-editors
unit: 002-content-admin-web
intent: 017-content-admin-web
type: simple-construction-bolt
status: planned
stories:
  - 003-exercise-editors
  - 005-exercise-preview
created: '2026-09-22T10:00:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 037-admin-web-shell
enables_bolts: []
requires_units: []
blocks: false
---

# Bolt: 038-admin-exercise-editors

## Overview

Exercise editors and preview.

## Objective

Every exercise type has a form that round-trips existing content unchanged, plus a preview.

## Stories Included

- **003-exercise-editors** (Must)
- **005-exercise-preview** (Should)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `037-admin-web-shell`

### Enables
- None

## Notes

The round-trip test over every seeded exercise is the load-bearing one: write it first.
