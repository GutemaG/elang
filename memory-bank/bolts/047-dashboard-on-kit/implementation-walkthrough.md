---
stage: implement
bolt: 047-dashboard-on-kit
created: '2026-09-25T21:22:16Z'
---

## Implementation Walkthrough: screen-migration-ui (dashboard and course picker on the library)

### Summary

- **The dashboard** stands on `AppPage` with the lattice background.
  - Its header shows the library's `StatPill`s.
  - Its section banners are the mockup's white milestone cards.
  - Its path nodes, practice card, sync banner, offline note and status
    pages all come from the library.
- **Courses:** the badge, the drop-down panel and the picker are rebuilt
  on library pieces. The picker opens as the library's sheet.
- **Scrolling:** unchanged. The header stays pinned, and each banner is
  pinned only over its own nodes.
- **Rules test:** every dashboard and course file is off the allow-list.
  The dashboard kept only the review-sheet entry, which bolt 048 then
  removed.

### Structure Overview

The dashboard hands `AppPage` a body with no padding and no scrolling of
its own, so its `CustomScrollView` keeps full control of the pinned header
and banners.

Two components that drew their own borders and shelves moved into the
library, and the feature code now only maps its data onto them:
- the path node (`PathNode`)
- the course glyph (`CourseGlyph`)

### Completed Work

- [x] **`lib/shared/widgets/path_node.dart` (new):** `PathNode`,
  DESIGN.md component 2.
  - **States:** locked, active and completed.
  - **Extras:** the progress ring and the crown badge.
  - **Look:** the shelf from `AppShadows`, token colours, and the label
    pill.
  - **Behaviour:** size, tap and what a screen reader hears are as
    before.
- [x] **`lib/shared/widgets/course_glyph.dart` (new):** `CourseGlyph`,
  moved unchanged. `course_badge.dart` re-exports it.
- [x] **`lib/features/lesson/widgets/skill_path_node.dart`:** now maps a
  skill onto `PathNode`: the state, the "Numbers · 1/2" label, the
  spoken label and the ring.
- [x] **`lib/features/lesson/widgets/category_banner.dart`:** the
  milestone card.
  - An `AppCard` with the Tibeb stripe, holding:
    - the title and subtitle
    - a "N/M Completed" `CountBadge`
    - a gradient `AppProgressBar`
  - Consecutive sections take the primary, secondary and tertiary tones
    in turn, on the border, shelf and bar.
  - `extentOf` still measures the real text and adds the card's exact
    chrome, so the pinned height stays exact.
  - The bar still gives way first if a font reserves a pixel less than
    predicted.
- [x] **`lib/features/lesson/widgets/lesson_hud.dart`:** four `StatPill`s,
  still scaled down together rather than overflowing at 320 px.
- [x] **`lib/features/lesson/widgets/sync_status_banner.dart`:** each
  status is an `InfoBanner`. Offline with packs is neutral, the warnings
  are tertiary, and 30+ days unsynced adds emphasis. The messages are
  unchanged.
- [x] **`lib/features/lesson/screens/skill_tree_dashboard_screen.dart`**
  - The page and the lattice background.
  - Loading is `LoadingState`.
  - "Please sign in again" is `EmptyState` with a primary Sign in.
  - A load failure is `ErrorState` with Retry.
  - The practice entry is a tappable `AppCard` with an `IconBadge`, faded
    and inert when disabled.
  - The download badge is an `IconBadge` per state, with `AppSpinner`
    while downloading, in a 48 px tap target. Each state now has a
    spoken label.
  - The offline note is an `InfoBanner`.
  - The panel's scrim uses the library's scrim colour.
- [x] **`lib/features/courses/course_badge.dart`:** the ink splash is a
  stadium, with no hand-built radius.
- [x] **`lib/features/courses/course_panel.dart`**
  - The surface is an `AppCard` inset under the header.
  - The loading rail shows `AppSpinner`.
  - A failed rail shows its sentence with a compact Retry.
  - The add tile is a square `IconBadge`.
  - Settings and downloads are `ListRow`s.
- [x] **`lib/features/courses/course_picker.dart`**
  - Opens with `showAppSheet`, which brings the handle, the backdrop and
    scrolling.
  - Close is `AppIconButton`, and loading is `AppSpinner`.
  - A failure is `ErrorState` with Retry.
  - Each course is an `AppCard`: selected for the active one, faded when
    coming soon, with an `AppProgressBar` that says "N of M skills".
  - What it returns is unchanged.
- [x] **`lib/shared/screens/home_placeholder_screen.dart`:** `AppPage`
  with an `EmptyState`.
- [x] **Library adjustments**
  - `AppCard`'s content under a top stripe may be squeezed, so a card held
    to a fixed height (a pinned banner) shrinks its content instead of
    overflowing.
  - `CountBadge.verticalChrome()`, and `AppProgressBar.regularHeight` and
    `largeHeight`: what a pinned header needs to know before layout.
- [x] **Gallery:** cases for every `PathNode` state and for `CourseGlyph`.
- [x] **Tests changed only where they found a replaced type or look**
  - **Categories:** the colour test reads each banner's card tone,
    because the face is now white and the tone is on the border.
  - **Amole pill:** it is found by `StatPill`'s diamond icon, not the old
    `paid` icon.
  - **HUD:** the narrow test expects "10,300", since `StatPill` groups
    digits. What a screen reader hears is unchanged.
  - **Panel:** its tap-target test finds the rows as `ListRow`s.

### Key Decisions

- **Banners follow the mockup (checkpoint choice 1):** white cards with
  the tone on the border, shelf and bar, not solid colour.
- **Rail tiles keep their ink splash, without a radius.** A card per tile
  would not fit the rail's 92 px height.
- **The download badge's tap target grew to 48 px.** It sits in the
  node's corner, so the extra area lies over the node.

### Deviations from Plan

- **The download badge has spoken labels now** ("Download for offline
  use", "Downloaded for offline use", "Downloading", "Download failed,
  tap to try again"). Before, a screen reader found an unlabelled button.
- **Otherwise none.**

### Dependencies Added

None.

### Developer Notes

- **Checks:**
  - `flutter analyze` shows the same 13 infos as before.
  - All 952 Flutter tests pass, including all 81 banner-height cases (every text scale, width and script).
  - `dart format` was run on each file this bolt touched.
- **Scroll smoothness** in profile mode on a device remains the manual
  check the plan names.
