---
stage: plan
bolt: 048-lesson-complete-and-sheets-on-kit
created: '2026-09-25T20:50:30Z'
---

## Implementation Plan: screen-migration-ui (lesson complete and the lesson sheets on the library)

### Objective

Rebuild the lesson-complete screen, and the level-up, review-skill,
exit-lesson and out-of-beans pop-ups, on the design library, as their
mockups lay them out. Each pop-up returns exactly what it returns today.

### Reference designs (FR-11)

- **`lesson_complete_summary_1` and `_2`:**
  - the celebration glow page
  - the cup in a circle
  - a large green "Lesson Complete!"
  - three stat cards, the streak one with a "+1 TODAY" ribbon
  - an accuracy card with a large bar
  - a warm daily-goal banner
  - a docked Continue
- **`level_up_streak_freeze_modal`:** a centred dialog card with a glowing
  illustration and a level badge, a large title, the body, and a primary
  action.
- **`out_of_beans_refill_modal`:**
  - the illustration circle with a "0 / 5" badge
  - a red title and the body
  - a "Refill timer" card with a bar
  - an orange "Refill with Amole" button carrying a "350 Amole" badge
  - "Not now" as a link
- **Exit and review:** these have no mockup. They follow the out-of-beans
  sheet's pattern, Material 3's "confirmation" bottom sheet: an
  illustration, a title, one line of consequence, then the actions from
  main to least.
- **Not taken from the mockups,** since the story excludes stats and
  features the app doesn't have:
  - gems
  - time spent
  - "Review Mistakes"
  - "Practice for Free Beans"
  - streak shields
  - "View Inventory"
  - the Amharic lines

### Decisions

- **D1: Lesson complete.**
  - **The page:** an `AppPage` with the celebration background, and
    Continue docked as `AppButton.primary`.
  - **Illustration:** the cup, in an `IconBadge`-style circle.
  - **Stat cards:** the three are `StatCard`s. The streak card shows a
    "+1 Today" ribbon when the streak grew.
  - **Offline:** the "syncs when online" variant keeps its text.
  - **Daily goal:** an `AppCard` with an `AppProgressBar` and the same "x
    / y XP today" text. Offline, it keeps its sentence.
  - **Skill progress:** an `AppCard` with its headline, an
    `AppProgressBar` for lessons done, and its detail line. That bar
    replaces today's hand-drawn segments.
  - **Reviews:** two `StatCard`s and an `InfoBanner` explaining that
    reviews earn nothing.
  - **Copy and conditions:** unchanged.
- **D2: Level-up is a dialog.**
  - **The call:** `showAppDialog`, with `SheetHero` inside.
  - **Why not a sheet:** the story names `showAppSheet` for all four
    pop-ups, but the level-up mockup is a centred card, and
    `showAppDialog` was built from that mockup. Checkpoint option: make
    it a sheet instead.
  - **Illustration:** the freeze or crown icon.
  - **Title and body:** unchanged.
  - **Action:** a primary Continue.
  - **Result:** still nothing, and Continue on the summary pops
    afterwards as before.
- **D3: Review skill** opens with `showAppSheet`, using `SheetHero`.
  - **Illustration:** the crown icon.
  - **Actions:** a primary "Review" that returns `true`, and a new "Not
    now" text link that returns `null`, the same as dismissing it today.
    It follows the story's rule that a dismissal is a text link.
- **D4: Exit lesson** opens with `showAppSheet`, using `SheetHero`.
  - **Actions:**
    - "Keep learning" is primary and returns `false`
    - "Leave" is `AppButton.secondary` and returns `true`: the story's "a
      real alternative is secondary"
  - **Dismissing:** still stays in the lesson.
- **D5: Out of beans** opens with `showAppSheet`, using `SheetHero`, and
  still can't be dismissed or dragged away.
  - **Badge:** a `CountBadge` on the illustration, showing "0 / N".
  - **Refill timer:** an `AppCard` with the gradient top stripe.
    - An `IconBadge` hourglass sits beside "Next bean in" and the
      countdown.
    - An `AppProgressBar` shows how far the next bean has come.
    - A caption reads "Refills 1 bean every N minutes".
    - All of it comes from `BeansStatus`, which already has
      `regenMinutesPerBean`.
  - **Refill:** `AppButton.accent`, with the price as its badge. It is
    disabled with "Not enough Amole" as today.
  - **Not now:** `AppButton.text`.
  - **Callbacks:** unchanged.
- **D6: The calls.** The sheets are opened by three screens:
  `lesson_screen.dart` (exit and out-of-beans),
  `lesson_complete_screen.dart` (level-up) and
  `skill_tree_dashboard_screen.dart` (review). They switch from
  `showModalBottomSheet` to `showAppSheet` or `showAppDialog`, keeping
  their dismissal settings.
- **D7: The rules test.** The lesson-complete screen, `lesson_screen.dart`,
  the exit and out-of-beans sheets, and the dashboard's remaining sheet
  entry all come off `_notYetMigrated`.

### Deliverables

- **`lib/features/lesson/screens/`:** `lesson_complete_screen.dart`,
  `lesson_screen.dart` and `skill_tree_dashboard_screen.dart` (the calls
  only).
- **`lib/features/lesson/widgets/`:** `level_up_sheet.dart`,
  `review_skill_sheet.dart`, `exit_lesson_sheet.dart` and
  `out_of_beans_sheet.dart`, each rebuilt on `SheetHero`.
- **`test/design/design_rules_test.dart`:** entries removed.
- **Tests:** existing lesson-complete, exit, out-of-beans, level-up and
  review tests updated only for replaced types. New tests for each
  pop-up's actions and results, and for the complete screen's layout.

### Dependencies

- Bolts 042–044: the library.
- Bolt 047 only shares the dashboard file (the review call). The two
  change different lines.

### Out of Scope

- Stats the app doesn't have.
- Review-mistakes and practice-for-beans features.
- Mascot art. The existing icons fill `SheetHero`'s illustration.

### Acceptance Criteria

- [ ] **Lesson complete** uses `AppPage` with the celebration background,
      `StatCard`s, the progress `AppCard`s with `AppProgressBar`, an
      `InfoBanner` for reviews, and a docked Continue, laid out as its
      mockups.
- [ ] **The pop-ups:** exit, review and out-of-beans use `showAppSheet`
      with `SheetHero`, and level-up uses `showAppDialog` with `SheetHero`,
      laid out as the level-up and out-of-beans mockups.
- [ ] **Actions:** the main action is primary, a real alternative is
      secondary, and a dismissal is a text link.
- [ ] **Results:** each pop-up returns the same result as before:
  - review is `true` or `null`
  - exit is `true`, `false` or `null`
  - out-of-beans uses its callbacks and can't be dismissed
  - level-up returns nothing
- [ ] **Failed saves:** a completion save that fails still shows its error
      and retry.
- [ ] **Small screens:** no overflow at 320 and 360 px, at 1.0× and 1.3×
      text.
- [ ] **The rules test** passes with these entries removed.
- [ ] **Existing tests:** all lesson-complete and sheet tests pass,
      changed only for replaced types.
