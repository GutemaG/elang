---
id: 063-reminder-scheduler
unit: 002-daily-reminder-ui
intent: 021-daily-reminder
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T08:40:29Z'
started: '2026-09-30T08:55:00Z'
completed: '2026-09-30T12:24:11Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T08:58:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T09:30:18Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T12:24:10Z'
    artifact: implementation-plan.md
requires_bolts:
  - 062-practised-today
enables_bolts:
  - 064-reminder-settings-switch
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 063-reminder-scheduler

## Objective

Set up local notifications on Android and iOS and schedule the 8 pm reminder for the next week, skipping practised days, with the streak message.

## Stories Included

Written in the unit brief (`intents/021-daily-reminder/units/002-daily-reminder-ui/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-schedule-reminders (Must)**
- [x] **002-skip-practised-day (Must)**
- [x] **003-reminder-message (Must)**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes the plugin versions and Android/iOS setup
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Plugin and time zone setup; Android manifest and iOS delegate
- `ReminderScheduler` interface, plugin version, fake, web no-op
- Refresh on app start, dashboard load and lesson finish
- Unit and widget tests with the fake

## Dependencies

### Requires
- `062-practised-today`

### Enables
- `064-reminder-settings-switch`
