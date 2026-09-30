---
intent: 021-daily-reminder
phase: inception
status: units-decomposed
updated: '2026-09-30T08:40:29Z'
---

# Daily Reminder - Unit Decomposition

## Units Overview

Two units at the usual seam: one backend field first, then the app. Stories
are written inside each unit brief (owner's request: keep the file count
small).

### Unit 1: 001-daily-reminder-service

**Description:** The skill tree answer says whether today's UTC streak day
is already practised.

**Requirements:** FR-6

**Deliverables:**
- `practised_today` on the skill tree response, from the streak row the
  request already reads (`last_completed_date == today UTC`), so no extra
  query
- Tests; API notes updated; no migration

**Dependencies:** none. Depended on by unit 2 (skip a day practised on
another device).

**Estimated complexity:** S

### Unit 2: 002-daily-reminder-ui

**Description:** The phone schedules the 8 pm reminder, skips practised
days, and the Settings switch turns it on and off with a permission
request.

**Requirements:** FR-1, FR-2, FR-3, FR-4, FR-5

**Deliverables:**
- `flutter_local_notifications` and `timezone` set up for Android and iOS
  (manifest, boot receiver, iOS delegate)
- A `ReminderScheduler` interface, the plugin version, a fake, and a no-op
  for the web
- The scheduling rules: 7 days ahead at 8 pm local, skip a practised day,
  streak message, refresh on dashboard load and on lesson finish
- The Settings switch wired: permission, refusal line, off cancels, sign
  out cancels

**Dependencies:** `001-daily-reminder-service` for `practised_today`.

**Estimated complexity:** M

## Requirement-to-Unit Mapping

- **FR-1** One evening reminder → `002-daily-reminder-ui`
- **FR-2** Skip a practised day → `002-daily-reminder-ui` (uses unit 1)
- **FR-3** The message → `002-daily-reminder-ui`
- **FR-4** The Settings switch → `002-daily-reminder-ui`
- **FR-5** No surprise permission prompt → `002-daily-reminder-ui`
- **FR-6** Backend `practised_today` → `001-daily-reminder-service`

## Unit Dependency Graph

```text
[001-daily-reminder-service] ──> [002-daily-reminder-ui]
```

## Execution Order

1. `001-daily-reminder-service` (bolt 062)
2. `002-daily-reminder-ui`: the scheduler and its rules (bolt 063), then
   the Settings switch and permission (bolt 064)
