---
stage: implement
bolt: 048-lesson-complete-and-sheets-on-kit
created: '2026-09-25T21:22:16Z'
---

## Implementation Walkthrough: screen-migration-ui (lesson complete and the lesson sheets on the library)

### Summary

- **Lesson complete** is the mockup's celebration page:
  - a large cup badge and a large green title
  - three `StatCard`s, the streak one with a "+1 Today" ribbon
  - a daily-goal card and a skill-progress card, each with an
    `AppProgressBar`
  - Continue docked at the bottom
- **The four pop-ups** are laid out with `SheetHero`:
  - exit, review and out-of-beans open with `showAppSheet`
  - level-up opens with `showAppDialog`, as its mockup's centred card
- **Results:** each pop-up returns what it returned before.
- **Rules test:** only bolt 049's two screens are left on the allow-list.

### Structure Overview

Each pop-up's widget now comes with the function that opens it, so the
screens no longer choose a sheet's colours, shape or dismissal
themselves:
- `showExitLessonSheet`
- `showReviewSkillSheet`
- `showOutOfBeansSheet`
- `showLevelUpDialog`

The lesson screen, the complete screen and the dashboard call these.

### Completed Work

- [x] **`lib/features/lesson/screens/lesson_complete_screen.dart`**
  - `AppPage` with the celebration background, and Continue docked as
    `AppButton.primary`.
  - **Stat cards:** XP is gold, the streak terracotta (with its ribbon
    when the streak grew) and accuracy green. Offline, the streak card
    still says "SYNCS WHEN ONLINE".
  - **Daily goal:** a gold-toned `AppCard` with a gradient bar and
    "x / y XP today". Offline, it keeps its sentence.
  - **Skill progress:** an `AppCard` with its headline, a bar for the
    lessons done (in place of the hand-drawn segments) and its detail
    line.
  - **Review:** two `StatCard`s and a neutral `InfoBanner` saying reviews
    earn nothing.
  - **Copy and conditions:** unchanged.
- [x] **`lib/features/lesson/widgets/level_up_sheet.dart`**
  - `SheetHero` with the freeze or crown icon, and a "Lv N" badge on it
    when there is a level.
  - The title and body are unchanged, with a primary Continue.
  - `showLevelUpDialog` opens it in the library's dialog. Continue, the
    close button or a tap outside close it, and it returns nothing.
- [x] **`lib/features/lesson/widgets/review_skill_sheet.dart`**
  - A primary Review returns `true`.
  - A new "Not now" text link returns `null`, as a swipe down does.
- [x] **`lib/features/lesson/widgets/exit_lesson_sheet.dart`**
  - Terracotta tone.
  - Keep learning is primary and returns `false`.
  - Leave is `AppButton.secondary` and returns `true`.
  - A dismissal still stays in the lesson.
- [x] **`lib/features/lesson/widgets/out_of_beans_sheet.dart`**
  - A "0 / 5" `CountBadge` on the illustration.
  - A refill-timer `AppCard` with the Tibeb stripe:
    - an hourglass `IconBadge`
    - "Next bean in" and the countdown (read as before)
    - a bar showing how far the next bean has come
    - "Refills 1 bean every N minutes" under the bar, shown only when the
      rate is known
  - **Refill:** `AppButton.accent` labelled "Refill with Amole", with the
    price as its badge. It is disabled as "Not enough Amole" when the
    account can't afford it.
  - **Not now:** a text link.
  - `showOutOfBeansSheet` can't be dismissed or dragged away.
- [x] **Calls:** `lesson_screen.dart` (exit and out-of-beans),
  `lesson_complete_screen.dart` (level-up) and
  `skill_tree_dashboard_screen.dart` (review) use the new functions.
- [x] **Library:** `AppButton` now reads its badge with its label, so a
  screen reader hears "Refill with Amole, 350 Amole" and the price is
  never only visual.
- [x] **`test/design/design_rules_test.dart`:** removed the entries for
  the complete screen, the lesson screen, the two sheets and the
  dashboard's last entry.

### Key Decisions

- **Level-up is a dialog (checkpoint choice 2).** It matches its mockup,
  and has the mockup's close button.
- **The price moved into the Refill button's badge.** The label reads
  "Refill with Amole" as in the mockup, and the badge carries "350 Amole"
  for both the eye and a screen reader.
- **The exit sheet is terracotta.** An ending is what that tone is for,
  and it matches the gallery's leave sheet.

### Deviations from Plan

- **`AppButton` reads its badge.** This small library change wasn't in
  the plan. Without it, moving the price into the badge would have hidden
  it from a screen reader.
- **The level-up dialog shows a "Lv N" badge** on its illustration, as
  the mockup's level badge does. It uses the crown level the result
  already carries.
- **Otherwise none.** No existing lesson-complete, exit, review or
  out-of-beans test needed changing.

### Dependencies Added

None.

### Developer Notes

- **Checks:**
  - `flutter analyze` shows the same 13 infos as before.
  - All 952 Flutter tests pass. One end-to-end auth test timed out once
    in the full run, and passed on its own against the running backend.
  - `dart format` was run on each file this bolt touched.
- **Small screens:** a scratch run at 320 and 360 px, at 1.0x and 1.3x
  text, found no overflow on lesson complete (normal, offline, review and
  with skill progress) or any of the four pop-ups. The Test stage turns
  this into real tests.
