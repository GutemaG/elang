---
unit: 002-stat-pill-ui
intent: 013-stat-pill-interactions
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-09-30T05:44:19Z'
updated: '2026-09-30T08:23:49Z'
---

# Unit Brief: Stat Pill UI

## Purpose

Turn the dashboard's four counters into buttons, each opening a sheet
that explains its number, online and offline.

## Scope

### In Scope
- A tappable `StatPill` (`lib/shared/widgets/app_status.dart`) and
  `LessonHud` wiring from the dashboard
- The beans, streak, Amole and XP sheets, built from the design system's
  sheet and card pieces
- `LessonApi` methods for both reads (HTTP and fake)
- Keeping `nextBeanAt`, `regenMinutesPerBean` and `refillCostAmole` in the
  offline dashboard copy
- Gallery entries

### Out of Scope
- The lesson's "Out of Beans!" sheet (unchanged)
- Counters anywhere but the dashboard header
- Today's XP (not on the dashboard response)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Tappable pills | Must |
| FR-2 | Beans sheet | Must |
| FR-3 | Streak calendar | Should |
| FR-5 | Amole sheet | Should |
| FR-7 | XP sheet | Could |

NFR-1 (header), NFR-2 (accessibility), NFR-3 (sheets open at once) and
NFR-4 (offline) apply.

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-tappable-pills | Every counter is a button | Must | Complete (bolt 060) |
| 002-beans-sheet | Beans: next bean and refill | Must | Complete (bolt 060) |
| 003-streak-calendar | Streak: a calendar of practised days | Should | Complete (bolt 061) |
| 004-amole-sheet | Amole: what it is and recent entries | Should | Complete (bolt 061) |
| 005-xp-sheet | XP: what it is | Could | Complete (bolt 061) |

### 001-tappable-pills (FR-1)

**As a** learner, **I want** to tap a counter, **so that** I can find out
what it means.

- [x] Each of the four pills opens the stats sheet on its own tab; it
  presses like the design system's other tappable pieces (reduced motion
  respected).
- [x] The tap areas are the header row's full 48 dp height and split the
  row between the pills (FR-1 as amended at bolt 060's Plan).
- [x] One semantics node per pill, a button, with today's label.
- [x] No overflow in the pinned header at 320 and 360 dp at 1.3× text;
  the header's height is unchanged.
- [x] Works on the dashboard loaded from the offline cache.
- [x] Sheets close by a tap outside, a drag, or a close button.

### 002-beans-sheet (FR-2)

**As a** learner, **I want** to see when my next bean comes and refill
with Amole, **so that** running low is not a dead end.

- [x] Shows "N / max", how often a bean comes back, and a countdown to
  `nextBeanAt` that ticks each second while open.
- [x] At full beans: says they are full, no countdown, no refill.
- [x] At zero on the countdown, the bean count goes up on screen.
- [x] The refill uses `refillBeansWithAmole()` and `refillCostAmole`;
  disabled when unaffordable; a success updates the dashboard's beans and
  Amole at once; a failure says so and changes nothing.
- [x] The offline dashboard copy keeps `nextBeanAt`,
  `regenMinutesPerBean` and `refillCostAmole` (older copies without them
  still load); offline the count and countdown show and the refill is
  disabled with "needs a connection".
- [x] The countdown is not announced every second.

### 003-streak-calendar (FR-3)

**As a** learner, **I want** to see the days I practised, **so that** my
streak feels worth keeping.

- [x] A month grid opening on this month; arrows go back 5 more months
  and no further, and never past this month.
- [x] Practised days are marked; today is marked; days after today or
  before the account existed look not possible, not missed.
- [x] Current streak (same as the pill) and longest streak are shown.
- [x] No lessons: an empty calendar and 0.
- [x] A placeholder while loading; a failed load shows a retry.
- [x] Offline: the current streak and "the calendar needs a connection".
- [x] Days read as, for example, "3 September, practised".

### 004-amole-sheet (FR-5)

**As a** learner, **I want** to see how I earn and spend Amole and my
recent entries, **so that** my balance makes sense.

- [x] The balance and a short explanation: earned by lessons, perfect
  lessons, streak milestones and Practice; spent on bean refills.
- [x] Up to 20 recent entries, newest first: a readable reason per
  source, the signed amount (+10, −50), the date.
- [x] An unknown source shows as "Amole"; no entries shows "No Amole yet".
- [x] A placeholder while loading; a failed load shows a retry.
- [x] Offline: the cached balance, the explanation, and "the list needs a
  connection".

### 005-xp-sheet (FR-7)

**As a** learner, **I want** to know what XP is, **so that** the number
means something.

- [x] Shows the total XP and how a lesson earns XP.
- [x] Lists no past gains and does not suggest a history exists (ADR-8).
- [x] Works offline with the cached total.

---

## Dependencies

### Depends On
`001-stat-pill-service` for stories 003 and 004. Stories 001, 002 and 005
need no backend change. The design system (intent 018) is done.

### Depended On By
None.

## Technical Notes

- `OutOfBeansSheet` cannot be dismissed and is titled "Out of Beans!";
  the beans sheet reuses its refill call and look where it fits, not the
  sheet itself.
- The cached dashboard rebuilds `BeansStatus` in
  `SkillTreeDashboardScreen._loadFromCache`; the three extra fields go in
  `CourseCache.saveDashboard`.
