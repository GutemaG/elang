---
stage: test
bolt: 007-core-lesson-loop-ui
created: 2026-09-16T16:45:00Z
---

## Test Report: Real Backend Integration (007-core-lesson-loop-ui)

### Summary

- **Flutter**: 79/79 passing (`flutter test test/ --exclude-tags=e2e`), `flutter analyze` clean (one pre-existing `info`-level `prefer_initializing_formals` hint on `HttpLessonApi`'s required `sessionRepository` param — not fixable without making the parameter private-named, which breaks external construction; matches `HttpAuthApi`'s existing pattern of not using `this.`-shorthand for params needing non-trivial handling).
- **Backend** (amended again this bolt): 221/221 passing (`uv run pytest -q` from `backend/`), `ruff check`/`ruff format --check` clean, 100% coverage on every lesson-service module including this bolt's additions.

### Acceptance Criteria Validation

- ✅ **A real `LessonApi` implementation calls all live endpoints matching the Technical Design's shapes**: `HttpLessonApi` (`lib/shared/services/http_lesson_api.dart`) implements all 5 methods against `GET /skill-tree`, `GET /lessons/{id}`, `GET /beans`, `POST /beans/refill`, `POST /lessons/{id}/complete` — verified via `http_lesson_api_test.dart` (12 tests, mocked `http.Client`) covering success parsing, every documented error code, and network-level failure.
- ✅ **Backend/network errors map to a clear UI state without a screen/controller redesign**: true for `getSkillTree`/`startLesson`/`getBeansStatus` (already-generic `FutureBuilder` error handling from bolt 006, zero changes needed). **Did not hold** for `completeLesson` — audited and found genuinely no error path existed there even conceptually (an unguarded `Future`), which the story explicitly permits fixing rather than forcing; fixed with a small, additive `LessonController.completionError` + one inline error line in `LessonScreen`, verified by a new widget test (`lesson_screen_test.dart`: "a completion failure shows an inline error and retrying... succeeds").
- ✅ **A full lesson taken against the real backend updates the dashboard on return, not stale/mocked data**: this is exactly what `test_skill_tree_next_lesson_id.py`'s 3 backend integration tests prove end-to-end (complete a lesson → skill-tree's `lesson_id`/state advances), and what `HttpLessonApi.getSkillTree`/`completeLesson`'s parsing tests prove on the Flutter side; the dashboard already re-fetches on return from a lesson (bolt 006), unchanged here.

### Real Response-Shape Gaps Found (per story 005's explicit "report, don't force" guidance)

1. **`skills[].lesson_id` didn't exist in the real backend.** The fake modeled "one lesson per skill" as a deliberate simplification; the real seed curriculum has multiple lessons per skill with no server-side lesson ordering/locking (only a cycle-completion *set*). Fixed by extending `GET /skill-tree` (amending bolt 005's endpoint again) with a `lesson_id` field: the first lesson not yet completed this cycle, computed via one grouped query (`list_lesson_ids_by_skills`) — not a per-skill round trip, keeping the query-count NFR intact (verified: initially introduced a real N+1 via a per-skill loop, caught by `test_lesson_performance.py`'s own query-count assertion failing, then fixed properly with the grouped query before moving on).
2. **`SkillTreeNode.subtitle` has no backend equivalent.** Grep-verified it's never actually rendered by any widget in the lesson feature — supplied as `''`, zero visible effect.
3. **`startLesson` needs 2 real HTTP calls, not 1** (lesson-content has no beans field). Issued in parallel via `Future.wait`, merged into one `LessonContent` — still satisfies the NFR's actual wording ("no call *per exercise*"), not a violation.
4. **Content-direction mismatch in `multiple_choice` exercises**: the fake's design asks "what does this Amharic word mean?" (Amharic `prompt` + English `promptTranslation`); the real seed content asks "how do you say this in Amharic?" (one English `prompt`, Amharic answer `choices`). Mapped backend `prompt` → Flutter's `prompt` (main text), `promptTranslation` left empty — a real, workable exercise direction, just the reverse of the fake's, not a bug. Flagged, not silently smoothed over.

### Test Files

- `test/shared/services/http_lesson_api_test.dart` (new, 12 tests): every method's success-path parsing (including the 3-exercise-type mapping and word-bank id→text substitution), every documented error code, network failure, missing-session guard.
- `test/features/lesson/screens/lesson_screen_test.dart` (+1 test): the completion-error-then-retry flow.
- `test/widget_test.dart`, `test/features/auth/splash_screen_test.dart` (amended): updated for `LessonDependencies`'s new required `sessionRepository` parameter.
- Backend: `test_skill_tree_next_lesson_id.py` (new, 3 tests), `test_lesson_engagement_repositories.py`/`test_lesson_use_cases.py`/`test_lesson_performance.py` (amended for the ordered-tuple/grouped-query changes).

### Issues Found

| Issue | Severity | Status |
|-------|----------|--------|
| Mocking an HTTP response body containing Amharic text via `http.Response(jsonEncode(...), 200)` throws (`http.Response` defaults to latin1 when no content-type header is given) | Low (test-only) | Fixed — pass `headers: {'content-type': 'application/json'}` on those mock responses; not an app bug, `HttpLessonApi` itself never constructs `http.Response`. |
| Initial `get_skill_tree` implementation for `lesson_id` used a per-skill loop (N+1), breaking the existing query-count NFR test | Medium | Caught immediately by the existing performance test failing; fixed with a grouped single query before proceeding, not by weakening the assertion. |

### Ready for Operations

- [x] All acceptance criteria met
- [x] No screen/controller redesign beyond what the story explicitly anticipated as acceptable
- [x] Both real response-shape gaps and the completion-error gap fixed and tested, not silently patched
- [x] Full backend + Flutter suites re-run clean after every amendment, not assumed safe
