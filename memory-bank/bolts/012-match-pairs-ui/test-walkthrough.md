---
stage: test
bolt: 012-match-pairs-ui
created: '2026-09-17T07:20:00Z'
---

## Test Report: Match-Pairs UI

### Summary

- **Tests**: 126/127 passed (Flutter full suite, including 8 new). The 1 failure (`http_auth_api_e2e_test.dart`, an `e2e`-tagged test requiring a live backend) is confirmed pre-existing and untouched by this bolt (`git diff` on that file is empty) — same known gap flagged in bolt 009's construction log.
- **Coverage**: no coverage tool run for Flutter (not configured in this project); acceptance criteria validated directly below instead.

### Test Files

- [x] `test/shared/services/http_lesson_api_test.dart` — extended `startLesson`'s existing mixed-exercise test with a `match_pairs` entry; verifies JSON parsing into `MatchPairsExercise` (tiles + `correctPairs`)
- [x] `test/shared/services/lesson_pack_downloader_test.dart` — new test: a match_pairs-only lesson downloads through the real (unmodified) downloader with zero HTTP calls
- [x] `test/features/lesson/screens/lesson_screen_test.dart` — 4 new widget tests: atomic Check-gating (disabled until every tile linked, then grades correctly), incorrect submission requeues the exercise (mirrors the existing multiple-choice retry-loop test), unlink/re-link keeps the pairing one-to-one, and a full download → offline-take → sync-queue round trip

### Acceptance Criteria Validation

- ✅ **A user can complete a `match_pairs` exercise via tap-only interaction**: tap-to-arm/link/unlink verified directly
- ✅ **Checking grades the whole exercise atomically**: verified both correct and incorrect full-submission cases
- ✅ **`LessonController`'s existing grade/advance/Beans-XP/offline-completion-queueing flow runs unchanged**: the retry-loop and offline-queue tests reuse the exact same controller code paths as the other 3 exercise types, with no controller logic forked for this type beyond the new tap-to-link method
- ✅ **A downloaded pack containing a `match_pairs` exercise plays fully offline with zero network calls**: verified end-to-end (real download → offline take → sync queue), not assumed
- ✅ **`flutter analyze` clean, full existing Flutter test suite still passes**: confirmed (same 4 pre-existing unrelated info-lints; 0 existing tests needed changes)

### Issues Found

None. The two corrections from this bolt (atomic-grading UX, content/answer-key split on the backend side) were both caught and resolved during Plan/Implement of this and the prior bolt, not during Test.

### Notes

**Known, deliberate gap** (consistent with this project's existing, documented convention for `SqfliteLessonPackStore`): the real JSON round-trip code added to `lesson_pack_store.dart` (`_exerciseToJson`/`_exerciseFromJson`'s new `match_pairs` branches) is exercised only indirectly — `FakeLessonPackStore` (used by every test above) is a plain in-memory map with no JSON encoding at all, and this project has no `sqflite_common_ffi` dependency to test the real store directly (same gap already accepted for the other 3 exercise types' equivalent code, never flagged as a regression). The new branches are structurally symmetric with the other 3 types' existing (tested-by-precedent-only) branches and required by Dart's exhaustive-switch checking, so a typo would be a compile error, but a semantic mismatch between the two directions would not be caught by any current test. Flagging rather than silently claiming full coverage.
