---
stage: test
bolt: 027-course-offline-and-verification
created: '2026-09-21T01:30:00Z'
---

## Test Report: course-offline-and-verification

### Summary

- **Flutter**: 275 passed, 0 failed (241 before this bolt; includes the real-backend `http_auth_api_e2e_test`, which passed on this run)
- **Backend**: 509 passed, 0 failed (506 before); ruff clean
- **`flutter analyze`**: no errors or warnings; 13 info-level lints, all in existing style

### Test Files

- [x] `test/shared/services/course_cache_store_test.dart` - tree round trip, two courses kept apart, one save leaves the other untouched, course list, active and pending course, overlapping writes, corrupt and damaged cache
- [x] `test/shared/services/caching_course_api_test.dart` - list cached and served offline, offline choice shown as active, offline switch to a cached course (pending) and an uncached one (refused), server rejection never treated as offline, pending switch sent, kept while offline, dropped on rejection, sent before listing
- [x] `test/features/lesson/screens/skill_tree_dashboard_offline_test.dart` - online load saves the course; offline opens the saved copy with the note; course A never shown for course B; no cache keeps the error state; a backend error is not offline; offline switch works for a saved course and is refused for an unsaved one; a pending choice is sent before loading; packs filed under the shown course; no overflow at 360dp and 320dp with 1.3x text
- [x] `test/features/lesson/screens/download_management_screen_test.dart` - each pack under its course, older packs as English to Amharic, deleting one course's pack leaves the other
- [x] `backend/tests/integration/test_seed_course_content.py` - per new pair (3): a lesson pays XP and streak, its words are due, Practice shows them only while that course is active, practising them pays Amole
- [x] Existing splash tests updated to use an in-memory cache (no behaviour change)

### Story Coverage

| Criterion | Covered by |
|---|---|
| A's tree not shown for B | cache store and dashboard offline tests |
| Packs from two courses kept and labelled | download management test |
| Offline, cached target opens from cache | dashboard and caching API tests |
| Offline, uncached target: message, current stays | dashboard and caching API tests |
| Completion queued in A syncs to A after a switch | backend `TestLessonsAreGatedByTheirOwnCourse` (bolt 024) |
| Older data kept as English to Amharic | download management test; no data is deleted |
| XP, streak, Amole, vocab per new course | backend earn-and-practise tests plus bolt 025 tests |
| Words due only in their own course | backend earn-and-practise tests |
| Amharic to Afaan Oromo reads Amharic prompts, Afaan Oromo answers | bolt 025 language-direction tests |
| English to Amharic unchanged | full suites pass; only fixtures changed |

### Not Covered

- **Pack database upgrade (version 1 to 2)**: no sqflite test driver in the repo. Included in your manual check.
- **Manual on-device check (pending for you)**, after a full `flutter run` rebuild:
  1. Switch course from the dashboard and from Settings; restart the app and confirm it is remembered.
  2. Open both courses online, turn on airplane mode, open the picker, switch to the other course, and confirm it opens with the "Offline, showing saved progress" note.
  3. Offline, try a course you never opened: expect the "Connect to the internet…" message.
  4. Turn the network back on: confirm the app ends on the course you chose.
  5. If you already had downloaded lessons, open Manage Downloads and confirm they show "English to Amharic" (this exercises the database upgrade).
  6. Sign up with a new account as an Amharic speaker learning Afaan Oromo.
- **Native-speaker review** of the Afaan Oromo and Amharic content (release blocker, NFR-3).
- **Cache not cleared on log out** (ADR-14 follow-up).
