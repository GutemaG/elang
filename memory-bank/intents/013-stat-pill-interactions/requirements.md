---
intent: 013-stat-pill-interactions
phase: inception
status: complete
created: '2026-09-21T05:15:00Z'
updated: '2026-09-30T05:44:19Z'
---

# Requirements: Stat Pill Interactions

## Intent Overview

Make the dashboard's four stat pills (streak, beans, XP, Amole) answer the
questions they raise. Each pill becomes a button that opens a sheet
explaining its number. Type: UI feature plus two new backend reads.

Opened from a UX review on 2026-09-21. Picked up 2026-09-30. To keep the
file count small, this file also holds the system context, and the unit
briefs hold their stories.

### Verified against the source (2026-09-30)

- **No pill is tappable.** `StatPill` (`lib/shared/widgets/app_status.dart`,
  bolt 047) is a plain widget; `LessonHud` puts four of them in a row inside
  a `FittedBox(scaleDown)`, so on a narrow header the whole row shrinks.
- **Beans have the data.** `BeansStatus` (from `GET /beans`) carries
  `beans`, `beansMax`, `nextBeanAt` (null when full),
  `regenMinutesPerBean`, `amoleBalance` and `refillCostAmole`. The refill
  call is `LessonApi.refillBeansWithAmole()`.
  `OutOfBeansSheet` already draws the count, a refill timer and the refill
  offer, but it is the lesson's "Out of Beans!" sheet and cannot be
  dismissed.
- **Offline beans are partial.** The cached dashboard rebuilds
  `BeansStatus` with `regenMinutesPerBean: 0`, no `nextBeanAt` and
  `refillCostAmole: 0`.
- **Streak.** `UserStreak` holds `current_streak`, `last_completed_date`
  and `active_freeze_count` only; there is no longest streak. A day counts
  when a lesson is completed on it: the date of the attempt's
  `completed_at` (UTC). Practice sessions do not touch the streak. No code
  ever grants a freeze today.
- **Amole** is an append-only ledger (`amole_transactions`, ADR-8), each
  row with `amount`, `source` (a closed `AmoleSource` list: wallet
  created, migration backfill, lesson completion, perfect lesson, 7- and
  30-day streak milestones, bean refill, practice session) and
  `reference_id`. There is no endpoint that lists it.
- **XP has no ledger** by design (ADR-8), so XP has no history to show.
- Bolt 028 made each pill a single semantics node; that must stay.

## System Context

- **Actors:** the learner, on the dashboard, online or offline.
- **Mobile app:** the pills, four sheets, and two new API calls.
- **Backend:** two new read-only endpoints for the signed-in user. No
  new table, no migration, no change to how streaks, beans or Amole are
  written.
- **Out of the picture:** the admin site, Neon data, R2.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| The pills answer what they raise | Each pill opens a sheet that explains its number | Must |
| Beans stop being a dead end | Tapping beans shows the next bean's time and the Amole refill | Must |
| The streak feels worth keeping | Tapping the streak shows practised days, the current and the longest streak | Should |
| Amole feels earned | Tapping Amole shows where it came from and went | Should |

## Functional Requirements

### FR-1: Tappable Pills
- **Description**: Each of the four pills becomes a button that opens one
  stats sheet on that pill's tab; the sheet's tabs are the four pills at
  full size. The sheet can be closed by a tap outside, a drag or a close
  button.
- **Acceptance Criteria**:
  - Tapping a pill opens the stats sheet on its tab; each pill presses
    like the design system's other tappable pieces.
  - The tap areas are the header row's full 48 dp height, and split the
    row's width between the four pills. (Amended at bolt 060's Plan,
    2026-09-30: measured, the header leaves the pills 133-225 dp in all,
    so four 48 × 48 targets do not fit; a near miss is fixed with one tap
    on a tab.)
  - Each pill stays one semantics node, now announced as a button, with
    the same label as today (for example "5 day streak").
  - The pinned header still does not overflow at 320 dp and 360 dp wide
    at 1.3× text.
  - The pills work on a dashboard loaded from the offline cache.
- **Priority**: Must

### FR-2: Beans Sheet
- **Description**: Shows beans out of the maximum, when the next bean
  arrives and how often beans come back, and the existing Amole refill.
- **Acceptance Criteria**:
  - Shows "N / max" and a countdown to the next bean from `nextBeanAt`,
    ticking each second while the sheet is open.
  - At full beans it says the beans are full instead of a countdown, and
    offers no refill.
  - The refill uses the existing `refillBeansWithAmole()` call and its
    price; it is disabled when the learner cannot afford it, and a
    success updates the dashboard's beans and Amole at once.
  - The countdown reaching zero adds the bean on screen without a reload.
  - The dashboard's offline copy keeps `nextBeanAt`,
    `regenMinutesPerBean` and `refillCostAmole`, so offline the sheet
    still shows the count and the countdown; the refill is disabled with
    a note that it needs a connection.
- **Priority**: Must

### FR-3: Streak Calendar
- **Description**: A month calendar marking the days a lesson was
  completed, with the current streak and the longest streak.
- **Acceptance Criteria**:
  - A practised day is a UTC day with at least one completed lesson,
    the same rule the streak uses. Practice sessions do not mark a day.
  - Opens on this month; arrows go back up to 5 more months (6 in all)
    and forward to this month, no further.
  - Today is marked; days after today and before the account existed are
    shown as not yet possible, not as missed.
  - Shows the current streak (the same number as the pill) and the
    longest streak.
  - The longest streak is worked out from all of the learner's practised
    days, since nothing stores it.
  - A learner with no lessons sees an empty calendar and "0", not an
    error.
  - Offline, the sheet shows the current streak and says the calendar
    needs a connection; it is never blank.
  - Loading shows a placeholder; a failed load shows a retry.
- **Priority**: Should

### FR-4: Streak History Read (backend)
- **Description**: `GET` endpoint returning the signed-in learner's
  practised days in a date range, plus the longest streak.
- **Acceptance Criteria**:
  - Returns the list of practised UTC dates between `from` and `to`, the
    longest streak and the current streak.
  - The range is at most 186 days; a larger or reversed range is
    rejected with 422.
  - A fixed number of queries whatever the range (no query per day).
  - Only the signed-in learner's own attempts; 401 without a session.
  - No attempts gives an empty list and a longest streak of 0.
- **Priority**: Should

### FR-5: Amole Sheet
- **Description**: Explains what Amole is and how it is earned and spent,
  shows the balance, and lists the most recent ledger entries.
- **Acceptance Criteria**:
  - Explains in a few lines: earned by lessons, perfect lessons, streak
    milestones and Practice; spent on bean refills.
  - Lists the 20 most recent entries, newest first: a readable reason for
    each source (for example "Perfect lesson", "Bean refill"), the amount
    signed (+10, −50) and the date.
  - The entries come from `amole_transactions`, never worked out again on
    the device.
  - A learner with no entries sees the explanation and "No Amole yet".
  - Offline, it shows the cached balance and the explanation, and says
    the list needs a connection.
- **Priority**: Should

### FR-6: Amole History Read (backend)
- **Description**: `GET` endpoint returning the signed-in learner's most
  recent Amole ledger entries.
- **Acceptance Criteria**:
  - Returns up to `limit` entries (default 20, at most 50), newest first,
    each with `amount`, `source` and `created_at`.
  - A source the app does not know yet shows as a general "Amole" entry
    rather than failing.
  - One query; only the learner's own rows; 401 without a session.
- **Priority**: Should

### FR-7: XP Sheet
- **Description**: Explains what XP is and how a lesson earns it.
- **Acceptance Criteria**:
  - Shows the total XP. Today's XP is not shown: the dashboard does not
    receive it, and adding it is not worth a backend change here.
  - Explains how XP is earned without listing past gains, since there is
    no XP history (ADR-8).
  - Works offline with the cached total.
- **Priority**: Could

## Non-Functional Requirements

### NFR-1: Header Integrity
- The pills stay within the header's computed extent at every text scale;
  the header's height does not change.

### NFR-2: Accessibility
- One node per pill, announced as a button with today's label.
- Each sheet has a heading, and its countdown is not announced every
  second.
- Calendar days have labels such as "3 September, practised".

### NFR-3: Performance
- Both reads use a fixed number of queries, and the streak range is capped
  at 186 days.
- Opening a sheet is instant; only the calendar and the Amole list wait
  for the network.

### NFR-4: Offline
- Every pill stays tappable offline; parts that need the network say so.

### NFR-5: Compatibility
- Only new endpoints; existing responses do not change, so older app
  versions are unaffected.

## Scope

**In scope**: the four tappable pills; the beans, streak, Amole and XP
sheets; two read endpoints; keeping the beans timing in the offline
dashboard copy.

**Out of scope**: an XP ledger (rejected by ADR-8); streak freezes or
repairs; leaderboards; notifications; per-course stats; storing a longest
streak.

## Decisions (Checkpoint 1, 2026-09-30)

- Amole lists recent entries (needs FR-6).
- The longest streak is worked out from practised days, not stored.
- Only days with a completed lesson count, matching the streak.
- The calendar is a month view going back 6 months.
- Beans timing is kept in the offline dashboard copy (a sensible default,
  not asked).

## Open for Design (not Inception)

- ~~One sheet component with four modes, or four sheets.~~ One tabbed
  sheet (bolt 060, D1).
- Whether the calendar's months are cached after the first load.
