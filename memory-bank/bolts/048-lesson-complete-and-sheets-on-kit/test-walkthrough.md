---
stage: test
bolt: 048-lesson-complete-and-sheets-on-kit
created: '2026-09-26T05:27:21Z'
---

## Test Report: screen-migration-ui (lesson complete and the lesson sheets on the library)

### Summary

- **Tests:** 1,117 of 1,118 Flutter tests pass.
  - 952 were passing before these three bolts, and 166 are new across
    them.
  - **The one failure** is the end-to-end sign-in test "a garbage Google ID
    token gets a real 401". It needs the backend on port 8000, and it
    failed in each of today's three full runs, with a sign-in failure of
    a different kind than it expects. It passed every time it ran alone
    (three times). It calls the backend directly and touches none of the
    screens these bolts changed, so it looks like a timeout under the
    full suite's load. It is worth a look separately.
- **Checks:** `flutter analyze` shows the same 13 infos as before, and
  `dart format` finds nothing to change in any file these bolts wrote.
- **Coverage:** not measured.
- **Mutation check** (shared by 046 to 048): 72 deliberate breakages of the
  new code, each run against the new tests and the related existing ones.
  - **First run:** 68 caught.
  - **After new tests:** 71 caught. The last, #36, is equivalent: it drops
    the count badge's padding from the banner-height sum, but the title
    and subtitle are always taller than the badge, so the sum never uses
    it.
  - Every file was checked to be restored exactly after its run.

### Test Files

- [x] **`test/features/lesson/screens/lesson_complete_and_sheets_on_kit_test.dart`**
  (57, new)
  - **Lesson complete:**
    - A celebration page, with Continue docked as the primary action and
      the 120 px cup badge.
    - Three stat cards: gold XP, terracotta streak with its ribbon, and
      green accuracy. No ribbon when the streak didn't grow.
    - The daily goal is a gold card, with a bar and "25 / 30 XP today".
      A goal already passed fills the bar, and no goal leaves it empty.
    - Offline, the streak card waits for sync, and the goal card keeps its
      sentence with no bar.
    - Skill progress is a green card with a bar of lessons done, and its
      spoken label.
    - A review shows two green stat cards and a neutral banner.
  - **Level-up:**
    - It opens in the library dialog, not a sheet, laid out by
      `SheetHero`, with a gold "Lv 3" badge and a primary Continue.
    - With no level, there is no badge.
    - Continue, the close button and a tap outside each close it, and the
      summary then goes back.
  - **Review:**
    - It opens in the library sheet, with a primary Review and a "Not now"
      text link.
    - Review returns `true`.
    - "Not now", a tap outside and a swipe down each return `null`.
  - **Exit:**
    - It is terracotta, with Keep learning primary and Leave secondary
      under it.
    - Keep learning returns `false`, Leave returns `true` and a tap
      outside returns `null`.
    - Practice says "practice".
  - **Out of beans:**
    - Neither a tap outside nor a swipe down closes it, and it has no
      handle.
    - The terracotta "0 / 5" badge.
    - The striped timer card: the square hourglass, the countdown and its
      spoken label, a bar at 60 % with 12 of 30 minutes to go, and the
      refill-rate caption.
    - "1 minute" is singular. An unknown rate has no caption and an empty
      bar, and full beans show "--:--".
    - Refill is the orange button with "350 Amole" in its badge, read
      aloud with it. Without enough Amole it is disabled, still showing
      the price.
    - "Not now" is a text link that calls `onDismiss`.
  - **From the real lesson screen:**
    - The close button opens the exit sheet in the library sheet.
    - Running out of beans opens the sheet that can't be dismissed.
  - **Small screens:** lesson complete (with skill progress, offline and
    review) and all four pop-ups fit 320 and 360 px at 1.0x and 1.3x.
- [x] **`test/shared/widgets/screen_migration_library_test.dart`,** for
  this bolt's pieces:
  - A button reads its badge after its label.
  - A badge too wide for half the button shrinks, and the label keeps the
    rest.
  - With room to spare, the badge keeps its own size.
- [x] **Still passing unchanged:** the existing lesson-complete, exit,
  review-mode, out-of-beans and refill tests.

### Acceptance Criteria Validation

**Story 003: lesson complete and the lesson sheets on the library**
- ✅ **Lesson complete is the celebration `AppPage`,** with `StatCard`s,
  the progress cards and bars, the reviews banner and a docked Continue:
  covered.
- ✅ **The pop-ups:** exit, review and out-of-beans use `showAppSheet`
  with `SheetHero`, and level-up uses `showAppDialog` with `SheetHero`.
  Covered.
- ✅ **The main action is primary, a real alternative secondary, and a
  dismissal a text link:** covered for each pop-up.
- ✅ **Each pop-up returns what it did before:** review is `true` or
  `null`; exit is `true`, `false` or `null`; out-of-beans uses its
  callbacks and can't be dismissed; level-up returns nothing. Covered.
- ✅ **A failed completion save still shows its error and retry:** the
  existing lesson-screen tests pass unchanged.
- ✅ **No overflow at 320 and 360 px, at 1.0x and 1.3x:** covered, after
  the fix below.
- ✅ **The rules test passes with these entries removed:** only bolt 049's
  two screens remain on the list.
- ✅ **Existing tests:** none needed changing.

### Issues Found

- **The Refill button overflowed at 320 px with 1.3x text.** The price
  badge left the label no room: 195 of 220 px with the test font, and
  the label drew at 0 px.
  - **Fixed in the library:** a button's badge now takes at most half the
    button, shrinking to fit. The label always keeps the rest, and at
    normal sizes nothing changes.
  - Tests cover both cases.
- **The mutation check found no gaps in this bolt's code.**

### Notes

- **The countdown is drawn once, when the sheet opens,** as before. It
  doesn't tick while the sheet is open.
