---
unit: 002-league-ui
intent: 023-weekly-leagues
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-01T06:14:45Z'
updated: '2026-10-01T06:14:45Z'
---

# Unit Brief: League UI

## Purpose

Show the learner their league: where they stand this week, what happened
last week, and how to stay out, using only what the league endpoint
returns.

## Scope

### In Scope
- A league API client and a saved copy for offline
- The league screen (ranking, zones, rewards, time left, empty and
  switched-off states), both themes
- The one-time result sheet after a week closes
- The dashboard card
- The "Show me in leagues" switch in Settings and the first-visit name
  notice
- Widget tests, the screen sweep, the gallery where a new component is
  added

### Out of Scope
- Any league rule computed in the app
- Notifications

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-6 | Names other learners see (notice) | Must |
| FR-7 | "Show me in leagues" (switch) | Must |
| FR-9 | League screen | Must |
| FR-10 | Dashboard entry | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 006-league-screen | The league screen | Must | Planned |
| 007-show-in-leagues-switch | The switch and the name notice | Must | Planned |
| 008-week-result-sheet | Last week's result, shown once | Must | Planned |
| 009-dashboard-league-card | Tier and rank on the dashboard | Must | Planned |

### 006-league-screen (FR-9, FR-2)

**As a** learner, **I want** to see my group's ranking and the time left,
**so that** I know what it takes to move up.

- [ ] Rows show rank, avatar (initial on its colour), shown name and
  weekly XP; my row is highlighted; the top three show their Amole.
- [ ] Dividers mark the move-up and move-down zones, sized by the
  endpoint.
- [ ] The tier (name, icon, palette colour) and the time left are shown.
- [ ] Not joined yet: "Earn XP this week to join the league" and a button
  to start a lesson.
- [ ] Offline: the last saved copy, marked as not up to date; never an
  error screen.
- [ ] Both themes, design-system components and palette roles only; in
  the screen sweep.

### 007-show-in-leagues-switch (FR-7, FR-6)

**As a** learner, **I want** to know who sees my name and to be able to
stay out, **so that** I'm comfortable taking part.

- [ ] Settings has "Show me in leagues", read from the account settings
  (`show_in_leagues` in `AccountSettings`, one line) and written with
  `PATCH /api/v1/users/me/settings`; a failed write puts the switch back
  and says so.
- [ ] The first time the league screen opens, it explains that others in
  the group see your first name, with a link to the switch; shown once.
- [ ] Switched off: the league screen explains it and offers to turn it
  on.

### 008-week-result-sheet (FR-9)

**As a** learner, **I want** to hear how last week went, **so that**
moving up feels like an event.

- [ ] When the endpoint returns a last-week result, a sheet shows it:
  moved up (to which tier), stayed, or moved down, with the place and any
  Amole earned.
- [ ] Closing the sheet acknowledges it, so it is shown once; offline it
  waits for the next time.

### 009-dashboard-league-card (FR-10)

**As a** learner, **I want** my tier and rank on the home screen, **so
that** I'm reminded of the league every day.

- [ ] The dashboard shows "Light Roast · 4th", or "Join this week's
  league" before the first XP, or nothing when switched off; tapping it
  opens the league screen.
- [ ] It refreshes after a lesson or practice session, without a restart.

---

## Dependencies

### Depends On
- `001-league-service` (the endpoint and the setting)

### Depended On By
None.
