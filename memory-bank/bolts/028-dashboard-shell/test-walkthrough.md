---
stage: test
bolt: 028-dashboard-shell
created: '2026-09-21T04:40:00Z'
---

## Test Report: dashboard-shell-ui

### Summary

- **Flutter**: 284 passed, 0 failed (275 before this bolt), including the real-backend
  `http_auth_api_e2e_test`
- **`flutter analyze`**: no errors or warnings; 13 info-level lints, the same set as
  before this bolt
- **Backend**: untouched by this bolt and not re-run

### Test Files

- [x] `test/features/lesson/screens/skill_tree_dashboard_scroll_test.dart` - new: the
      header survives a scroll to the bottom; the stats are inside the header and appear
      once; a category's banner pins beneath the header while its nodes pass; the next
      category's banner displaces it; a one-category course stays pinned throughout; a
      course shorter than the viewport still drags and settles back to zero; a course
      change returns to the top; coming back from a lesson does not
- [x] `test/features/lesson/widgets/lesson_hud_narrow_test.dart` - updated for the compact
      pills, plus a new test that each pill announces its full label to a screen reader
- [x] `test/features/lesson/screens/skill_tree_dashboard_categories_test.dart` - unchanged
      and still passing: banner content, ordering, the per-category zig-zag restart, an
      empty category, locked nodes, and no overflow at 360dp and 320dp at 1.3x
- [x] `test/features/lesson/screens/skill_tree_dashboard_course_chip_test.dart` - unchanged
      and still passing, including the top-bar overflow cases that drove the header's
      width split
- [x] `test/features/lesson/screens/skill_tree_dashboard_offline_test.dart` - unchanged
      and still passing: the offline note as a sliver, the cached fallback, offline
      switching and the pending switch
- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` - unchanged and
      still passing: node states, the error state, download affordances, Practice

### Acceptance Criteria Validation

- ✅ **One `CustomScrollView` owns the dashboard**: the screen builds a single scroll view;
  no nested vertical scrollable remains
- ✅ **Stats in the header, not the body**: asserted as a descendant of `DashboardHeader`,
  found exactly once
- ✅ **Header visible at offset 0 and at the bottom**: asserted before and after a scroll
  to the end
- ✅ **Header opaque with a bottom edge, content passes beneath**: the header is a pinned
  sliver with its own surface and border
- ✅ **Category banner pins and is displaced by the next**: asserted at the header's bottom
  edge, with the previous banner gone
- ✅ **A one-category course stays pinned throughout**
- ✅ **A category with no nodes renders `0/0`**: existing categories test
- ✅ **Banner strings and progress unchanged**: existing categories test passes untouched
- ✅ **A short course is still draggable and settles**: overscrolls negative under the
  finger, returns to zero on release
- ✅ **Course change animates to the top; a lesson return does not**: both asserted on the
  scroll controller's offset
- ✅ **Sync banner and offline note do not move the header**: they are slivers below the
  pinned header, and the offline test passes unchanged
- ✅ **Stat semantics still read**: all four labels asserted, including the streak's
- ✅ **No overflow at 320dp and 360dp at 1.3x**: existing categories and course-chip
  overflow tests pass
- ✅ **Existing tests updated, not deleted**: only the HUD test changed, and it gained a
  test rather than losing one
- ✅ **`flutter analyze` clean**: no new errors or warnings
- ✅ **No backend, API or model file changed**: the diff is five `lib/` files under
  `features/lesson/` and three test files

### Issues Found

Two were found by the tests and fixed in the implementation, not worked around:

1. **Pinned slivers stack rather than displace.** Both category banners sat at the top
   together. Fixed by wrapping each category's banner and nodes in a
   `SliverMainAxisGroup`, which scopes the pin to that section.
2. **A reload lost the scroll position.** The `FutureBuilder`'s waiting branch replaced
   the scroll view with a spinner, detaching the scroll position, so returning from a
   lesson dropped the learner at the top. Fixed by holding the last loaded dashboard and
   re-rendering it while a reload is in flight. This also removes a spinner flash that
   existed before this bolt.

A third was a flaw in the pre-existing code that only surfaced because a test was finally
written for it: each stat pill exposed a bare number as a second semantics node alongside
its label. Fixed by making each pill one semantics node.

### Not Covered

- **Manual on-device check (pending for you)**, after a full `flutter run` rebuild:
  1. Scroll a long course: the header stays, and each section's banner sits under it and
     hands over to the next.
  2. Check the scroll feel at speed, which no widget test can judge.
  3. Open a lesson and come back: you should return to the same node, with no spinner flash.
  4. Switch course: it should glide to the top rather than jump.
  5. Look at the header at your device's largest font setting.
- **Frame-level scroll performance**: the criterion that the header is not rebuilt per
  frame is met structurally (the pinned delegate rebuilds only when its extent or child
  changes) but is not asserted by a test.
- The course rail, `+ Course`, and relocating Settings and Manage Downloads are bolt 029.
