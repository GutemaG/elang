---
id: 058-audio-playing-state
unit: 002-question-kit-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-29T09:23:25Z'
started: '2026-09-29T09:23:25Z'
completed: '2026-09-29T09:41:28Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-29T09:26:14Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-29T09:35:48Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-29T09:41:28Z'
    artifact: implementation-plan.md
requires_bolts:
  - 057-media-cache
enables_bolts: []
requires_units: []
blocks: false
---

# Bolt: 058-audio-playing-state

## Overview

The play button shows "playing" for about a second and then goes back to
the speaker while the clip is still playing, and it does not move (reported
2026-09-29). It should show playing, animated, until the clip ends, and a
tap while playing should start the clip again.

## Objective

A learner can see that a clip is playing for exactly as long as it plays,
and tap to hear it again from the start.

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
- `057-media-cache` (the caching audio player this builds on)

### Enables
- None
