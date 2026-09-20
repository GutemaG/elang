---
stage: test
bolt: 029-course-switcher-panel
created: '2026-09-21T07:00:00Z'
---

## Test Report: course-switcher-panel

### Summary

- **Flutter**: 314 passed, 0 failed (284 before this bolt), including the real-backend
  `http_auth_api_e2e_test`
- **`flutter analyze`**: no errors or warnings; the same info-level lints as before this
  bolt, unchanged in kind and count
- **Backend**: untouched by this bolt and not re-run

### Test Files

- [x] `test/features/courses/course_rail_source_test.dart` - new, ADR-15's rule: an empty
      cache leaves the active course alone on the rail; no cache at all still does; an
      opened course joins; a course with progress joins without ever being cached; a
      course neither opened nor progressed stays off; the active course is first whatever
      the catalog order; a coming-soon course is never on the rail even if cached; an
      unreadable cache degrades to the server's list
- [x] `test/features/courses/course_panel_test.dart` - new: a tile per course plus the add
      tile and both entries; exactly one tile announced as current; taps reported; the add
      tile and entries fire; every tile and row is a 48dp target; the entries stay usable
      while the rail loads and after it fails; Retry; horizontal scrolling with nine
      courses at 320dp; no overflow at 360dp and 320dp at 1.3x
- [x] `test/features/lesson/screens/skill_tree_dashboard_course_panel_test.dart` - new,
      the panel on the real dashboard: the badge opens and closes it; tapping outside
      closes it; the course list is not fetched until it is first opened; an opened course
      switches in one tap from the rail; tapping the active course only closes the panel;
      Manage downloads and Course settings each open their screen
- [x] `test/features/courses/course_picker_test.dart` - rewritten for the catalog grouped
      by the language the learner speaks, progress as a bar, the close button, and the
      unchanged switch, active-course, coming-soon, failure and overflow behaviour
- [x] `test/shared/services/course_cache_store_test.dart` - `cachedCourseIds` lists opened
      courses and reads a corrupt cache as nothing opened
- [x] `test/features/lesson/screens/skill_tree_dashboard_course_chip_test.dart` - updated:
      the badge opens the panel, "+ Course" reaches the catalog, switching and failure go
      through it, and the header still does not overflow
- [x] `test/features/lesson/screens/skill_tree_dashboard_offline_test.dart` - updated: two
      cached courses switch in one tap from the rail, and an uncached course is reached
      through "+ Course", which is exactly the case ADR-14 refuses
- [x] `test/features/lesson/screens/skill_tree_dashboard_scroll_test.dart` - updated for
      the catalog's new route; the shell's own assertions are unchanged

### Acceptance Criteria Validation

- ✅ **Badge shows the active course and opens the panel; icon buttons gone**
- ✅ **Rail comes from the course API, exactly one tile ringed**
- ✅ **Tapping another course switches, collapses, and shows that course's tree**
- ✅ **Tapping the active course collapses and changes nothing**
- ✅ **Tapping the badge again, or outside, collapses it**
- ✅ **Opening and closing are animated** (the panel is removed from the tree only once
  the closing animation ends, which the dashboard tests depend on)
- ✅ **The rail scrolls horizontally and clips no tile**
- ✅ **"+ Course" opens the catalog grouped by the language the learner speaks**
- ✅ **Coming-soon courses shown, disabled, unchoosable**
- ✅ **A failed switch keeps the current course and shows a message**
- ✅ **Offline, an uncached course still gives the "Connect to the internet…" message**
- ✅ **Course settings and Manage Downloads each open their screen, in two taps**
- ✅ **Settings' own Course row still opens the catalog and still switches** (its tests
  pass unchanged, which is what keeping `pickAndSwitchCourse`'s signature bought)
- ✅ **Every tile and row is at least 48dp with a button semantic and a label**
- ✅ **No overflow at 320dp and 360dp at 1.3x**
- ✅ **ADR-15 written and indexed**
- ✅ **Suite green, analyze clean, no backend or model file touched**
- ⚠️ **The course name is no longer truncated to `Amh…` at 360dp**: the two icon buttons
  are gone and the overflow tests pass, so the room is there, but "the text is not
  ellipsised" is not asserted by a test. It is on the manual check below.

### Issues Found

Three were found by the tests and fixed in the implementation:

1. **A closed panel was still in the widget tree.** `AnimatedOpacity` at zero hides a
   widget visually but leaves it readable by a screen reader and findable by tests. The
   panel is now removed once the closing animation ends, and kept during it.
2. **The scrim could not be tapped.** As an `Expanded` below the panel in a `Column`, the
   hit test at its own centre landed on the scroll view behind it. Restructured so the
   scrim fills the area under the header and the panel sits on top of it — the standard
   shape, and the one where "tap anywhere the panel is not" actually works.
3. **The catalog's progress bar did not announce itself.** The same
   `container: true, excludeSemantics: true` fix the stat pills needed in bolt 028, for
   the same reason. The course tiles were given it too, so a tile reads as one thing.

### Not Covered

- **Manual on-device check (pending for you)**, after a full `flutter run` rebuild:
  1. Confirm the course name is no longer clipped in the header on your device.
  2. Judge the glyph (`አ`, `A`, `E`) at real size — it is the one deliberately
     unscaled element, so it deserves a look at your largest font setting.
  3. Open and close the panel a few times: the drop and fade are 180ms, which no widget
     test can judge.
  4. With two courses opened, switch from the rail; with one, add the second through
     "+ Course".
  5. Check that Course settings and Manage downloads land where you expect.
- **The rail across devices**: ADR-15 makes it per device by design. Not testable here.
- **Intent 011's own follow-ups**: bottom navigation (deferred 2026-09-21) and clearing
  the cache on log out, which now also empties the rail.
