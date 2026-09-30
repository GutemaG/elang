---
intent: 013-stat-pill-interactions
phase: inception
status: units-decomposed
updated: '2026-09-30T05:44:19Z'
---

# Stat Pill Interactions - Unit Decomposition

## Units Overview

Two units, split at the usual seam: the backend reads first, the app
builds against them. The beans sheet needs no backend change, so the app
can start before the service is done.

Stories are written inside each unit brief, not as separate files (owner's
request, 2026-09-30: keep the file count small).

### Unit 1: 001-stat-pill-service

**Description:** Two read-only endpoints for the signed-in learner: the
practised days in a range with the current and longest streak, and the
most recent Amole ledger entries.

**Requirements:** FR-4, FR-6

**Deliverables:**
- Streak history read: practised UTC dates in `from`..`to` (at most 186
  days), current streak, longest streak worked out from all practised days
- Amole history read: up to `limit` entries (default 20, at most 50),
  newest first, with `amount`, `source`, `created_at`
- Repository queries with a fixed query count, schemas, tests
- `api-contract` notes updated; no migration

**Dependencies:** none. Depended on by unit 2's streak and Amole sheets.

**Estimated complexity:** S

### Unit 2: 002-stat-pill-ui

**Description:** The four pills become buttons, each opening its sheet:
beans (countdown and refill), streak (month calendar), Amole (explanation
and recent entries) and XP (explanation).

**Requirements:** FR-1, FR-2, FR-3, FR-5, FR-7

**Deliverables:**
- A tappable `StatPill` with one button node; tap areas the header's full
  48 dp height; one tabbed stats sheet
- The beans sheet reusing the existing refill; beans timing kept in the
  offline dashboard copy
- The streak calendar sheet, the Amole sheet and the XP sheet
- `LessonApi` calls for both reads, in the HTTP and fake APIs
- Gallery entries for the new pieces

**Dependencies:** `001-stat-pill-service` for the streak and Amole sheets
only.

**Estimated complexity:** M

## Requirement-to-Unit Mapping

- **FR-1** Tappable pills → `002-stat-pill-ui`
- **FR-2** Beans sheet → `002-stat-pill-ui`
- **FR-3** Streak calendar → `002-stat-pill-ui`
- **FR-4** Streak history read → `001-stat-pill-service`
- **FR-5** Amole sheet → `002-stat-pill-ui`
- **FR-6** Amole history read → `001-stat-pill-service`
- **FR-7** XP sheet → `002-stat-pill-ui`

## Unit Dependency Graph

```text
[001-stat-pill-service] ──> [002-stat-pill-ui] (streak and Amole sheets)
```

## Execution Order

1. `001-stat-pill-service` (bolt 059)
2. `002-stat-pill-ui`: pills and beans (bolt 060, can run before or
   alongside 059), then the streak, Amole and XP sheets (bolt 061, after
   059 and 060)
