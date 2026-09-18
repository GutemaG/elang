---
stage: test
bolt: 020-practice-ui
created: '2026-09-18T00:30:00Z'
---

## Test Report: practice-ui

### Summary

- **Backend tests**: 330/330 passed (`uv run pytest -q`), `ruff check` clean
- **Backend coverage**: 100% on every domain/application module touched by this bolt (`lesson_use_cases.py`, `domain/lesson/*`, `lesson_repositories.py`, `exercise_mapping.py`); the API-router layer sits at 86-87%, unchanged from this project's pre-existing baseline for that layer (untouched return-statement lines, not new gaps)
- **Frontend tests**: 163/163 passed (`flutter test --exclude-tags=e2e`), `flutter analyze` clean (only 10 pre-existing, unrelated `prefer_initializing_formals`/`use_null_aware_elements` infos elsewhere in the codebase)
- **Regression pass**: the full pre-existing suite (backend + Flutter) was re-run after every change in this bolt; zero regressions to the regular (non-practice) lesson-taking flow, which the Plan flagged as the main risk of the "extend `LessonController`/`LessonScreen`" approach

### Test Files

**Backend** (new/extended this stage):

- [x] `backend/tests/unit/test_practice_session_use_cases.py` - `complete_practice_session`: awards XP/Amole, updates vocab progress, idempotent on `session_id`, rejects an empty results list
- [x] `backend/tests/integration/test_practice_endpoints.py` - `POST /api/v1/practice/complete` end-to-end (success, idempotency, empty-results 422, auth-required, streak/skill-progress untouched); `GET /api/v1/practice/due-items` returning full exercise content; **new**: a due item on a still-locked skill's lesson still appears (proven by first confirming that lesson genuinely 403s via `GET /lessons/{lesson_id}`, then confirming the due-items endpoint returns it anyway)
- [x] `backend/tests/integration/test_lesson_engagement_repositories.py` - `SqlAlchemyPracticeAttemptRepository` get/add; `list_exercises_by_vocab_item_ids` resolving full exercises
- [x] `backend/tests/unit/test_due_items_use_cases.py` - `get_due_items`/`get_due_count` against fakes, including a due row whose exercise can no longer be resolved being silently omitted

**Frontend** (new/extended this stage):

- [x] `test/features/lesson/screens/lesson_screen_test.dart` - practice-mode group: the beans indicator is absent entirely; a wrong answer neither decrements beans nor triggers the out-of-beans interruption; finishing a session (including one with a missed-then-retried exercise) calls `completePracticeSession` with per-vocab-item correctness and never calls `completeLesson`
- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` - practice-entry-card group: due count displayed and the card disabled when nothing is due; disabled (not hidden) when offline even with due items present; tapping it with due items renders the due exercise through the same exercise-engine widgets, completes it, and the dashboard's due count reflects the change after returning

### Acceptance Criteria Validation

- ✅ **Due-count visible and matches the backend's due-count endpoint**: dashboard fetches and displays it; backend test confirms due-count and due-items agree
- ✅ **Zero due items shown clearly (not hidden)**: "You're all caught up -- nothing due today" message, card still rendered
- ✅ **Entry point visibly disabled (not hidden) when offline**: card stays visible with an explicit offline message; tapping it is a no-op
- ✅ **A session includes only exercises linked to currently-due vocab items, up to the backend's limit**: `get_due_items` filters on `next_review_at <= now`, `limit`-bounded (bolt 019, reused unchanged)
- ✅ **Every practice exercise renders via the exact same widget a regular lesson uses -- no new rendering code**: `LessonScreen.practice` reuses `LessonScreen`'s private exercise-rendering widgets directly
- ✅ **A due item whose lesson is locked for the user still appears and is answerable in Practice**: new integration test proves the lesson 403s directly but still appears via due-items
- ✅ **Session completion awards XP/Amole and updates vocab progress; does not touch streak or skill-progress**: verified server-side (streak/crown-level/skill-state unchanged after completion) and client-side (`LessonCompletionResult`'s streak/crown fields stay at their "not applicable" defaults)
- ✅ **Due-count after a session reflects the just-reviewed items no longer being due**: proven end-to-end in the dashboard test (due count 1 -> session completed -> due count 0 after returning)
- ✅ **Zero regression to the regular (non-practice) lesson-taking flow**: full existing suite re-run clean throughout

### Issues Found

None outstanding. One gap was caught and closed during this stage: the initial implementation had no test proving Practice's due-items endpoint actually bypasses the lesson-access lock (the single most significant Plan-stage structural finding) -- added `test_a_due_item_on_a_locked_skills_lesson_still_appears`, which first confirms the lesson genuinely 403s before confirming due-items surfaces it anyway, so the test can't pass by accident if a lock check is ever added back.

### Notes

The Amole-award check in `test_success_awards_xp_amole_and_updates_vocab_progress` only asserts `amole_earned > 0` rather than the exact `AMOLE_PRACTICE_SESSION_AWARD` constant -- consistent with how this codebase's other reward-amount tests are written (award *amounts* are treated as tuning constants, not part of the contract under test).
