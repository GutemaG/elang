---
id: 034-admin-api-foundation
unit: 001-content-admin-api
intent: 017-content-admin-web
type: simple-construction-bolt
status: complete
stories:
  - 001-admin-authorization
  - 002-seed-insert-only
created: '2026-09-22T10:00:00Z'
started: '2026-09-22T10:10:00Z'
completed: '2026-09-22T11:19:08Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-22T10:30:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-22T10:55:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-22T11:19:08Z'
    artifact: test-walkthrough.md
requires_bolts: []
enables_bolts:
  - 035-admin-content-api
  - 036-admin-audio-api
requires_units: []
blocks: false
---

# Bolt: 034-admin-api-foundation

## Overview

Admin authorization and insert-only seeds.

## Objective

Only admins can reach `/admin/*`, and no seed run can overwrite content any more.

## Stories Included

- **001-admin-authorization** (Must)
- **002-seed-insert-only** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- None

### Enables
- `035-admin-content-api`
- `036-admin-audio-api`

## Notes

Seeds go insert-only **before** any admin write exists, so there is never a window in which the seed erases admin edits. The email-storage question (system-context finding 1) is this bolt's ADR.
