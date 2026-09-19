---
id: 027-course-offline-and-verification
unit: 002-courses-ui
intent: 010-multi-language-courses
type: simple-construction-bolt
status: planned
stories:
  - 003-offline-per-course
  - 004-multi-course-end-to-end-verification
created: '2026-09-20T13:20:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 025-course-content-seed
  - 026-course-picker-ui
enables_bolts: []
requires_units:
  - 001-courses-service
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 3
  max_dependencies: 2
  testing_scope: 4
---

# Bolt: 027-course-offline-and-verification

## Overview

Key the offline skill-tree cache and lesson packs by course, define offline switching rules, and verify the whole multi-course flow end to end.

## Objective

Switching courses is correct online and offline, and nothing in the English to Amharic course regressed.

## Stories Included

- **003-offline-per-course** (Must)
- **004-multi-course-end-to-end-verification** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `025-course-content-seed`, `026-course-picker-ui`

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] Cache and packs separated by course; upgrade keeps existing data as English to Amharic
- [ ] Offline switch rules and cross-course queued sync verified
- [ ] Full Flutter and backend suites pass; manual on-device check done

## Notes

Read the real skill-tree cache, `LessonPackStore` and sync queue at Plan stage before restructuring.
