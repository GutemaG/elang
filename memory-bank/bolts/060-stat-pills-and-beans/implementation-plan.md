---
stage: plan
bolt: 060-stat-pills-and-beans
created: '2026-09-30T05:51:47Z'
---

## Implementation Plan: stat-pills-and-beans

### Objective

- The four dashboard counters open a sheet when tapped (story
  001-tappable-pills, FR-1).
- The beans part of that sheet shows the count, a live countdown to the
  next bean and the Amole refill, online and offline (story
  002-beans-sheet, FR-2).
- No backend change.

### What the code says (checked before planning)

- **F1: The counters are tiny on a real phone.** Measured in a widget test
  with the app's own fonts (Plus Jakarta Sans), the pinned header at 1x:

  | Width | Counters' area | Each counter (w x h, dp) |
  |---|---|---|
  | 320 | 133 x 14 | 25-40 x 14 |
  | 360 | 173 x 19 | 32-51 x 19 |
  | 412 | 225 x 24 | 42-67 x 24 |

  `LessonHud` puts them in a `FittedBox(scaleDown)`, and the course badge
  takes up to 62 % of the row, so the counters are drawn at 50-85 % size.
  Four separate 48 x 48 targets need at least 192 dp; there are 133-225.
  **FR-1's "48 x 48 per counter" cannot be met without redesigning the
  header** (see D1).
- **F2: The header row is already 48 dp tall** (`DashboardHeader.contentHeight`
  is floored at 48), so a target can be the row's full height.
- **F3: Beans data.** `BeansStatus` has `beans`, `beansMax`, `nextBeanAt`
  (null when full), `regenMinutesPerBean` (30), `amoleBalance`,
  `refillCostAmole`. The HUD shows `tree.beans`; `/beans` gives the same
  number freshly regenerated.
- **F4: The offline copy** (`CourseCache.saveDashboard`) keeps the tree,
  Amole and due count only; `_loadFromCache` fills `regenMinutesPerBean: 0`,
  `refillCostAmole: 0` and no `nextBeanAt`.
- **F5: The refill.** `LessonApi.refillBeansWithAmole()` returns
  `RefillSuccess(newBeans, newAmoleBalance)` or
  `RefillFailure(insufficientAmole)`, and throws `LessonApiException` when
  offline. `OutOfBeansSheet` draws a "Next bean in" card with a progress
  bar and the refill button with its price; its countdown is worked out
  once and shows minutes only up to 59.
- **F6: `StatPill` has another user.** The lesson screen's beans counter
  (`exercise_layout.dart`) must stay a plain, untappable counter.
- **F7: No tab or segmented control** exists in the design system.

### Decisions

- **D1: One stats sheet with four tabs, opened on the tapped counter.**
  *(Needs your approval: it changes FR-1.)*
  - The sheet's top row is the four counters again, full size (at least
    48 dp tall each), acting as tabs; the chosen one is highlighted. The
    body shows that counter's part.
  - The counters' tap areas cover the whole header row: full 48 dp height,
    and each counter's width plus half the gap on each side (the empty
    space left of the first counter goes to it). On a 360 dp phone that is
    about 36-55 dp wide.
  - So a tap that lands on the neighbour costs one more tap on a tab, not
    a wrong sheet with no way across.
  - FR-1 is amended to: "48 dp tall; as wide as the header allows, with a
    tabbed sheet so a near miss is fixed in the sheet." Making the header
    itself roomier is out of scope.
  - This also settles "one component or four" (left open for design).
- **D2: `StatPill` gets optional `onPressed` and `selected`.**
  - With `onPressed` it is one button node with today's label; without it,
    it is exactly today's widget (the lesson screen's counter).
  - Press feedback: a quick scale to 0.94; with reduced motion, none.
  - `selected` (sheet tabs) adds a thicker border in the counter's colour.
- **D3: `LessonHud` takes `onOpen(StatKind)`.** One tap layer over the row
  maps a tap's x to the nearest counter, measured from the drawn counters.
  Semantics stay per counter.
- **D4: `BeansStatus.at(now)`** projects the beans forward: each whole
  `regenMinutesPerBean` past `nextBeanAt` adds a bean, up to the maximum,
  and moves `nextBeanAt` on (null at full). The sheet ticks once a second
  and redraws from it, so the countdown reaching zero adds the bean, and a
  stale offline copy is projected too.
- **D5: The dashboard's beans come from `BeansStatus`**, and the sheet
  hands back a changed status (a bean arrived, or a refill), which the
  dashboard puts in its data. So the counter updates at once, with no
  reload.
- **D6: Beans tab.**
  - "N / max" badge, "Next bean in m:ss" (h:mm:ss past an hour) with the
    progress bar and "Refills 1 bean every 30 minutes".
  - Full: "Your beans are full", no timer, no refill.
  - Refill button with its price, as in the out-of-beans sheet. Disabled
    with "Not enough Amole" when unaffordable, and "Refill needs a
    connection" offline. While sending, it shows a spinner. Success
    updates the tab and the dashboard. A failure or no connection shows a
    short message and changes nothing.
  - The countdown text is excluded from semantics updates; it reads
    "Next bean in 12 minutes" on focus.
  - The "Next bean in" card is pulled out of `OutOfBeansSheet` into a
    shared `BeanTimerCard`, so both sheets look the same; the out-of-beans
    sheet keeps its behaviour.
- **D7: The other three tabs, until bolt 061.** Each shows its number and
  a one-line explanation (for example "Your streak: days in a row with a
  finished lesson"). Bolt 061 fills them in.
- **D8: Offline copy.** `saveDashboard` also stores `next_bean_at`,
  `regen_minutes_per_bean` and `refill_cost_amole`; `CachedDashboard`
  gets them as nullable fields; an older saved entry without them still
  loads (the sheet then shows the count without a timer).
- **D9: Closing.** The sheet closes by a tap outside, a drag, or a close
  button, via the existing `showAppSheet`.
- **D10: Gallery.** A tappable and a selected `StatPill`, and the stats
  sheet on its beans tab (full, counting down, offline).

### Files

- `lib/shared/widgets/app_status.dart`: `StatPill` `onPressed`, `selected`
- `lib/features/lesson/widgets/lesson_hud.dart`: `onOpen`, the tap layer
- `lib/features/lesson/widgets/stat_sheet.dart` (new): the tabbed sheet,
  the beans tab, the three short tabs
- `lib/features/lesson/widgets/bean_timer_card.dart` (new), used by
  `out_of_beans_sheet.dart` too
- `lib/shared/models/beans_status.dart`: `at(now)`, `copyWith`
- `lib/shared/services/course_cache*.dart`: the three extra fields
- `lib/features/lesson/screens/skill_tree_dashboard_screen.dart`: open the
  sheet, take back the new status, save the fields
- `lib/shared/gallery/gallery_status.dart`, `gallery_sheets.dart`

### Tests

- `StatPill`: without `onPressed`, unchanged (not a button); with it, one
  button node with the same label, and a tap calls it; reduced motion.
- `LessonHud`: a tap at each counter's centre and at the row's top, bottom
  and gaps opens the right kind; no overflow at 320 and 360 at 1.3x; the
  lesson screen's counter is still not a button.
- `BeansStatus.at`: before, at and past `nextBeanAt`; several periods;
  capped at full; already full.
- Stats sheet: opens on the tapped tab and switches; beans full; the
  countdown ticks and the bean arrives at zero; refill success updates the
  dashboard counter; unaffordable, failure, no connection and offline.
- Offline copy: the new fields round-trip; an old entry still loads.
- Dashboard: tapping a counter opens the sheet on that tab, online and
  from the offline copy.

### Out of scope

- The streak calendar, the Amole list and the XP sheet (bolt 061).
- Redesigning the header so the counters are bigger (F1): worth its own
  change if you want it.

### Acceptance criteria

- **A. Counters**
  - [ ] Tapping any counter opens the stats sheet on its tab.
  - [ ] Tap areas are the header's full 48 dp height and split the row
    between the counters.
  - [ ] One button node per counter with today's label; the lesson
    screen's counter is unchanged.
  - [ ] No overflow at 320 and 360 dp at 1.3x text; header height
    unchanged.
- **B. Beans**
  - [ ] Count, live countdown and period; full state.
  - [ ] The bean arrives at zero, on the sheet and on the counter.
  - [ ] The refill works, and is disabled when unaffordable or offline.
  - [ ] Offline: saved count and projected countdown.
- **C. Checks**
  - [ ] `flutter analyze` clean; `flutter test` passes.
  - [ ] On a phone: the counters feel easy to hit (left for a person).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30, D1 (one tabbed sheet) included. FR-1 in
`requirements.md` and story 001 in the unit brief were amended to match.

### New

- **`lib/features/lesson/widgets/stat_sheet.dart`**: `showStatSheet` and
  `StatSheet`.
  - The tabs are four `StatPill`s (`selected`, 48 dp `tapHeight`) in a
    `Wrap`.
  - The beans tab: badge, `BeanTimerCard`, refill button (price badge only
    when the price is known), a short error line, and "Close".
  - Full beans: "Your beans are full" with the refill rate; no timer, no
    refill.
  - The streak, XP and Amole tabs: number and one line of explanation
    (`_StatExplainer`), for bolt 061 to fill in.
  - A one-second `Timer` runs only while the beans tab is counting down.
    Each tick redraws from `BeansStatus.at(now)`; a bean that arrives is
    handed to the dashboard. A catch-up found on opening is handed over
    after the first frame (the dashboard cannot rebuild mid-build).
  - The clock is injectable (`now`) for tests.
- **`lib/features/lesson/widgets/bean_timer_card.dart`**: the "Next bean
  in" card, moved out of `OutOfBeansSheet`, plus `formatCountdown`
  (`mm:ss`, `h:mm:ss` from an hour). The out-of-beans sheet uses it and
  otherwise behaves as before (its bar is now clamped to 0..1).

### Changed

- **`StatPill`** is stateful, with optional `onPressed`, `selected`,
  `pressed` and `tapHeight`. Without `onPressed` it is the same widget as
  before (the lesson screen's counter).
- **`LessonHud`** takes `onOpen`. With it, a `GestureDetector` (excluded
  from semantics) fills the space the row is given; a tap goes to the pill
  under it or with the nearer edge, so a gap is split in the middle. It
  shows that pill as pressed while the finger is down.
- **`BeansStatus`**: `isFull`, `at(now)`, `refilled(result)`, `toJson` and
  `fromJson`.
- **`CourseCacheStore.saveDashboard`** takes `beansStatus`, stored as
  `beans_status`; `CachedDashboard.beansStatus` is `null` for older
  entries.
- **Dashboard**: the counters' beans and Amole come from `BeansStatus`;
  `_openStats` opens the sheet (`offline` = the saved copy is showing);
  the sheet's changes go in `_sheetBeans`, shown over the loaded data until
  the next network load. The saved copy's beans are brought up to now on
  loading.
- **Gallery**: a tappable, selectable `StatPill` row. The stats sheet is a
  feature screen, and the gallery (in `lib/shared`) imports no features,
  so it is not in the gallery (a change from D10).

### Tests (+52)

- `test/shared/models/beans_status_test.dart` (new, 10)
- `test/shared/widgets/app_status_test.dart` (+6): not a button without
  `onPressed`, a button with it, the dip and reduced motion, `pressed`,
  `selected`, `tapHeight`.
- `test/features/lesson/widgets/lesson_hud_tap_test.dart` (new, 9): each
  pill, the full height, gaps, the space left of the row, the pressed look,
  one button per pill and no unlabelled tap node, 320 and 360 at 1.3x, and
  no tap area without `onOpen`.
- `test/features/lesson/widgets/stat_sheet_test.dart` (new, 21): tabs,
  countdown, the bean arriving, full, caught up on opening, the ticker
  pausing on other tabs, refill success, spinner, unaffordable, refused,
  no connection, offline, an old copy, closing, fit at 320 and 360 at 1.3x,
  and `formatCountdown`.
- `test/shared/services/course_cache_store_test.dart` (+2): the timing
  round-trips; an older entry still loads.
- `test/features/lesson/screens/dashboard_stat_sheet_test.dart` (new, 4):
  each counter opens its tab, a refill updates the counters, an online load
  saves the timing, and offline the sheet counts down but cannot refill.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1464 passed (was 1412).
- Seen in tests: the beans tab is about 610 dp tall with the test font, so
  on a small phone the sheet scrolls to reach "Close". Worth a look on a
  phone.

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1464 passed |
| The four new test files, repeated | passed 5 of 5 runs (44 tests each) |

### Sheet size with the app's own fonts

Measured in a throwaway widget test (deleted afterwards) that loads Plus
Jakarta Sans, with the beans tab counting down (full beans in brackets):

| Phone | Text | Sheet content (dp) | Fits without scrolling | Tab rows |
|---|---|---|---|---|
| 360 x 640 | 1x | 546 (334) | yes | 1 |
| 360 x 640 | 1.3x | 616 (406) | just under; "Close" at the edge | 1 |
| 320 x 568 | 1x | 594 (382) | no, scrolls about 40 dp (full: yes) | 2 |
| 320 x 568 | 1.3x | 664 (480) | no, scrolls about 115 dp (full: yes) | 2 |
| 412 x 915 | 1x and 1.3x | 542-616 | yes | 1 |

On the smallest phones the counting-down beans tab scrolls, and the tabs
wrap to two rows at 320 dp. The sheet still closes by a tap outside or a
drag, and nothing overflows. Left as is; it can be tightened (a smaller
picture) if it feels cramped on a phone.

### Acceptance criteria

- **A. Counters** (`lesson_hud_tap_test.dart`, `app_status_test.dart`,
  `dashboard_stat_sheet_test.dart`)
  - [x] Tapping any counter opens the stats sheet on its tab.
  - [x] Tap areas are the header's full 48 dp height and split the row
    between the counters.
  - [x] One button node per counter with today's label; the lesson
    screen's counter is unchanged.
  - [x] No overflow at 320 and 360 dp at 1.3x text; header height
    unchanged.
- **B. Beans** (`stat_sheet_test.dart`, `beans_status_test.dart`,
  `course_cache_store_test.dart`, `dashboard_stat_sheet_test.dart`)
  - [x] Count, live countdown and period; full state.
  - [x] The bean arrives at zero, on the sheet and on the counter.
  - [x] The refill works, and is disabled when unaffordable or offline.
  - [x] Offline: saved count and projected countdown.
- **C. Checks**
  - [x] `flutter analyze` clean; `flutter test` passes.
  - [ ] On a phone: the counters feel easy to hit. Not tried yet.

### Left for a person

- On a phone, tap each counter in the dashboard header, including near the
  edges and gaps; the sheet should open on the one meant, or one tab away.
- Open beans while not full: the countdown ticks; refill with enough
  Amole; the counters change at once.
- Turn on airplane mode and reopen the app: beans still counts down, and
  the refill says it needs a connection.
- On a small phone, see whether the beans tab's scrolling is acceptable.
