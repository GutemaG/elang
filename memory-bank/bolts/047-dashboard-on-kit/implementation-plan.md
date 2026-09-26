---
stage: plan
bolt: 047-dashboard-on-kit
created: '2026-09-25T20:50:30Z'
---

## Implementation Plan: screen-migration-ui (dashboard and course picker on the library)

### Objective

Rebuild the dashboard on the design library, as the dashboard mockup lays
it out: the page, header pills, category banners, path nodes, practice
card, sync banner and offline note, the course badge, panel and picker,
and the home placeholder.

Intent 011's scroll behaviour stays exactly as it is: the pinned header,
and a category banner pinned only while its own nodes scroll. Every
dashboard file comes off the rules test's allow-list, except the
review-skill sheet call, which moves with bolt 048.

### Reference designs (FR-11)

- **`4._home_skill_tree_dashboard`:**
  - the lattice background
  - a header of translucent stat pills beside the course control
  - a white "milestone" card with a gradient top stripe, an eyebrow, the
    unit title and subtitle, a "3/5 Completed" count and a progress bar
  - the path of round nodes on shelves: green with a check when done,
    large gold when active, grey with a lock when locked, each with a
    label pill
- **Course picker, which has no mockup:** Material 3's modal bottom sheet
  anatomy, a drag handle and a list of rows, drawn with the library's
  `showAppSheet` and `AppCard`s. The same pattern is used for the
  out-of-beans sheet.
- **Not taken from the mockup,** since the story excludes new content and
  bottom navigation:
  - the bottom tab bar
  - the "START" pill and "Let's go! +20 XP" tooltip under the active node
  - the dotted trail between nodes
  - the mascot peeking in

### Decisions

- **D1: The page.**
  - **Shell:** an `AppPage` with the patterned (lattice) background.
    Its `padded: false` and `scrollable: false` options let the existing
    `CustomScrollView` keep full control of pinning.
  - **Loading, sign-out and errors:**
    - loading is `LoadingState`
    - "session ended" is `EmptyState` with a primary "Sign in"
    - a load failure is `ErrorState` with Retry
    - their copy is unchanged
- **D2: Header pills.** `LessonHud` shows the library's `StatPill`s for
  streak, beans, XP and Amole.
  - Its private pill goes.
  - The narrow-width fitting it does today stays: a pill shrinks rather
    than overflows at 320 px.
  - What a screen reader hears is unchanged.
- **D3: Category banners follow the mockup's milestone card.**
  - **The card:** an `AppCard` with the gradient top stripe.
  - **Inside it:**
    - the category title
    - the subtitle
    - a `CountBadge` "N/M Completed"
    - an `AppProgressBar`
  - **Telling sections apart:** consecutive categories still differ, now
    by tone (primary, secondary, tertiary, in turn) on the card's border,
    shelf and bar, instead of a solid colour.
  - **Pinning:** `extentOf` stays exact at every text scale, so pinning is
    unchanged.
  - **Checkpoint choice:** the alternative is keeping today's solid
    coloured banners, rebuilt from tokens; see the checkpoint.
- **D4: Path nodes join the library.** The path node is DESIGN.md
  component 2. A feature file may not draw borders or shelves, so
  `SkillPathNode` moves to `lib/shared/widgets/path_node.dart` as
  `PathNode`.
  - **Its states:** locked, active and completed, with the progress ring
    and crown badge.
  - **Its parts:** shelves from `AppShadows`, colours from tokens, and the
    label pill.
  - **Behaviour:** size and tap behaviour are unchanged.
  - **The dashboard:** keeps a thin feature wrapper that maps a
    `SkillTreeNode` onto it.
  - **Gallery:** a case for every state.
- **D5: The node's download button.**
  - **The badge:** a small `IconBadge` in a 48 px tap target, and
    `AppSpinner` while downloading.
  - **Behaviour and icons:** unchanged, one per state.
- **D6: The practice card.**
  - **The card:** an `AppCard` that is tappable when enabled, with an
    `IconBadge`, a title, the same subtitles, and a chevron.
  - **Disabled:** faded, as now.
- **D7: Banners.**
  - `SyncStatusBanner` shows its messages through `InfoBanner`, with
    `emphasis` for the escalated one.
  - The offline note is an `InfoBanner` too.
- **D8: Courses.**
  - **`CourseGlyph`:** moves to the library, with a gallery case, for the
    same reason as the node.
  - **`CourseBadge`:** built on library pieces.
  - **`CoursePanel`:**
    - its surface is an `AppCard`
    - its loading is `AppSpinner`
    - its rows are `ListRow`s
    - its "add" tile uses library pieces
  - **The course picker:**
    - opens with `showAppSheet`
    - each course is an `AppCard`, selected for the active one and faded
      when coming soon, with an `AppProgressBar` for progress
    - the close button is `AppIconButton`
    - loading is `AppSpinner`
    - a load error is `ErrorState`
    - what it returns is unchanged
- **D9: The home placeholder.** An `AppPage` with an `EmptyState`.
- **D10: The rules test.** Every dashboard and course file comes off
  `_notYetMigrated`. `skill_tree_dashboard_screen.dart` keeps only
  `rawSheetOrDialog`, for the review-skill sheet, until bolt 048 moves
  that sheet.

### Deliverables

- **`lib/features/lesson/`:**
  - `screens/skill_tree_dashboard_screen.dart`
  - `widgets/lesson_hud.dart`
  - `widgets/category_banner.dart`
  - `widgets/skill_path_node.dart`, now a thin wrapper
  - `widgets/sync_status_banner.dart`
- **`lib/features/courses/`:** `course_badge.dart`, `course_panel.dart`
  and `course_picker.dart`.
- **`lib/shared/screens/home_placeholder_screen.dart`**
- **`lib/shared/widgets/`:** `path_node.dart` and `course_glyph.dart`
  (new), with gallery cases.
- **`test/design/design_rules_test.dart`:** entries removed or narrowed.
- **Tests:** existing dashboard, picker, HUD, banner and offline tests
  updated only for replaced types. New tests for `PathNode`,
  `CourseGlyph` and the new layouts.

### Dependencies

- Bolts 042–044: the library.
- No new packages.

### Out of Scope

- Bottom navigation, new dashboard content, and the review-skill sheet
  (bolt 048).

### Acceptance Criteria

- [ ] **The page:** the dashboard uses `AppPage` with the patterned
      background, `StatPill`s in the header, an `AppCard` practice entry,
      and library banner and node styles, laid out as the mockup.
- [ ] **Nodes and banners:** their colours and shelves come from tokens,
      with no local `Color(0x…)`, `BoxShadow`, border or radius.
- [ ] **The course picker** is a `showAppSheet` with `AppCard` rows.
- [ ] **The sync banner and offline note** are `InfoBanner`s.
- [ ] **The home placeholder** is `AppPage` with an `EmptyState`.
- [ ] **Scrolling:** the header stays pinned, and each category banner is
      pinned only over its own nodes, exactly as before.
- [ ] **Small screens:** no overflow at 320 and 360 px, at 1.0× and 1.3×
      text.
- [ ] **The rules test** passes, with the dashboard files off the list
      except the one sheet entry left for bolt 048.
- [ ] **Existing tests:** all dashboard, picker, HUD and offline tests
      pass, changed only for replaced types.
- [ ] **Scroll smoothness:** checked in profile mode on a device, a
      manual step recorded in the test report.
