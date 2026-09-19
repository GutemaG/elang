---
id: 026-course-picker-ui
unit: 002-courses-ui
intent: 010-multi-language-courses
type: simple-construction-bolt
status: planned
stories:
  - 001-course-switcher-and-settings-picker
  - 002-onboarding-language-pair
created: '2026-09-20T13:20:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 024-courses-service
  - 025-course-content-seed
enables_bolts:
  - 027-course-offline-and-verification
requires_units:
  - 001-courses-service
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 3
---

# Bolt: 026-course-picker-ui

## Overview

Flutter course model and API, dashboard course chip and picker, Settings using the same picker, and onboarding that asks the language pair.

## Objective

A learner can pick a course during onboarding, see the course list on the dashboard, switch, and have it saved.

## Stories Included

- **001-course-switcher-and-settings-picker** (Must)
- **002-onboarding-language-pair** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `024-courses-service`, `025-course-content-seed`

### Enables
- `027-course-offline-and-verification`

## Success Criteria

- [ ] Course list is API-driven; no hardcoded lists remain
- [ ] Coming-soon courses disabled; failed switch keeps the current course
- [ ] No overflow at 360dp and 320dp with 1.3x text
- [ ] Full Flutter suite passes

## Notes

Read the real dashboard top bar, settings screen and onboarding flow at Plan stage before restructuring.
