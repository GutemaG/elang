---
stage: implement
bolt: 020-practice-ui
created: '2026-09-18T00:00:00Z'
---

## Implementation Walkthrough: practice-ui

### Summary

Practice is now end-to-end: a learner sees an accurate due-count on the dashboard, taps into a session assembled from due vocab items' linked exercises (rendered through the exact same exercise-engine widgets a regular lesson uses), and completes it through a small, dedicated backend path that awards XP/Amole and updates vocab progress without touching the daily streak or skill-tree progression.

### Structure Overview

Backend: a new `practice_attempts` table + repository mirrors `LessonAttempt`'s idempotency shape; a new `complete_practice_session` application use case reuses the vocab-progress-update logic already extracted for `complete_lesson`; `GET /api/v1/practice/due-items` now returns full exercise content per item (via a mapping function shared with the regular lesson-content endpoint, so the two can't drift). Frontend: `LessonController` gained an `isPractice` flag that guards Beans consumption/interruption and swaps `completeLesson` for `completePracticeSession` at finish time; `LessonScreen` gained a `LessonScreen.practice` named constructor that skips the `startLesson`/offline-pack fetch entirely and hides the beans indicator; `SkillTreeDashboardScreen` gained a due-count card that assembles a `LessonContent` directly from fetched due items and launches practice mode.

### Completed Work

**Backend**:

- [x] `backend/app/domain/lesson/value_objects.py` - `AmoleSource.PRACTICE_SESSION` and `AMOLE_PRACTICE_SESSION_AWARD`
- [x] `backend/app/domain/lesson/entities.py` - `PracticeAttempt` entity
- [x] `backend/app/domain/lesson/repositories.py` - `list_exercises_by_vocab_item_ids` widened to return full exercises; new `PracticeAttemptRepository` protocol
- [x] `backend/app/domain/lesson/exceptions.py` - `InvalidPracticeCompletionError`
- [x] `backend/app/infrastructure/api/error_handlers.py` - registers the new exception's status code
- [x] `backend/app/infrastructure/db/lesson_models.py` - widened Amole source CHECK constraint; new `PracticeAttemptModel`
- [x] `backend/app/infrastructure/api/exercise_mapping.py` - new shared exercise-to-response mapping, extracted out of `lesson_routers.py` so both it and `practice_routers.py` reuse the same code
- [x] `backend/app/infrastructure/api/lesson_routers.py` - now calls the shared mapping function instead of its own private copy
- [x] `backend/app/infrastructure/db/lesson_repositories.py` - `list_exercises_by_vocab_item_ids` resolves full domain entities; new `SqlAlchemyPracticeAttemptRepository`
- [x] `backend/app/infrastructure/api/lesson_dependencies.py` - `get_practice_attempt_repository`
- [x] `backend/app/infrastructure/api/lesson_schemas.py` - `DueItemResponse` carries full exercise content; new practice-completion request/response schemas
- [x] `backend/app/application/lesson_use_cases.py` - extracted `_apply_vocab_progress_update` (shared by `complete_lesson` and the new use case); new `complete_practice_session` use case
- [x] `backend/app/infrastructure/api/practice_routers.py` - due-items endpoint now returns full exercise content; new `POST /api/v1/practice/complete`
- [x] `backend/app/infrastructure/db/migrations/versions/c29bf2c53433_*.py` - creates `practice_attempts`, widens the Amole source constraint

**Frontend**:

- [x] `lib/shared/models/due_item.dart` - client model for a due vocab item with its full exercise
- [x] `lib/shared/models/practice_completion_result.dart` - client models for a practice result/completion response
- [x] `lib/shared/services/lesson_api.dart` / `http_lesson_api.dart` / `fake_lesson_api.dart` - `getDueCount`, `getDueItems`, `completePracticeSession`
- [x] `lib/features/lesson/state/lesson_controller.dart` - `isPractice` mode: bypasses Beans consumption/interruption, calls the practice-completion API at finish time, maps its response into the existing completion-result shape with streak/crown fields at their "not applicable" defaults
- [x] `lib/features/lesson/screens/lesson_screen.dart` - `LessonScreen.practice` named constructor (skips the `startLesson`/offline-pack fetch), and the beans indicator is hidden in practice mode
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - new due-count entry card, disabled (not hidden) when offline or when nothing is due; tapping it assembles a `LessonContent` from fetched due items and launches `LessonScreen.practice`

**Tests** (both new coverage and fixture updates needed by the widened return types):

- [x] `backend/tests/unit/test_practice_session_use_cases.py` - new, covers `complete_practice_session`
- [x] `backend/tests/integration/test_practice_endpoints.py` - extended with the new completion endpoint's tests, including that it does not advance the daily streak
- [x] `backend/tests/integration/test_lesson_engagement_repositories.py` - extended with `PracticeAttemptRepository` coverage; fixed for the widened return type
- [x] `backend/tests/unit/test_due_items_use_cases.py` - fixed for the widened return type
- [x] `backend/tests/fakes.py` - fake repository updated to match the widened return type
- [x] `test/helpers/controllable_lesson_api.dart` - practice-mode fields/methods
- [x] `test/features/lesson/screens/lesson_screen_test.dart` - practice-mode group: beans indicator hidden, wrong answers don't decrement beans or interrupt, completion calls the practice endpoint (not the regular one) with correctness per vocab item
- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` - practice-entry-card group: due count shown and disabled when zero, disabled (not hidden) when offline, tapping it launches and completes a session and the due count refreshes; existing tests updated for the new required `dueCount` field

### Key Decisions

- **Beans indicator hidden entirely in practice mode**: identified while reading `_ProgressHeader` at Construction time -- it unconditionally displayed `beansRemaining`, which would show a static, meaningless number since Beans consumption is fully bypassed for Practice. Hidden via a simple `if (!controller.isPractice)` guard rather than restructuring the header.
- **Dashboard due-count card reuses `SyncEngine.isOnline`, not a fresh `ConnectivityMonitor.isOnline()` poll**: `SyncStatusBanner` already listens to the same `SyncEngine` reactively on this screen, so the practice card follows the same pattern instead of introducing a second connectivity-polling path.
- **`LessonContent` for a practice session uses empty-string sentinel `lessonId`/`skillId` and zeroed beans fields**: none of these are ever read in practice mode (Beans logic is bypassed, and completion doesn't key off `lessonId`), so no real values exist to put there.

### Deviations from Plan

None -- all three deliverables (backend completion path, widened due-items endpoint, `LessonController`/`LessonScreen` practice mode) were implemented as scoped in `implementation-plan.md`. The dashboard entry card's exact visual treatment (a single tappable card with an icon, title, and subtitle, reusing existing theme tokens) wasn't specified in the plan beyond "due-count display, disabled when offline" -- built in the same deliberately-plain style as this screen's existing `SyncStatusBanner`/`_DownloadAffordance`, consistent with this codebase's convention of prioritizing capability over visual polish for these first-cut affordances.

### Dependencies Added

None -- no new packages on either side.

### Developer Notes

- `Navigator.pushReplacement` (used by `LessonScreen` to swap itself for `LessonCompleteScreen` at finish time) resolves the *original* `Navigator.push` future immediately at replacement time, not when `LessonCompleteScreen` is later popped. This matters for the dashboard's `_reload()` timing (it fires once, at replacement) -- worth remembering if a future bolt adds more post-completion dashboard state that depends on fresh data.
- `flutter analyze` and `flutter test --exclude-tags=e2e` are both clean (163 passing, zero regressions to the pre-existing regular-lesson flow); the 12 e2e-tagged tests in `http_auth_api_e2e_test.dart` still require a running backend and are unrelated to this bolt.
