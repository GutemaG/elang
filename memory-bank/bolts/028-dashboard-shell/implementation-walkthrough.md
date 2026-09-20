---
stage: implement
bolt: 028-dashboard-shell
created: '2026-09-21T04:00:00Z'
---

## Implementation Walkthrough: dashboard-shell-ui

### Summary

The dashboard is now one scroll surface. A single pinned header carries the course
control and the stat pills, so streak, beans, XP and Amole are readable at any scroll
position instead of scrolling away with the content. Each category's banner pins beneath
that header while its own nodes pass underneath, and is displaced by the next category's.
The sync banner and offline note moved into the scroll view, so the header is the only
fixed chrome and the skill path is what fills the screen.

### Structure Overview

Three new widgets sit under `lib/features/lesson/widgets/`. A shared delegate provides
fixed-extent pinning and a helper that computes a line's exact pixel height from the type
scale, because a pinned sliver must declare its extent before it lays out and cannot read
the ambient text scale itself. The header and the category banner each expose a static
`extentOf` built from that helper, so the screen can hand each pinned sliver a height that
is correct at any text scale rather than a constant that clips at 1.3x. The dashboard
screen assembles the slivers in order and owns a `ScrollController` used only to return to
the top when the course changes.

### Completed Work

- [x] `lib/features/lesson/widgets/pinned_header_sliver.dart` - the fixed-extent pinned
      delegate, a convenience constructor for it, and the line-height helper every
      `extentOf` is built from
- [x] `lib/features/lesson/widgets/dashboard_header.dart` - the dashboard's permanent
      chrome: a leading slot and the stat pills on an opaque surface with a bottom edge;
      owns its own height and the width split between the two
- [x] `lib/features/lesson/widgets/category_banner.dart` - the compact, pinnable category
      bar carrying the same title, subtitle, completed count and progress as before
- [x] `lib/features/lesson/widgets/lesson_hud.dart` - pills reduced to icon and value so
      four of them share a row with the course control; every pill now reads as one
      labelled node to a screen reader
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - rebuilt as one
      `CustomScrollView`; pinned header, banner slivers, Practice card, then per category
      a pinned banner and its nodes; scroll controller and animated return to the top on a
      course change
- [x] `test/features/lesson/widgets/lesson_hud_narrow_test.dart` - updated for the compact
      pills, plus a new test that every pill announces itself

### Key Decisions

- **Extent by arithmetic, not measurement**: every `AppTypography` style declares an
  explicit `height`, so a fixed number of lines has an exactly computable height. Both
  pinned elements fix their line count and ellipsise, which is what makes them correct at
  1.3x text instead of lucky at 1.0x.
- **The category banner became a compact bar**: a bevelled card of variable height cannot
  be pinned honestly. The bar is also what the reference screenshots show. Every string
  and the progress value are unchanged, so the existing assertions still mean something.
- **The streak's text became its semantic label**: "N Day Streak" spelled out cannot share
  a 320dp row with three more pills and a course name. A screen reader reads exactly what
  it read before; sighted users read the number next to the flame.
- **The header splits its width deliberately**: the leading control has rigid tap targets
  that cannot ellipsise, so it claims its share outright and the pills, which scale
  themselves, take the remainder. An even split starved the leading at 320dp and overflowed.
- **Each category is a `SliverMainAxisGroup`**: pinned slivers otherwise *accumulate* at
  the top, each stopping below the last, so every category already scrolled past would
  still be sitting there. Grouping scopes a banner's pin to its own section, which is what
  makes it a section header rather than another piece of permanent chrome.
- **A reload keeps the previous dashboard on screen**: swapping in a spinner tears down
  the scroll view, which detaches the scroll position. Holding the last loaded data means
  the tree stays put on the way back from a lesson, and it also removes a spinner flash
  that was there before this bolt.
- **Scroll-to-top only on a course change**: returning from a lesson keeps its position, so
  the learner comes back to the node they just finished.
- **Course selection untouched**: the chip and the two icon buttons moved into the header
  unchanged, grouped as one leading widget so bolt 029 can replace the whole slot.

### Deviations from Plan

- The plan expected the header row to be a plain flex split. It needed an explicit width
  share, discovered when the 320dp and 360dp overflow tests failed: two 48dp icon buttons
  plus a course chip cannot fit half of a 320dp row.
- The stat pills lost their drop shadow. Kept flat so the pill height is exactly
  computable and the header reads as one surface rather than floating chips on it.
- `_DashboardContent` and `_CategoryBanner` were removed rather than modified;
  `_CategorySection` became `_CategoryNodes` (nodes only, banner now a sibling sliver).
- The plan assumed a pinned sliver per category was enough for "displaced by the next
  one". It is not: pinned slivers stack. `SliverMainAxisGroup` per category was added
  after a test showed both banners pinned together at the top.
- The plan assumed the scroll position survived a reload. It did not, because the
  `FutureBuilder`'s waiting branch replaced the scroll view. `_lastData` was added so a
  reload re-renders the previous dashboard instead. This is a behaviour change beyond
  layout, and it is the one thing in this bolt a reviewer should look at closely.

### Dependencies Added

None.

### Developer Notes

- `SliverPersistentHeaderDelegate.maxExtent` is a getter with no `BuildContext`. Anything
  pinned here must therefore go through `scaledLineHeight` and a static `extentOf`; adding
  a line to the header or the banner without updating its `extentOf` will clip silently.
- Full Flutter suite: 276 passed (275 before this bolt; the extra is the new semantics
  test). `flutter analyze`: no errors or warnings, 13 info-level lints, the same set as
  before this bolt.
- The existing `skill_tree_dashboard_categories_test` position assertions still hold
  because its viewport is taller than the content, so nothing scrolls and the pinned
  banners sit at their natural offsets.
- Bolt 029 replaces `_HeaderLeading` wholesale. It is deliberately one widget with one
  reason to exist, so that swap touches nothing else in the shell.
