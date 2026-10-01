---
intent: 023-weekly-leagues
phase: inception
status: units-decomposed
updated: '2026-10-01T06:14:45Z'
---

# Weekly Leagues - Unit Decomposition

## Units Overview

Two units: the backend owns every rule (joining, ranking, closing a week,
rewards, names, the switch), and the app only shows what the endpoint
returns. Stories are written inside each unit brief (owner's request: keep
the file count small), numbered across the intent.

### Unit 1: 001-league-service

**Description:** League tiers and weekly groups, joining with the first XP
of the week, ranking from the attempt tables, closing ended weeks with
moves and Amole rewards, stored first names, the "Show me in leagues"
setting and the league endpoint.

**Requirements:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6 (backend), FR-7
(backend), FR-8

**Deliverables:**
- One migration: league groups, members and closed results; the user's
  first name
- `given_name` from Google's verified token, stored at each sign-in
- Joining on XP-awarding completions (lesson and practice, online and
  synced)
- Ranking, week closing (idempotent, concurrent-safe), moves, rewards
- `show_in_leagues` in `ACCOUNT_SETTINGS`
- `GET /api/v1/leagues/current` (and acknowledging the last-week result);
  tests; API notes

**Dependencies:** none (builds on the settings store and Amole ledger
already shipped). Depended on by unit 2.

**Estimated complexity:** L

### Unit 2: 002-league-ui

**Description:** The league screen, the one-time result sheet, the
dashboard card, the privacy notice and the "Show me in leagues" switch.

**Requirements:** FR-6 (notice), FR-7 (switch), FR-9, FR-10

**Deliverables:**
- League API client and a saved copy for offline
- League screen with zones, empty and switched-off states, both themes
- Result sheet after a week closes
- Dashboard card; the Settings switch; the first-visit name notice

**Dependencies:** `001-league-service`.

**Estimated complexity:** M

## Requirement-to-Unit Mapping

- **FR-1** League tiers → `001-league-service`
- **FR-2** The league week → `001-league-service` (time left shown by `002-league-ui`)
- **FR-3** Joining a group → `001-league-service`
- **FR-4** Ranking → `001-league-service`
- **FR-5** Closing a week → `001-league-service`
- **FR-6** Names other learners see → `001-league-service`; notice in `002-league-ui`
- **FR-7** "Show me in leagues" → `001-league-service` (setting, effects); switch in `002-league-ui`
- **FR-8** League endpoint → `001-league-service`
- **FR-9** League screen → `002-league-ui`
- **FR-10** Dashboard entry → `002-league-ui`

## Unit Dependency Graph

```text
[001-league-service] ──> [002-league-ui]
```

## Execution Order

1. `001-league-service`: names, joining, ranking and the endpoint (bolt
   073), then closing a week with moves and rewards (bolt 074)
2. `002-league-ui`: the league screen, switch and notice (bolt 075), then
   the result sheet and dashboard card (bolt 076)
