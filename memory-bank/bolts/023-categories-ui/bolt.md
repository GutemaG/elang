---
id: 023-categories-ui
unit: 002-categories-ui
intent: 009-course-categories
type: simple-construction-bolt
status: planned
stories:
  - 001-dashboard-grouped-by-category
  - 002-new-category-end-to-end-verification
created: '2026-09-19T19:40:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 021-categories-service
  - 022-category-content-seed
enables_bolts: []
requires_units:
  - 001-categories-service
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 3
---

# Bolt: 023-categories-ui

## Overview

Flutter model/API/dashboard changes to group skills by category, plus end-to-end verification of new-category content.

## Objective

The dashboard shows five categories, each with its own banner and skill path, and new-category lessons work fully (complete, offline, Practice).

## Stories Included

- **001-dashboard-grouped-by-category** (Must)
- **002-new-category-end-to-end-verification** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `021-categories-service`, `022-category-content-seed`

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] N categories render N banners with correct counts
- [ ] No overflow at 360dp
- [ ] Existing skill behaviors unchanged
- [ ] Full Flutter suite passes; manual on-device check done

## Notes

Read the real dashboard structure at Plan stage before restructuring.
