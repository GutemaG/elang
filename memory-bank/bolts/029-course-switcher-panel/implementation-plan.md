---
stage: plan
bolt: 029-course-switcher-panel
created: '2026-09-21T05:40:00Z'
---

## Implementation Plan: course-switcher-panel

### Objective

Replace the course chip and the two icon buttons with one control: a course badge in the
pinned header that expands a panel holding a horizontal rail of the learner's courses, a
`+ Course` tile opening the rebuilt catalog, and the entries for course settings and
Manage Downloads. Choosing a course, adding one and reaching settings become one flow
from one place, and the header stops being crowded.

### Deliverables

- A course badge: a compact, script-distinct tile for the active course, replacing
  `_CourseChip` and both icon buttons in the header's leading slot
- An expanding panel below the header: the course rail, `+ Course`, and the two entries
- The rebuilt catalog sheet, grouped by the language the learner speaks
- A way to know which courses the learner has actually opened (see the decision below)
- ADR-15 recording that decision
- Tests for the rail, the catalog, the entries, and a regression pass over the dashboard

### Dependencies

- `028-dashboard-shell` (complete): the panel hangs from the header it built, and
  `_HeaderLeading` is the slot this bolt replaces wholesale.
- No backend change. `GET /courses`, `PUT /users/me/active-course` and the catalog
  endpoint are consumed as they are.

### The Decision This Bolt Has to Make

`GET /api/v1/courses` returns **every** course with `is_active`, `completed_skills` and
`total_skills`. The backend has no concept of "courses I have joined", so a rail of "my
courses" has to be derived on the client. Three candidates were carried from Inception:

1 - **Every available course in the rail**: simplest, but with four seeded courses the
rail becomes the whole catalog and `+ Course` means nothing.
2 - **Active plus any course with progress**: no new state, but a course the learner
switched to and has not finished a skill in disappears from the rail the moment they
switch away — the opposite of what they just did.
3 - **Courses the learner has opened, remembered locally**: needs somewhere to remember it.

**Recommended: 3, using what already exists.** ADR-14's `CourseCacheStore` already holds
one cached dashboard *per course id*, written after every successful load. A cached
dashboard already means exactly "this learner has opened this course". So the rail is the
union of: courses with a cached dashboard, the active course, and any course reporting
progress — ordered with the active one first. It needs one new read on the cache
(`cachedCourseIds`), no backend change, and no new persisted concept.

It degrades honestly: a brand-new learner sees one tile plus `+ Course`; a learner whose
cache was cleared sees their active course and anything with progress, and the rail
refills as they use it. Recorded as **ADR-15**.

### Technical Approach

**Badge.** No flag artwork ships, so the badge shows the first character of the learning
language's own name (`አ` for Amharic, `A` for Afaan Oromo, `E` for English) from the
existing `languageNativeName`, with the language name beside it. Script-distinct, no
assets, and it degrades to a letter for any future language. It keeps a `maxWidth` and
ellipsises, but with both icon buttons gone it has roughly 96dp more room than today —
which is what fixes the `Amh…` truncation reported in the UX review.

**Panel.** A `Stack` over the scroll view, with the panel positioned directly beneath the
header (its extent is already computable via `DashboardHeader.extentOf`). An overlay, not
a sliver, so opening it never reflows the skill path. A full-height scrim beneath it
closes it on tap. Open and close animate with implicit animations, in keeping with the
rest of the app.

**Rail.** A horizontal `ListView` of tiles: badge glyph, language name, from-language, and
a ring on the active one. Each tile is at least 48dp both ways with a button semantic. A
trailing `+ Course` tile opens the catalog. Tapping the active course just closes the
panel. The rail renders from the cached course list when offline, as `CachingCourseApi`
already provides.

**Catalog.** `CoursePickerSheet` regrouped by `fromLanguage` ("For Amharic speakers")
rather than by language taught, each row showing the language learned, its progress as a
bar rather than bare text, and coming-soon rows disabled. `pickAndSwitchCourse` keeps its
signature so `SettingsScreen` needs no change, and the `offline_not_cached` message
stays as it is.

**Entries.** Course settings and Manage Downloads become rows beneath the rail, opening
the same screens with the same dependencies as today.

**Untouched.** `CourseApi`, `CachingCourseApi`'s rules, ADR-14's offline behaviour, the
skill path, the Practice card, `SettingsScreen`'s own layout, every backend file.

### Acceptance Criteria

- [ ] The badge shows the active course and opens the panel; the two icon buttons are gone
- [ ] The rail comes from the course API, with exactly one tile ringed as active
- [ ] Tapping another course switches, collapses the panel, and shows that course's tree
- [ ] Tapping the active course collapses the panel and changes nothing
- [ ] Tapping the badge again, or outside the panel, collapses it
- [ ] Opening and closing are animated
- [ ] The rail scrolls horizontally and clips no tile
- [ ] `+ Course` opens the catalog, grouped by the language the learner speaks
- [ ] Coming-soon courses are shown, disabled, and cannot be chosen
- [ ] A failed switch keeps the current course and shows a message
- [ ] Offline, an uncached course still gives the existing "Connect to the internet…" message
- [ ] Course settings and Manage Downloads each open their screen, in two taps
- [ ] Settings' own Course row still opens the catalog and still switches
- [ ] Every tile and row is at least 48dp with a button semantic and a meaningful label
- [ ] No overflow at 320dp and 360dp at 1.3x with the longest seeded titles
- [ ] The course name is no longer truncated to `Amh…` at 360dp
- [ ] ADR-15 written and indexed
- [ ] Full Flutter suite green, `flutter analyze` clean, no backend or model file touched

### Files Expected to Change

| File | Change |
|---|---|
| `lib/features/courses/course_badge.dart` | New: the header badge |
| `lib/features/courses/course_panel.dart` | New: the expanding panel, rail and entries |
| `lib/features/courses/course_rail_source.dart` | New: derives the learner's courses per ADR-15 |
| `lib/features/courses/course_picker.dart` | Catalog regrouped by spoken language, restyled |
| `lib/shared/services/course_cache_store.dart` | `cachedCourseIds` on the interface and both implementations |
| `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` | `_HeaderLeading` replaced by the badge; the panel as an overlay |
| `memory-bank/bolts/029-.../adr-15-*.md` | The rail-membership decision |
| Tests | Rail, catalog, entries, cache store, and the dashboard regression |

### Risks

- **The panel overlay and the pinned header**: the panel is positioned from the header's
  computed extent, so an extent change silently misplaces it. Tested at both text scales.
- **`SettingsScreen` coupling**: `pickAndSwitchCourse` is shared. Its signature must not
  change, or the settings tests break for the wrong reason.
- **Rail membership when the cache is empty**: a first run has no cached dashboards. The
  active course must always be in the rail, or a new learner sees an empty one.
