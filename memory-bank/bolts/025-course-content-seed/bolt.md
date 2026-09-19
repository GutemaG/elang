---
id: 025-course-content-seed
unit: 001-courses-service
intent: 010-multi-language-courses
type: simple-construction-bolt
status: planned
stories:
  - 006-seed-afaan-oromo-starter-courses
created: '2026-09-20T13:20:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 024-courses-service
enables_bolts:
  - 026-course-picker-ui
  - 027-course-offline-and-verification
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 3
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 025-course-content-seed

## Overview

Extend the idempotent seed with three available courses (English to Afaan Oromo, Amharic to Afaan Oromo, Afaan Oromo to Amharic), each with 1 category, 2 skills x 2 lessons, vocab-linked.

## Objective

The dev database holds four playable courses, and users of any of the three source languages can study.

## Stories Included

- **006-seed-afaan-oromo-starter-courses** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `024-courses-service`

### Enables
- `026-course-picker-ui`, `027-course-offline-and-verification`

## Success Criteria

- [ ] Idempotent (second run creates nothing)
- [ ] Every lesson >= 4 exercises, >= 3 types; each course has match_pairs
- [ ] All content passes existing validation; Latin and Fidel scripts both work in word banks
- [ ] Native-review caveat recorded

## Notes

Content is agent-authored (NFR-3). The Plan stage must present the full vocabulary list per course to the user for a sanity check before implementing. Backup `backend/dev.db` before seeding it.
