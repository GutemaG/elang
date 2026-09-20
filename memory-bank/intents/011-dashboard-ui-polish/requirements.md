---
intent: 011-dashboard-ui-polish
phase: inception
status: complete
created: '2026-09-21T02:00:00Z'
updated: '2026-09-21T02:55:00Z'
---

# Requirements: Dashboard UI Polish

## Intent Overview

Rework the dashboard shell so the learner's eye goes to the course content, not the
chrome around it. The stats header stays pinned while the page scrolls, the whole page
scrolls as one smooth surface, and everything to do with choosing a course, adding a
course and reaching course settings collapses into one clear control in that header.
Type: UI refactor (Flutter only; no backend, schema or API change).

Reference: the learner supplied Duolingo screenshots showing a pinned stat bar, a course
badge that expands into a horizontal course rail with a `+ Course` tile, and a section
banner that stays put while its unit scrolls.

**Verified against real source before writing** (not assumed):
- `SkillTreeDashboardScreen` builds a `Column`: a fixed padded block (course chip +
  two `IconButton`s, `SyncStatusBanner`, optional `_OfflineNote`) above an `Expanded`
  `CustomScrollView`. The header block is outside the scroll view, so it is already
  fixed, but it is a plain `Column`, not a sliver, and it takes vertical space from the
  content on every frame.
- `LessonHud` (streak, beans, XP, Amole) is the **first item inside** the scroll view,
  so the stats scroll away. In the screenshots they never do.
- `_CategoryBanner` is a plain `SliverToBoxAdapter` per category; it scrolls away with
  its nodes. The screenshots keep it pinned above its own section.
- `_DashboardContent` is already a `CustomScrollView` with default physics; no
  `ScrollController`, no custom physics, no scroll-position awareness anywhere.
- `_CourseChip` opens `pickAndSwitchCourse`, a `showModalBottomSheet` grouped by
  "Learn X" with `SelectableOptionCard` rows. Settings' Course row calls the same
  helper. There is no rail, no "add a course" affordance and no per-course settings.
- Manage Downloads and Settings are two `IconButton`s in the dashboard top bar.
  There is no bottom navigation bar anywhere in the app.
- `GET /api/v1/courses` returns **every** course (available and coming soon) with
  `is_active`, `completed_skills` and `total_skills`. The backend has no notion of
  "courses I have joined", so "my courses" has to be derived on the client.
- Highland Pulse tokens live in `AppColors`, `AppSpacing` and `AppTypography`; the
  dashboard uses them exclusively, with no literal hex values.
- Dashboard tests that read the current structure: `skill_tree_dashboard_screen_test`,
  `..._categories_test`, `..._course_chip_test`, `..._offline_test`,
  `course_picker_test`, `settings_screen_test`, `lesson_hud_narrow_test`.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Put the visual focus on course content | Chrome above the scroll area is one compact row; the skill path is the dominant element on first paint | Must |
| Stats and course control always reachable | Streak, beans, XP, Amole and the course control stay visible at any scroll position | Must |
| Course selection, adding a course and course settings read as one clear flow | All three reachable from one control, in at most two taps | Must |
| Nothing already shipped regresses | Existing Flutter suites pass; offline, sync, practice and download behaviour unchanged | Must |

## Functional Requirements

### FR-1: Pinned Dashboard Header
- **Description**: A single compact header pinned to the top of the dashboard at every
  scroll position. It carries the active course badge on the left and the stat pills
  (streak, beans, XP, Amole) on the right. `LessonHud` moves out of the scroll body
  into this header. The two top-bar icon buttons (Manage Downloads, Settings) leave the
  header; their new home is FR-5.
- **Acceptance Criteria**:
  - The header is visible at scroll offset 0 and after scrolling to the bottom
  - Streak, beans, XP and Amole values are present in the header, not in the scroll body
  - The header has a surface and a bottom edge so content scrolling under it stays legible
  - No overflow at 320dp and 360dp with 1.3x text and a long course name
  - Semantics for each stat are preserved (the existing `semanticLabel`s still read)
- **Priority**: Must

### FR-2: One Smooth Scroll Surface
- **Description**: The dashboard becomes a single `CustomScrollView` from the header
  down. The sync banner and the offline note become slivers inside it rather than a
  fixed block above it. Scrolling uses a consistent physics across the page, always
  scrollable even when the content is short, and the list settles smoothly rather than
  clipping hard at the ends.
- **Acceptance Criteria**:
  - One scroll view owns the page; no nested vertical scrollable on the dashboard
  - The page can be dragged and released with the content shorter than the viewport
  - Switching course returns the scroll position to the top with an animation, not a jump
  - The sync banner and offline note appear and disappear without shifting the header
  - Scrolling does not rebuild the header's stat pills on every frame
- **Priority**: Must

### FR-3: Sticky Category Section Banners
- **Description**: Each category's banner (title, subtitle, completed count, progress
  bar) stays pinned directly beneath the header while that category's nodes scroll past,
  and is pushed away by the next category's banner, so the learner always knows which
  section they are in.
- **Acceptance Criteria**:
  - Scrolling within a category keeps its banner visible under the header
  - Reaching the next category replaces the banner with that category's
  - The banner shows the same title, subtitle, completed/total and progress as today
  - A course with one category behaves correctly (banner pinned for the whole page)
  - No overflow at 320dp with a long category title and 1.3x text
- **Priority**: Must

### FR-4: Course Rail in the Header
- **Description**: Tapping the course badge expands a panel directly under the header: a
  horizontal rail of the learner's courses with the active one visibly ringed, each
  labelled with the language it teaches, plus a trailing `+ Course` tile. Tapping another
  course switches to it and collapses the panel. The panel expands and collapses with an
  animation and can be dismissed by tapping the badge again or outside it.
- **Acceptance Criteria**:
  - The rail comes from the course API, never a hardcoded list
  - The active course is the ringed one, and exactly one is ringed
  - Tapping a different course switches, collapses the panel, and shows that course's tree
  - Tapping the active course collapses the panel and changes nothing
  - The panel's open and closed states are animated, not instant
  - The rail scrolls horizontally when it holds more courses than fit
  - Every tile is at least 48dp in both directions
  - A switch that fails leaves the current course active and shows a message
- **Priority**: Must

### FR-5: Add a Course and Course Settings
- **Description**: The `+ Course` tile opens the full catalog, rebuilt as a clear list
  grouped by the language the learner speaks ("For Amharic speakers"), with coming-soon
  courses disabled. The expanded panel also carries the two entries that left the top
  bar: course settings (the existing Settings screen) and Manage Downloads.
- **Acceptance Criteria**:
  - `+ Course` opens the catalog; choosing an available course switches to it
  - Coming-soon courses are shown, disabled, and cannot be chosen
  - Settings and Manage Downloads are each reachable from the dashboard in two taps
  - The Settings screen's own Course row still opens the catalog and still works
  - Dismissing the catalog changes nothing
  - No overflow at 320dp and 360dp with 1.3x text and long titles
- **Priority**: Must

### FR-6: Behaviour Preserved
- **Description**: Every dashboard behaviour that exists today keeps working: skill node
  taps and locked nodes, per-node download affordances, the Practice entry card with its
  offline and nothing-due states, the sync status banner, the offline saved-progress note,
  the error state with Retry, and reload-on-return from a lesson.
- **Acceptance Criteria**:
  - Existing Flutter suites pass; dashboard tests are updated to the new structure, not deleted
  - Offline behaviour from ADR-14 is untouched (fallback, pending switch, cached list)
  - `flutter analyze` reports no new errors or warnings
  - No backend, API or model change is made by this intent
- **Priority**: Must

## Non-Functional Requirements

### NFR-1: Design Token Discipline
- Every colour, spacing and radius comes from `AppColors`, `AppSpacing`, `AppRadii` and
  `AppTypography`. No new literal hex values; a genuinely new token is added to the token
  file, not inlined at the call site.

### NFR-2: Layout Robustness
- No overflow at 320dp and 360dp width with 1.3x text scaling, with the longest
  course title, category title and language name in the seeded content.

### NFR-3: Accessibility
- The course badge, rail tiles, `+ Course`, settings and downloads entries all expose a
  button semantic with a meaningful label, and every tap target is at least 48dp.
  Existing stat semantics are unchanged.

### NFR-4: Scroll Performance
- Pinning and the expanding panel must not rebuild the skill path on scroll. Animations
  run in the compositor-friendly way the app already uses (implicit animations or a
  single controller), with no per-frame `setState` over the whole tree.

### NFR-5: No Scope Creep into Content
- The skill node visuals, the serpentine path, the Practice card content and the lesson
  screens are out of scope; only their placement inside the new shell may change.

## Scope

**In scope**: the dashboard shell (pinned header, one scroll surface, sticky category
banners), moving `LessonHud` into the header, the course badge and expanding course rail,
the `+ Course` catalog rebuild, relocating Settings and Manage Downloads, and updating the
affected widget tests.

**Out of scope**: backend, API or model changes; a bottom navigation bar; a profile
screen; per-course streaks or stats; redesigning skill nodes, the lesson screens or
Settings' own layout; app-interface localisation; flag artwork or new illustrations.

## Open Questions (for Technical Design, not Inception)
- How "my courses" is derived for the rail, given the API returns every course:
  active plus any with progress, a locally remembered recent list in `CourseCacheStore`,
  or every available course with the rest behind `+ Course`.
- Whether the course badge shows a language code, a generated initial, or a flag, given
  no flag artwork ships today.
- Whether the sticky category banner is a `SliverPersistentHeader` per category or a
  single header driven by the scroll position.
- Whether the expanding panel is an overlay above the scroll view or a sliver that
  pushes content down.
