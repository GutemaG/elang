---
intent: 013-stat-pill-interactions
phase: inception
status: draft
created: '2026-09-21T05:15:00Z'
updated: '2026-09-21T05:15:00Z'
---

# Requirements: Stat Pill Interactions

# Intent Overview

Make the dashboard's stat pills answer the questions they raise. Tapping beans should say
when the next one arrives, tapping the streak should show which days were practised, and
tapping XP and Amole should explain what they are and where they came from. Type:
UI feature plus one new backend read.

Opened from a UX review on 2026-09-21. Units, stories and bolts are **not yet
generated**; this intent holds requirements only until it is picked up.

**Verified against real source before writing** (not assumed):
- No stat pill is tappable. `_HudPill` is a `Semantics` wrapping a `Container`; there is
  no `InkWell`, no `onTap`, anywhere in `LessonHud`.
- **Beans already have everything needed.** `BeansStatus` carries `beans`, `beansMax`,
  `regenMinutesPerBean`, `amoleBalance` and `refillCostAmole`, and `OutOfBeansSheet`
  already exists and already offers an Amole refill. The beans pill needs a presenter,
  not new data.
- **The streak calendar needs a new read, but no new table.** `UserStreak` exists, and
  `LessonAttemptRepository.sum_xp_by_user_between` shows per-day XP is already derivable
  from `lesson_attempts` timestamps over UTC calendar-day boundaries. A per-day history
  endpoint is a new query over existing rows.
- Amole is an append-only ledger (`amole_transactions`, ADR-8) with `source` and
  `reference_id`, so "where your Amole came from" is answerable from data that already
  exists. XP has deliberately **no** equivalent ledger (ADR-8), so XP history is not
  symmetric and must not be assumed to be.
- 011's bolt 028 made each pill a single semantics node. Adding a tap must keep that:
  one node, now a button.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| The pills answer what they raise | Each pill opens something that explains its number | Must |
| Beans stop being a dead end | Tapping beans shows the refill time and the existing Amole refill | Must |
| The streak feels worth keeping | Tapping the streak shows the practised days | Should |

## Functional Requirements

### FR-1: Tappable Pills
- **Description**: Every stat pill becomes a button with a 48dp tap target that opens its
  own detail surface. The pills stay compact enough for the pinned header (011, FR-1).
- **Acceptance Criteria**:
  - Each pill is a button with a meaningful label and a 48dp target
  - Each pill remains one semantics node, as bolt 028 made it
  - The header still does not overflow at 320dp and 360dp at 1.3x text
  - The pills keep working on a dashboard served from the offline cache
- **Priority**: Must

### FR-2: Beans Detail
- **Description**: Tapping beans shows the current count, when the next bean arrives
  (from `regenMinutesPerBean`) and the existing Amole refill offer.
- **Acceptance Criteria**:
  - Shows beans out of max and the time to the next bean
  - Reuses the existing refill path rather than a second implementation
  - At full beans, says so instead of showing a countdown
  - Offline, shows the cached numbers and disables the refill
- **Priority**: Must

### FR-3: Streak Calendar
- **Description**: Tapping the streak opens a calendar of recent days marking which were
  practised, the current streak and the longest streak. Needs a new backend read over
  existing `lesson_attempts` and `UserStreak` data.
- **Acceptance Criteria**:
  - The endpoint returns per-day practised/not for a bounded recent window
  - Day boundaries match the UTC convention the streak policy already uses
  - Query count is constant, with no per-day N+1
  - Offline, the calendar is unavailable with a clear message, not a blank sheet
  - A learner with no attempts sees an empty calendar, not an error
- **Priority**: Should

### FR-4: XP and Amole Detail
- **Description**: Tapping XP or Amole explains what it is and how it is earned. Amole
  may additionally list recent ledger entries.
- **Acceptance Criteria**:
  - Amole's recent entries, if shown, come from `amole_transactions`, not a recomputation
  - XP's surface does not imply a transaction history that does not exist (ADR-8)
  - Both work offline with cached totals
- **Priority**: Could

## Non-Functional Requirements

### NFR-1: Header Integrity
- Nothing here may break 011's pinned header: the pills stay within their computed extent
  at every text scale.

### NFR-2: Accessibility
- One semantics node per pill, announced as a button, label unchanged from today's.

### NFR-3: Performance
- The streak read is constant-query and bounded in window size.

### NFR-4: Offline
- Every pill stays tappable offline; surfaces that need the network say so.

## Scope

**In scope**: tap targets on the four pills; a beans detail surface reusing the existing
refill; a streak calendar with its backend read; XP and Amole explainers.

**Out of scope**: an XP transaction ledger (explicitly rejected by ADR-8); streak freezes
or repair purchases; leaderboards; notifications; per-course stats.

## Open Questions (for Technical Design, not Inception)
- Whether the four surfaces are one component with four modes or four separate sheets.
- The streak window size, and whether it is cached for offline use like the dashboard is.
- Whether the beans countdown ticks live or is computed once on open.
