---
stage: plan
bolt: 061-streak-and-amole-sheets
created: '2026-09-30T07:57:55Z'
---

## Implementation Plan: streak-and-amole-sheets

### Objective

Fill in the stats sheet's other three tabs on the reads from bolt 059:

- **Streak** (story 003, FR-3): a month calendar of practised days with
  the current and longest streak.
- **Amole** (story 004, FR-5): what Amole is, the balance, and the 20 most
  recent entries.
- **XP** (story 005, FR-7): what XP is and the total.

### What the code says (checked before planning)

- **F1: The XP tab is already done.** Bolt 060 gave it the total and an
  explanation with no history. Only a check against story 005 is left.
- **F2: The sheet is tight.** Measured in bolt 060, the beans tab is 546 dp
  tall on a 360 x 640 phone. A 6-row calendar under the same 88 dp picture
  would not fit, so the streak and Amole tabs need a compact header
  instead of `SheetHero`.
- **F3: The reads.** `GET /api/v1/streak/history?from&to` (at most 186
  days; returns `practised_days`, `current_streak`, `longest_streak`,
  `joined_on`) and `GET /api/v1/amole/transactions?limit` (newest first;
  `amount`, `source`, `created_at`). This month and the 5 before it are
  at most 184 days, so **one request covers all six months**.
- **F4: The day rule is UTC** (the streak's own rule since bolt 005). In
  Ethiopia (UTC+3) a lesson between midnight and 3 am local counts for the
  day before.
- **F5: `LessonApi` has three implementations**: `HttpLessonApi`,
  `FakeLessonApi` (the app's offline demo) and `ControllableLessonApi`
  (tests). `HttpLessonApi._get` takes a path with its query string.
- **F6: The design system has** `AppSpinner`, `ErrorState` (with retry),
  `EmptyState`, `CountBadge`, `IconBadge` and `AppIconButton` (48 dp).
  There is no calendar.

### Decisions

- **D1: Models.** `StreakHistory` (practised days as a set of UTC dates,
  current, longest, join date) and `AmoleEntry` (amount, source, time) in
  `lib/shared/models/stat_history.dart`, parsed defensively.
- **D2: `LessonApi`** gets `getStreakHistory(from, to)` and
  `getAmoleHistory({limit = 20})`, in all three implementations. The
  fake API makes up a believable month of practice and a few entries.
- **D3: Loading.**
  - Each tab loads the first time it is shown, once per opening of the
    sheet: the streak tab asks for all six months at once, so the month
    arrows never wait.
  - A spinner while loading; `ErrorState` with "Try again" on failure.
  - Offline (the dashboard is the saved copy): no request; the tab shows
    the current streak or the Amole balance and says the calendar or the
    list needs a connection.
  - Nothing is saved on the device (this settles the open design
    question): the calendar is quick to fetch and a stale one would be
    misleading.
- **D4: Streak tab.**
  - Compact header: a flame badge, "12 day streak" as the heading, and
    "Longest: 9 days" beside it.
  - Month row: "September 2026" with back and forward `AppIconButton`s.
    Back stops at 5 months ago, forward at this month; a stopped arrow is
    disabled.
  - Weekday initials, Monday first; a 7-column grid of the month's days.
  - A practised day is a filled circle in the streak colour; today has a
    ring; a missed day is plain; a day after today or before the join date
    is faded.
  - Each day is one node for a screen reader: "3 September, practised",
    "4 September, not practised", "today", "not yet".
  - A learner with no lessons sees the empty calendar, "0 day streak" and
    "Longest: 0 days".
  - Days and "today" are UTC (F4), so the calendar always agrees with the
    streak number. A short note under the grid is not added; the rule is
    already the one the streak uses everywhere.
- **D5: Amole tab.**
  - Compact header: a gem badge, "420 Amole" as the heading, and one line:
    "Earned by lessons, perfect lessons, streak milestones and Practice.
    Spent on bean refills."
  - The list: each entry is its reason, its date ("30 Sep") and the amount
    signed (+10 in green, -350 in the error colour), one node each for a
    screen reader ("Bean refill, minus 350 Amole, 30 September").
  - Reasons: welcome bonus (`wallet_created`), starting balance
    (`migration_backfill`), lesson finished, perfect lesson, 7-day streak,
    30-day streak, bean refill, Practice session; anything else "Amole".
  - No entries: "No Amole yet".
- **D6: XP tab** stays as bolt 060 built it (F1); a test pins "no
  history".
- **D7: Where the code goes.** `stat_sheet.dart` keeps the tabs and takes
  two loaders (`loadStreak`, `loadAmole`) from the dashboard, which passes
  its `LessonApi` calls. The calendar is its own widget,
  `streak_calendar.dart`, testable alone; the Amole list is
  `amole_history.dart`.
- **D8: Gallery.** None (feature widgets; the gallery imports no
  features, as in bolt 060).

### Out of scope

- The out-of-date streak number (bolt 059's Q1; a later bolt).
- Local-time days; storing history on the device.

### Tests

- Models: parsing, bad input, the source labels.
- `HttpLessonApi`: both calls' paths and parsing (with the mock client
  the other HTTP tests use).
- `StreakCalendar`: the month grid (days, Monday first, a month starting
  on Sunday, February), practised/today/missed/not-yet looks and labels,
  arrows and their limits.
- Stats sheet: each tab loads once; spinner; retry after an error; offline
  messages; empty learner; the Amole list's order, signs, labels and
  "No Amole yet"; XP has no history.
- Dashboard: the streak and Amole tabs load through `LessonApi`.
- Size: the streak tab fits 360 x 640 without scrolling at 1x.

### Acceptance criteria

- **A. Streak**
  - [ ] Month view, this month and 5 back, arrows limited.
  - [ ] Practised, today, missed and not-yet days look and read
    differently.
  - [ ] Current and longest streak shown; empty learner shows 0.
  - [ ] Spinner, retry, and an offline message; never blank.
- **B. Amole**
  - [ ] Explanation and balance; up to 20 entries newest first, signed,
    with readable reasons; unknown reasons read "Amole".
  - [ ] "No Amole yet"; spinner, retry, offline message.
- **C. XP**
  - [ ] Total and explanation; no history.
- **D. Checks**
  - [ ] `flutter analyze` clean; `flutter test` passes.
  - [ ] On a phone: the calendar matches the days you practised (left
    for a person).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30.

### New

- **`lib/shared/models/stat_history.dart`**: `StreakHistory` (practised
  UTC days as a set, current, longest, join day; `practised(day)`),
  `AmoleEntry` (with `reason` for each ledger source, "Amole" for an
  unknown one), `utcDay`, and defensive `fromJson` for both (a bad day in
  the list is skipped).
- **`lib/features/lesson/widgets/streak_calendar.dart`**: `StreakCalendar`
  (month title with arrows limited to this month and 5 back, Monday-first
  weekday initials, the month's days) and
  `StreakCalendar.firstDayShown(today)`.
- **`lib/features/lesson/widgets/amole_history.dart`**:
  `AmoleHistoryList` (reason, short date, signed amount; one phrase per
  entry for a screen reader; "No Amole yet").
- **`CalendarDay`** in `lib/shared/widgets/app_status.dart`: the day
  circle (filled, ringed, faded), with a gallery case. *Not in the plan:*
  the design-rules test forbids hand-built borders outside the shared
  library, so the circle moved there instead of living in the calendar.

### Changed

- **`LessonApi`**: `getStreakHistory(from, to)` and
  `getAmoleHistory({limit})`, in `HttpLessonApi` (UTC `YYYY-MM-DD`
  query dates), `FakeLessonApi` (the current streak's days plus an older
  run of 9, and five sample entries) and `ControllableLessonApi` (data,
  error, and call records).
- **Stats sheet**: takes `loadStreak` and `loadAmole`; the dashboard
  passes its `LessonApi` reads.
  - The streak and Amole tabs use a compact header (badge, heading, one
    line) over their fetched part, then "Close".
  - Each loads the first time its tab shows, once per opening (the streak
    tab asks for all six months at once); a spinner meanwhile,
    `ErrorState` with "Try again" on failure, and on the saved dashboard
    no request and a line saying it needs a connection.
  - A refill clears the loaded Amole list, so it is fetched again with
    the refill in it.
  - The XP tab is unchanged from bolt 060.

### Tests (+26)

- `test/features/lesson/widgets/streak_calendar_test.dart` (new, 7): the
  month's days, Monday first with the 1st on its weekday (September,
  November starting on a Sunday, February), filled/ringed/faded, each
  day's phrase, arrow limits, a past month's days, and the first day shown
  across a year end.
- `test/features/lesson/widgets/stat_sheet_test.dart` (+11): streak (one
  six-month request, no second on returning, spinner, retry, offline,
  an empty learner); Amole (order, signs, reasons and phrase, empty,
  retry, offline, fetched again after a refill); XP (no history, nothing
  fetched).
- `test/shared/services/http_lesson_api_stats_test.dart` (new, 7): both
  requests' paths, query and parsing, a 422 and a network failure, every
  source's reason, malformed shapes.
- `test/features/lesson/screens/dashboard_stat_sheet_test.dart` (+1): the
  streak and Amole tabs load through `LessonApi` with the right range.

### Sizes with the app's own fonts

Measured in a throwaway test (deleted afterwards):

| Phone | Text | Streak tab (content / room) | Amole tab with 20 entries |
|---|---|---|---|
| 360 x 640 | 1x / 1.3x | 436 / 468, 453 / 485: fits | scrolls |
| 320 x 568 | 1x / 1.3x | 484 / 516, 501 / 533: fits | scrolls |
| 412 x 915 | 1x / 1.3x | fits | scrolls |

A full Amole list is longer than any phone, as a list of 20 would be; the
sheet scrolls, and a drag or a tap outside still closes it.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1490 passed (was 1464).

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1490 passed |
| The four test files of this bolt, repeated | 51 passed, 3 of 3 runs |
| Design rules (`test/design`) | pass, with `CalendarDay` in the library |

### Acceptance criteria

- **A. Streak** (`streak_calendar_test.dart`, `stat_sheet_test.dart`,
  `dashboard_stat_sheet_test.dart`)
  - [x] Month view, this month and 5 back, arrows limited.
  - [x] Practised, today, missed and not-yet days look and read
    differently.
  - [x] Current and longest streak shown; empty learner shows 0.
  - [x] Spinner, retry, and an offline message; never blank.
- **B. Amole** (`stat_sheet_test.dart`, `http_lesson_api_stats_test.dart`)
  - [x] Explanation and balance; up to 20 entries newest first, signed,
    with readable reasons; unknown reasons read "Amole".
  - [x] "No Amole yet"; spinner, retry, offline message.
- **C. XP**
  - [x] Total and explanation; no history.
- **D. Checks**
  - [x] `flutter analyze` clean; `flutter test` passes.
  - [ ] On a phone: the calendar matches the days you practised. Not
    tried yet.

### Not covered here

- The app against the real backend: the request and response shapes are
  checked on each side (bolt 059's endpoint tests, this bolt's
  `MockClient` tests) with the same field names, but not end to end.

### Left for a person

- With the backend running, open the streak tab: the filled days should
  be the days you finished a lesson (UTC), the longest streak should look
  right, and the arrows should go back five months.
- Open the Amole tab: the entries should match what you earned and spent;
  refill beans, then look again.
- Turn on airplane mode: both tabs should say they need a connection.
