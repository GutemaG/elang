---
unit: 001-stat-pill-service
intent: 013-stat-pill-interactions
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-09-30T05:44:19Z'
updated: '2026-09-30T07:56:33Z'
---

# Unit Brief: Stat Pill Service

## Purpose

Give the app what the streak and Amole sheets need, from rows the backend
already keeps: which days a learner practised, their longest streak, and
their recent Amole entries.

## Scope

### In Scope
- A streak history read over `lesson_attempts` and `user_streaks`
- An Amole history read over `amole_transactions`
- Response schemas, repository queries, tests, API notes

### Out of Scope
- Any write, table or migration
- Storing a longest streak; streak freezes
- An XP history (ADR-8)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-4 | Streak history read | Should |
| FR-6 | Amole history read | Should |

NFR-3 (fixed query count, capped range) and NFR-5 (new endpoints only)
apply.

---

## Domain Concepts

| Concept | Description |
|---------|-------------|
| Practised day | A UTC date with at least one `lesson_attempts` row for the learner, by `completed_at`. Practice sessions are not lesson attempts, so they never count. |
| Longest streak | The longest run of consecutive practised days, over all of the learner's attempts. No freeze is ever granted today, so runs are plain consecutive dates. |
| Current streak | `UserStreak.current_streak`, the same number the dashboard pill shows. |
| Amole entry | One `AmoleTransaction`: `amount` (signed), `source` (`AmoleSource`), `created_at`. |

| Operation | Inputs | Outputs |
|-----------|--------|---------|
| Streak history | user, `from`, `to` (dates) | practised dates in range, current streak, longest streak |
| Amole history | user, `limit` | entries, newest first |

Implementation hint (for Plan, not binding): one query for the learner's
distinct practised dates gives both the range and the longest run; one
query for the streak row; one for the Amole entries.

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-streak-history-read | The learner's practised days and streaks | Should | Complete (bolt 059) |
| 002-amole-history-read | The learner's recent Amole entries | Should | Complete (bolt 059) |

### 001-streak-history-read (FR-4)

**As a** learner, **I want** the app to know which days I practised and my
longest streak, **so that** the calendar can show them.

- [x] Returns the practised UTC dates between `from` and `to` inclusive,
  sorted, with `current_streak` and `longest_streak`.
- [x] A day counts when a lesson attempt's `completed_at` falls on it
  (UTC); practice sessions do not count.
- [x] `longest_streak` covers all of the learner's days, not just the
  range, and is never less than `current_streak`.
- [x] A range longer than 186 days, or `from` after `to`, returns 422.
- [x] The query count is the same for a 1-day and a 186-day range.
- [x] Only the signed-in learner's attempts; 401 without a session.
- [x] No attempts: an empty list, `longest_streak` 0, `current_streak` 0.

### 002-amole-history-read (FR-6)

**As a** learner, **I want** to see my recent Amole entries, **so that** I
know where my Amole came from and went.

- [x] Returns up to `limit` entries (default 20, at most 50; outside
  1..50 returns 422), newest first, each with `amount`, `source`,
  `created_at`.
- [x] Ties on `created_at` come back in a stable order.
- [x] One query; only the learner's own rows; 401 without a session.
- [x] No entries: an empty list.

---

## Dependencies

### Depends On
None. `lesson_attempts`, `user_streaks` and `amole_transactions` exist.

### Depended On By
`002-stat-pill-ui` (streak calendar and Amole sheet).

## Technical Notes

- Routes live beside `GET /beans` in `lesson_routers.py`; names are chosen
  at Plan.
- Local SQLite only while building; no Neon change is needed, since there
  is no migration.
