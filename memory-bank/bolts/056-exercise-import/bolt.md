---
id: 056-exercise-import
unit: 002-content-admin-web
intent: 017-content-admin-web
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-28T20:43:39Z'
started: '2026-09-28T20:43:39Z'
completed: '2026-09-28T21:13:07Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-28T20:45:35Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-28T21:10:25Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-28T21:13:07Z'
    artifact: implementation-plan.md
requires_bolts:
  - 055-admin-tree-polish
enables_bolts: []
requires_units:
  - 001-content-admin-api
blocks: false
---

# Bolt: 056-exercise-import

## Overview

Adding exercises one at a time is slow (reported 2026-09-28). A lesson's
exercises can be imported from a CSV or JSON file, and exported to either
format.

## Objective

A lesson's exercises can be written in a spreadsheet or generated as JSON,
checked in a preview, and added in one step. They can also be downloaded,
edited and imported back.

## Stories Included

None as separate files. The acceptance criteria are in
`implementation-plan.md` (one md per bolt).

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Dependencies

### Requires
- `055-admin-tree-polish`
- Unit `001-content-admin-api`: one new endpoint

### Enables
- None

## Notes

The user's decisions (2026-09-28):

- Both CSV and JSON.
- One file fills one lesson. For several lessons, import into each lesson
  in turn.
- Export is in this bolt.

The bolt spans both units of intent 017: the admin site (002) and one new
endpoint (001).
