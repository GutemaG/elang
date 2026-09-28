---
id: 055-admin-tree-polish
unit: 002-content-admin-web
intent: 017-content-admin-web
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-28T19:41:33Z'
started: '2026-09-28T19:41:33Z'
completed: '2026-09-28T20:12:44Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-28T19:52:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-28T20:11:01Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-28T20:12:44Z'
    artifact: implementation-plan.md
requires_bolts:
  - 040-admin-vocabulary
  - 052-image-choice-admin
enables_bolts: []
requires_units: []
blocks: false
---

# Bolt: 055-admin-tree-polish

## Overview

Three fixes from using the admin site (reported 2026-09-28):

1. A picture's description becomes optional.
2. Sections, skills, lessons and exercises are reordered by dragging,
   then saved with one Save button.
3. The course page keeps what was open, and where you were, however you
   come back to it: the browser's Back button, the breadcrumb, or
   "Back to lesson".

## Objective

Reordering and moving around the curriculum feel like one steady page,
and a picture question can be saved without a description.

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
- `040-admin-vocabulary`
- `052-image-choice-admin`

### Enables
- None

## Notes

Drag and drop was out of scope for unit 002 when it was planned. It is now
asked for, so the unit brief's scope is updated when this bolt completes.
The picture change also touches the backend and the Flutter app (intent
019).
