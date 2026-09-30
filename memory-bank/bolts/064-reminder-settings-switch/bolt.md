---
id: 064-reminder-settings-switch
unit: 002-daily-reminder-ui
intent: 021-daily-reminder
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T08:40:29Z'
started: '2026-09-30T12:30:00Z'
completed: '2026-09-30T12:38:18Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T12:33:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T12:37:51Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T12:38:17Z'
    artifact: implementation-plan.md
requires_bolts:
  - 063-reminder-scheduler
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 064-reminder-settings-switch

## Objective

Make the Settings Notifications switch control the reminder: permission on turning it on, the refusal line, and cancelling on off and sign-out.

## Stories Included

Written in the unit brief (`intents/021-daily-reminder/units/002-daily-reminder-ui/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **004-settings-switch (Must)**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Switch wired to the scheduler and permission
- Refusal line and subtitle
- Cancel on off and sign-out
- Widget tests

## Dependencies

### Requires
- `063-reminder-scheduler`

### Enables
- None
