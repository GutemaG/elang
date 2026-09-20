---
stage: implement
bolt: 027-course-offline-and-verification
created: '2026-09-21T01:00:00Z'
---

## Implementation Walkthrough: course-offline-and-verification

### Summary

Each course now has its own saved copy of the dashboard on the device, so a course opens offline from its last online state and course A's tree is never shown for course B. Switching offline works for a course that was opened before; the choice is kept locally and sent to the server the next time the app can reach it. Manage Downloads now shows which course each downloaded lesson belongs to. The backend gained end-to-end checks that each new course pays XP, streak and Amole and keeps its Practice words to itself.

### Structure Overview

A small file-backed cache (`CourseCacheStore`) holds one dashboard per course id, the last course list, the last known active course, and an offline switch not yet sent. `CachingCourseApi` wraps the real course API: it caches the list, serves it offline, applies the offline-switch rule, and sends a pending switch on request. The dashboard saves after each successful load and, when the network fails, shows the active course's saved copy with a note. Lesson packs keep their lesson-id keys (already unique per course) and gain display-only course columns.

### Completed Work

- [x] `lib/shared/services/course_cache_store.dart` - the cache interface, a JSON file implementation (a damaged file reads as empty; writes are serialised) and an in-memory one for tests
- [x] `lib/shared/services/caching_course_api.dart` - offline rules from ADR-14: cached list offline, switch only to a cached course, pending switch sent before the next load, backend rejections never mistaken for offline
- [x] `lib/shared/services/course_api.dart`, `http_course_api.dart`, `fake_course_api.dart` - one new method, `syncPendingSwitch`
- [x] `lib/shared/models/course.dart`, `skill_tree.dart` - JSON round-trip for the cache
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - sends a pending switch first, saves each online load, falls back to the saved copy with "Offline, showing saved progress"; backend errors still show the error state
- [x] `lib/features/courses/course_picker.dart` - a clear message when an uncached course is chosen offline
- [x] `lib/shared/services/lesson_pack_store.dart`, `lesson_pack_downloader.dart`, `models/downloaded_pack_summary.dart` - packs record their course (database version 2, two nullable columns; older packs read as English to Amharic)
- [x] `lib/features/lesson/screens/download_management_screen.dart` - the course under each pack title
- [x] `lib/features/auth/auth_dependencies.dart`, `lib/main.dart` - the cache is created once and wired to the course API and the dashboard
- [x] `backend/tests/integration/test_seed_course_content.py` - per new pair: a lesson pays XP and streak, its words are due, Practice shows them only while that course is active, and practising them pays Amole
- [x] ADR-14 written and indexed

### Key Decisions

- **Whole-dashboard cache per course**: the smallest thing that meets "never show A's tree for B" and "open from cache".
- **Offline means "no backend answer"**: only a failure with no `error_code` falls back to the cache; an expired session still shows the error state.
- **Pack keys unchanged**: lesson ids are already globally unique and the backend gates a completion by the lesson's own course, so queued completions already sync to the right course after a switch (covered by the bolt 024 tests). Only a display label was added.
- **Cache optional on the dashboard**: an omitted cache keeps the old behaviour, so existing tests needed no change.

### Deviations from Plan

- The plan proposed a possible separate `OfflineCourseGate`; the rules live in `CachingCourseApi` instead, which needed no extra UI plumbing.
- No new Flutter sync-engine test: the sync engine has no notion of courses, and the cross-course guarantee is on the backend.
- The backend audit found bolts 024 and 025 already cover signup, tree, switching, vocab scoping and language direction per pair; only the earn-and-practise flow was missing, and that is what was added.

### Dependencies Added

None.

### Developer Notes

- Full Flutter suite: 275 passed (241 before this bolt). `flutter analyze`: no errors or warnings, only existing info-level lints.
- **Known limits**: the saved copy can be stale (lessons finished offline show on the next online load); the cache is not cleared on log out, the same as lesson packs and the sync queue today (recorded in ADR-14 as a follow-up); the pack database upgrade (version 1 to 2) has no automated test because the repo has no sqflite test driver, so it is on the manual on-device check.
- **To see it on the phone**: restart the backend is not needed; stop and run `flutter run` for a full rebuild. To try offline: open both courses online first, switch on airplane mode, then open the picker.
