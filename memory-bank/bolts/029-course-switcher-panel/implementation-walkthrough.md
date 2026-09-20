---
stage: implement
bolt: 029-course-switcher-panel
created: '2026-09-21T06:20:00Z'
---

## Implementation Walkthrough: course-switcher-panel

### Summary

The dashboard header now carries one course control instead of three. A badge showing the
active course's script glyph drops a panel holding the courses the learner has opened, a
tile to add another, and the two screens that used to be icon buttons competing with the
skill path. The catalog behind "+ Course" was rebuilt around the language the learner
speaks, since that is the axis they choose along. Course selection, adding a course and
reaching settings are now one flow from one place.

### Structure Overview

Everything course-facing lives under `lib/features/courses/`. A badge and a reusable glyph
tile render a course without artwork. A panel widget holds the rail, the add tile and the
two rows, and is pure presentation — it takes a list and four callbacks. A small pure
function derives which courses belong on the rail from the course list plus the offline
cache, per ADR-15. The dashboard screen owns the open/closed state, loads the rail lazily
the first time the panel opens, and floats the panel over the scroll view so opening it
never reflows the tree.

### Completed Work

- [x] `lib/features/courses/course_badge.dart` - the header control and the reusable
      `CourseGlyph`: a course rendered as the first character of its language's own name
- [x] `lib/features/courses/course_panel.dart` - the dropped panel: the horizontal rail,
      the "+ Course" tile, and the course-settings and manage-downloads rows
- [x] `lib/features/courses/course_rail_source.dart` - derives rail membership per ADR-15
- [x] `lib/features/courses/course_picker.dart` - catalog regrouped by the language the
      learner speaks, leaner rows, progress as a bar, a close button; plus the switch-error
      message extracted so the rail and the catalog cannot drift apart
- [x] `lib/shared/services/course_cache_store.dart` - `cachedCourseIds`, the one new read
      ADR-15 needs
- [x] `lib/shared/models/language_names.dart` - `languageGlyph`
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - the badge replaces
      the chip and both icon buttons; panel state, lazy rail load, and the overlay
- [x] `memory-bank/bolts/029-.../adr-15-course-rail-membership.md` - written and indexed
- [x] Existing catalog, badge and offline tests updated to the new interaction

### Key Decisions

- **The rail is the courses the learner has opened** (ADR-15). ADR-14's cache already
  holds one dashboard per course id, written after every successful load, so it already
  records exactly that. One new read, no backend change, no new persisted concept.
- **A glyph instead of a flag**: the first character of the language's own name, so
  Amharic reads as Fidel and Afaan Oromo as Latin. No artwork, and any future language
  gets a sensible letter for free. The glyph does not scale with the text setting, so the
  tile stays square.
- **The panel floats, it does not push**: an overlay positioned from the header's own
  computed extent, so opening it never reflows the skill path. The scrim starts below the
  header, which leaves the badge tappable to close what it opened.
- **The rail loads lazily and is dropped after a switch**: a learner who never opens the
  panel never pays for a course-list fetch, and the next open always reflects the new
  active course.
- **One error message, one place**: `showCourseSwitchError` is shared by the rail and the
  catalog, including the `offline_not_cached` case, so the two cannot diverge.
- **The catalog groups by spoken language**: a learner knows what they speak and is
  shopping for what to learn. It also makes the group headers match the reference the UX
  review pointed at.

### Deviations from Plan

- The plan listed a leaner catalog row "instead of `SelectableOptionCard`". That is what
  was built, and `SelectableOptionCard` is now unused by the catalog but still used by
  onboarding, so it stays.
- The catalog gained a close button, which the plan did not mention. The sheet had no
  affordance for dismissal other than the barrier.
- `_HeaderLeading`, the single-purpose slot bolt 028 left behind, was deleted rather than
  modified — which is what it existed for.

### Dependencies Added

None.

### Developer Notes

- Full Flutter suite: 286 passed (284 before this bolt). `flutter analyze`: no errors or
  warnings, and the same info-level lints as before, unchanged in kind and count.
- **The rail is per device.** With an empty cache it is the active course alone, and every
  other course is behind "+ Course". That is not a bug, and two tests assert it.
- Two semantics wrappers in this bolt need `container: true, excludeSemantics: true`
  (the progress bar, as the stat pills did in bolt 028). Without it the inner widget
  announces itself separately and the intended label never surfaces as its own node.
- Anything that clears cached dashboards now also empties the rail. ADR-14's open
  follow-up ("clear the cache on log out") and ADR-15 have to be considered together.
