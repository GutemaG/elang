---
unit: 001-daily-reminder-service
intent: 021-daily-reminder
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-09-30T08:40:29Z'
updated: '2026-09-30T08:49:50Z'
---

# Unit Brief: Daily Reminder Service

## Purpose

Let the app know whether today's streak day is already practised, so a
lesson finished on another device still cancels that evening's reminder.

## Scope

### In Scope
- `practised_today` on `GET /api/v1/skill-tree`
- Tests and API notes

### Out of Scope
- Sending notifications; device tokens; any table or migration
- Local-time streak days (requirements D6)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-6 | Backend `practised_today` | Must |

---

## Domain Concepts

| Concept | Description |
|---------|-------------|
| Practised today | `UserStreak.last_completed_date` equals today's UTC date. Only a non-review lesson completion writes that date, so reviews and Practice never make it true. |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-practised-today | The skill tree says whether today is practised | Must | Complete (bolt 062) |

### 001-practised-today (FR-6)

**As a** learner with two devices, **I want** the app to know I already
practised today, **so that** I'm not reminded for a day I've done.

- [x] `practised_today` is true exactly when a non-review lesson was
  completed on today's UTC date.
- [x] False for a new learner, for a learner whose last lesson was
  yesterday, and after only a review or a Practice session.
- [x] No extra query: the skill tree already reads the streak row.
- [x] Old clients that ignore the field keep working.

---

## Dependencies

### Depends On
None.

### Depended On By
`002-daily-reminder-ui`.
