---
stage: plan
bolt: 028-dashboard-shell
created: '2026-09-21T03:10:00Z'
---

## Implementation Plan: dashboard-shell-ui

### Objective

Turn the dashboard into one scroll surface whose chrome is a single pinned header. The
stats move out of the scroll body into that header so they never scroll away, the sync
banner and offline note become slivers, and each category's banner pins beneath the
header while its own nodes scroll past. Course selection is untouched: the existing chip
and the two icon buttons simply move into the new header, and bolt 029 replaces them.

### Deliverables

- A shared pinned-sliver helper with a caller-supplied extent
- A dashboard header widget: a leading slot (today the existing course chip and icon
  buttons) plus the stat pills, on its own surface with a bottom edge
- A compact `LessonHud` suited to a single header row, with a semantic label on the
  streak pill that the full-text version carried implicitly
- A compact, pinned category banner carrying the same title, subtitle, completed count
  and progress bar as today
- `SkillTreeDashboardScreen` rebuilt as one `CustomScrollView`, with a `ScrollController`
  and an animated return to the top when the course changes
- Updated dashboard, categories, course-chip, offline and HUD tests, plus a new scroll
  test for pinning and scroll-to-top

### Dependencies

- None outside the repo. Intent 010 is complete and no backend change is involved.
- `flutter/material` only; no new package.

### Technical Approach

**One scroll view.** `build` returns a `Scaffold` → `SafeArea` → `FutureBuilder` →
`CustomScrollView`. The loading and error states keep the screen to themselves exactly as
today. The slivers, in order: pinned header, sync banner, offline note (when the data came
from cache), Practice entry card, then per category a pinned banner followed by that
category's nodes.

**Pinning with a computed extent.** `SliverPersistentHeaderDelegate.maxExtent` is a
getter with no `BuildContext`, so the extent has to be computed by the caller and handed
in. Every `AppTypography` style declares an explicit `height`, so a line's pixel height is
`fontSize * height`, scaled by `MediaQuery.textScalerOf(context)`. Both the header and the
banner therefore use a **fixed number of lines** (one line each for the banner's title and
subtitle, ellipsised) and their height is arithmetic, not measurement. This is what keeps
them overflow-proof at 1.3x text instead of guessing a constant.

**Header.** One row: the leading slot on the left, the stat pills on the right. The pills
become compact (icon plus value) so four of them plus a course control fit at 320dp;
`LessonHud`'s existing `FittedBox` scale-down stays as the final defence. The streak pill
loses its "N Day Streak" text and gains the equivalent `semanticLabel`, so a screen reader
reads the same thing it reads today. Background is `surfaceContainerLowest` with a hairline
bottom border, so nodes scrolling underneath stay legible.

**Category banner.** Recast from a bevelled card to a compact bar, which is both what the
reference screenshots show and what makes a fixed extent honest: title on one line,
subtitle on one line, the existing `x/y Completed` on the right, and the progress bar
underneath. The strings and the progress value are unchanged, so the existing assertions
stay meaningful.

**Physics and scroll position.** `AlwaysScrollableScrollPhysics` wrapping
`BouncingScrollPhysics`, so a course shorter than the viewport still drags and settles.
A `ScrollController` held by the state; `_reload()` animates to offset 0 when the course
changed, rather than jumping. Reloads that are not course changes (returning from a
lesson) keep their position.

**Deliberate reading of "content scrolls under the header".** The header is a pinned
sliver inside the scroll view, not a box above it, so content really does pass beneath it.
That is what makes the opaque surface and bottom edge necessary rather than decorative.

**What this bolt does not touch.** `_CourseChip`, `pickAndSwitchCourse`, the two icon
buttons, `SkillPathNode`, the serpentine offsets, the Practice card's content, the error
state, `_loadFromCache`/`_saveToCache` and every ADR-14 rule.

### Acceptance Criteria

- [ ] One `CustomScrollView` owns the dashboard; no nested vertical scrollable on it
- [ ] Streak, beans, XP and Amole appear once, in the header, not in the scroll body
- [ ] The header is fully visible at offset 0 and after scrolling to the bottom
- [ ] The header is opaque with a bottom edge; content passes beneath it
- [ ] Each category's banner pins beneath the header and is displaced by the next one
- [ ] A single-category course keeps its banner pinned for the whole page
- [ ] A category with no nodes still renders `0/0 Completed` without crashing
- [ ] Banner titles, subtitles, counts and progress values are unchanged from today
- [ ] A course shorter than the viewport is still draggable and settles back
- [ ] Changing course animates the scroll position to the top; returning from a lesson does not
- [ ] The sync banner and offline note appear and disappear without moving the header
- [ ] Existing stat semantics still read, including the streak
- [ ] No overflow at 320dp and 360dp, at 1.0x and 1.3x text, with the longest seeded titles
- [ ] Every affected test is updated to the new structure, not deleted; full suite green
- [ ] `flutter analyze` reports no new errors or warnings
- [ ] No backend, API or Flutter model file is changed

### Files Expected to Change

| File | Change |
|---|---|
| `lib/features/lesson/widgets/pinned_header_sliver.dart` | New: shared delegate taking an extent and a builder |
| `lib/features/lesson/widgets/dashboard_header.dart` | New: leading slot + stat pills on a surface |
| `lib/features/lesson/widgets/category_banner.dart` | New: compact pinned banner, extent computed from the type scale |
| `lib/features/lesson/widgets/lesson_hud.dart` | Compact pills; streak gains a semantic label |
| `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` | One `CustomScrollView`; header, banners, sync/offline slivers; scroll controller |
| `test/features/lesson/screens/skill_tree_dashboard_categories_test.dart` | Updated to the pinned structure |
| `test/features/lesson/screens/skill_tree_dashboard_course_chip_test.dart` | Updated for the header |
| `test/features/lesson/screens/skill_tree_dashboard_offline_test.dart` | Updated for the offline note as a sliver |
| `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` | Updated for the header |
| `test/features/lesson/widgets/lesson_hud_narrow_test.dart` | Updated for the compact pills and streak semantics |
| `test/features/lesson/screens/skill_tree_dashboard_scroll_test.dart` | New: pinning, scroll-to-top, short-course drag |

### Risks

- **Extent drift**: a banner or header whose real content needs more than its computed
  extent clips. Mitigated by fixing the line count, ellipsising, and testing both widths at
  both text scales.
- **Existing position assertions**: `skill_tree_dashboard_categories_test` compares the `dy`
  of banners and nodes. These hold while the content fits the test viewport (no scrolling,
  so pinned headers sit at their natural offsets), which is true of every existing case.
- **`lesson_hud_narrow_test`** asserts the literal `100 Day Streak`. The compact pill
  replaces that text with a semantic label; the test is updated to assert the semantic,
  which is what a user of the screen reader actually gets.
