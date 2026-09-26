---
stage: test
bolt: 047-dashboard-on-kit
created: '2026-09-26T05:27:21Z'
---

## Test Report: screen-migration-ui (dashboard and course picker on the library)

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

- [x] **`test/features/lesson/screens/dashboard_on_kit_test.dart`** (37,
  new)
  - **The page:**
    - The lattice `AppPage`, leaving padding and scrolling to the pinned
      scroll view.
    - The four stat pills with their kinds, values and bean maximum, and
      "12,340".
    - Loading is `LoadingState`.
    - A failure is `ErrorState` with its copy, the wifi icon and Retry,
      which reloads.
    - An ended session is a terracotta `EmptyState` with a primary Sign
      in.
  - **Banners:**
    - Each is a compact white card with the Tibeb stripe.
    - Sections turn primary, secondary, tertiary, then primary again, with
      the bar in the same tone.
    - The count badge and the bar's value.
    - A section with no skills.
    - `extentOf` is within the card's exact chrome and content.
  - **Nodes:**
    - Each skill is a library `PathNode` in its state.
    - A screen reader hears each node once.
  - **Practice card:** tappable with a chevron when words are due, and
    faded, inert and without a chevron when none are.
  - **Download badge:**
    - A 48 px tap target around a 28 px badge.
    - A spoken label for each state.
    - A failed download shows the terracotta error badge, and tapping it
      downloads again, to the green done badge.
  - **Status banners:**
    - Offline with a saved copy is a neutral banner.
    - Offline with downloads is neutral.
    - Offline with nothing downloaded is terracotta.
    - A failing sync is terracotta.
    - An old queue adds emphasis.
  - **Course panel:**
    - A card, with its entries as list rows.
    - A square add badge.
    - The library spinner while loading.
    - A compact secondary Retry on failure.
  - **Course picker:**
    - It opens as the library sheet, and its round button closes it.
    - The active course's card is chosen, and coming soon is faded and
      inert.
    - Progress is a library bar with its spoken count.
    - A failure is `ErrorState` with Retry.
  - **Placeholder and scrim:** the home placeholder is an `AppPage` with
    an `EmptyState`, and the panel's scrim is the library scrim.
  - **Small screens:** the whole dashboard, offline with every card and
    banner, fits 320 and 360 px at 1.0x and 1.3x, before and after
    scrolling. So does the course picker.
- [x] **`test/shared/widgets/screen_migration_library_test.dart`,** for
  this bolt's pieces:
  - **`PathNode`:**
    - Each state's icon, size, face and shelf, and its sizes.
    - The ring only with progress.
    - The crown badge only when completed with a level.
    - One tap target for the node and its label.
    - A locked node never taps.
    - What a screen reader hears.
  - **`CourseGlyph`:** the glyph, the tile, and the active ring.
  - **Pinned-header heights:** `CountBadge.verticalChrome` at two tones
    and two text scales, and the progress bar's heights.
  - **A striped card held short** squeezes its content rather than
    overflowing, and hugs it otherwise.
- [x] **Changed in Implement, and passing:** the category colour test, the
  Amole icon, the "10,300" HUD test and the panel's row type.
- [x] **Still passing unchanged:** all 81 banner-height cases, the scroll
  and pinning tests, and the course panel, picker and chip tests.

### Acceptance Criteria Validation

**Story 002: dashboard and course picker on the library**
- ✅ **The page:** lattice `AppPage`, `StatPill`s, an `AppCard` practice
  entry, and library banners and nodes, all covered.
- ✅ **Nodes and banners take their colours and shelves from tokens:** the
  rules test passes with those files off the list, and the node tests
  check the shelves.
- ✅ **The course picker is a `showAppSheet` with `AppCard` rows:**
  covered.
- ✅ **The sync banner and offline note are `InfoBanner`s:** covered, with
  each state's tone.
- ✅ **The home placeholder is `AppPage` with `EmptyState`:** covered.
- ✅ **The header stays pinned, and each banner pins only over its own
  nodes:** the existing scroll tests pass unchanged.
- ✅ **No overflow at 320 and 360 px, at 1.0x and 1.3x:** covered.
- ✅ **The rules test passes, with only the sheet entry left for 048:**
  048 then removed that entry too.
- ✅ **Existing tests changed only for replaced types:** four, all noted
  in Implement.
- ⏳ **Scroll smoothness in profile mode on a device:** not run. It is a
  manual step, and still to do.

### Issues Found

- **A screen reader read each path node twice:** its label, then the
  pill's text ("Numbers, active… Numbers · 1/2"). This was true before
  this bolt as well. The node is now one phrase, and still one button
  that taps.
- **The mutation check found two gaps:** the neutral tone of "offline,
  lessons downloaded", and an old queue turning a neutral banner
  terracotta. A test now covers both.

### Notes

- **The scroll-smoothness check still needs a device.** Run the app in
  profile mode and scroll a long course quickly, watching the pinned
  banners.
