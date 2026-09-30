---
unit: 002-daily-reminder-ui
intent: 021-daily-reminder
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-09-30T08:40:29Z'
updated: '2026-09-30T12:38:17Z'
---

# Unit Brief: Daily Reminder UI

## Purpose

Schedule the 8 pm reminder on the phone, skip days already practised, and
make the Settings switch control it.

## Scope

### In Scope
- The notification plugin and time zone data, Android and iOS setup
- A scheduler behind an interface (plugin, fake, web no-op)
- When to schedule, cancel and refresh; the message
- The Settings switch, the permission request and the refusal line

### Out of Scope
- Server push, a time picker, local-time streak days

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | One evening reminder | Must |
| FR-2 | Skip a practised day | Must |
| FR-3 | The message | Must |
| FR-4 | The Settings switch | Must |
| FR-5 | No surprise permission prompt | Must |

NFR-1 to NFR-5 apply.

---

## Domain Concepts

| Concept | Description |
|---------|-------------|
| Reminder day | A local calendar day with an 8:00 pm reminder. Its streak day is the UTC date of that 8 pm. |
| Schedule | One notification per reminder day for the next 7 days, each with its own id, rebuilt on each refresh. |
| Refresh | Rebuild the schedule from: the switch, the permission, the streak count and whether today's streak day is practised. |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-schedule-reminders | Reminders at 8 pm for the next week | Must | Complete (bolt 063) |
| 002-skip-practised-day | No reminder on a day already practised | Must | Complete (bolt 063) |
| 003-reminder-message | The message names the streak | Must | Complete (bolt 063) |
| 004-settings-switch | The switch controls reminders | Must | Complete (bolt 064) |

### 001-schedule-reminders (FR-1)

**As a** learner, **I want** a reminder at 8 pm, **so that** I remember to
practise before the day ends.

- [x] One reminder per day at 8:00 pm in the phone's time zone, for the
  next 7 days; a refresh never duplicates one.
- [x] Works with the app closed and offline; survives a restart.
- [x] Tapping it opens the app on the dashboard.
- [x] On the web nothing is scheduled and nothing fails.

### 002-skip-practised-day (FR-2)

**As a** learner, **I want** no reminder on a day I've practised, **so
that** the app doesn't nag me.

- [x] Finishing a lesson that counts (not a review, not Practice) cancels
  that streak day's reminder, online or offline.
- [x] A dashboard load with `practised_today: true` cancels it too.
- [x] Later days stay scheduled.
- [x] After 8 pm has passed, nothing is scheduled for today.

### 003-reminder-message (FR-3)

**As a** learner, **I want** the reminder to name my streak, **so that** I
know what's at stake.

- [x] "Keep your N-day streak going" / "A quick lesson is enough." with a
  streak; "Time for today's lesson" / "A quick lesson keeps you going."
  with none.
- [x] Uses the last streak count the app saw; refreshed on dashboard load
  and lesson finish.

### 004-settings-switch (FR-4, FR-5)

**As a** learner, **I want** the Notifications switch to control the
reminder, **so that** I decide whether I get it.

- [x] Turning it on asks for permission if needed; a refusal turns it back
  off with a line saying how to allow it in the phone's settings.
- [x] Turning it off, or signing out, cancels every reminder.
- [x] The app never asks for permission on its own; with the stored value
  on but no permission, the switch shows off with the same line.
- [x] The subtitle reads "A reminder at 8 pm if you haven't practised".

---

## Dependencies

### Depends On
`001-daily-reminder-service` (`practised_today`).

### Depended On By
None.

## Technical Notes

- Android: `POST_NOTIFICATIONS` (13+), the plugin's boot receiver, inexact
  scheduling (no exact-alarm permission), core library desugaring if the
  plugin needs it.
- iOS: the plugin's `AppDelegate` setup; checked by a person with a Mac.
