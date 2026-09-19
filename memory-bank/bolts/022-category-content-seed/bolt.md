---
id: 022-category-content-seed
unit: 001-categories-service
intent: 009-course-categories
type: simple-construction-bolt
status: in-progress
stories:
  - 004-seed-four-new-categories
created: '2026-09-19T19:40:00Z'
started: '2026-09-19T22:30:00Z'
completed: null
current_stage: test
stages_completed:
  - name: plan
    completed: '2026-09-19T22:55:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-19T23:35:00Z'
    artifact: implementation-walkthrough.md
requires_bolts:
  - 021-categories-service
enables_bolts:
  - 023-categories-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 022-category-content-seed

## Overview

Extend the idempotent seed with four categories (Family & People, Numbers & Time, Travel & Places, Colors/Body & Health), 2 skills x 2 lessons each, real Amharic content, vocab-linked.

## Objective

The dev database holds five categories of playable content covering all exercise types.

## Stories Included

- **004-seed-four-new-categories** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `021-categories-service`

### Enables
- `023-categories-ui`

## Success Criteria

- [ ] Idempotent (second run creates nothing)
- [ ] Every lesson >= 4 exercises, >= 3 types; each category has match_pairs
- [ ] All content passes existing validation
- [ ] Native-review caveat recorded

## Notes

Amharic is agent-authored (NFR-3). The Plan stage should present the full vocabulary list to the user for a sanity check before implementing.
