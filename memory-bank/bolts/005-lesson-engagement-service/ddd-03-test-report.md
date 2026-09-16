---
unit: 001-lesson-service
bolt: 005-lesson-engagement-service
stage: test
status: complete
updated: 2026-09-16T14:00:00Z
---

# Test Report - Lesson Engagement Service

## Test Summary

Full backend suite: **215 passed, 0 failed** (`uv run pytest -q` from `backend/`). Of these, 145 are `001-auth-service`/`004-lesson-content-service`'s pre-existing suite (2 amended — see "Cross-Bolt Amendments" below), and 70 are new for this bolt.

| Category | New for this bolt |
|----------|--------------------|
| Unit (`BeanLedger`, `StreakPolicy`, `LessonCompletionService`, application use cases) | 47 |
| Integration (repositories, endpoints) | 25 |
| Performance (skill-tree query count, amended) | 0 new, 1 amended |

`ruff check .` and `ruff format --check .`: clean across the whole backend.

## Acceptance Criteria Validation

| Story | Criteria | Status |
|-------|----------|--------|
| 002-answer-exercises-and-manage-beans | Wrong answers consume beans, 0 beans interrupts, regen over time | ✅ `test_bean_ledger.py` (regen/consume/refill), `test_lesson_engagement_endpoints.py::TestCompleteLesson` (beans_exhausted) |
| 002 | Correct answer never consumes a bean | ✅ `TestBeanLedger.TestConsume.test_zero_wrong_count_never_changes_the_balance` |
| 003-complete-lesson-award-xp-and-progress | XP awarded exactly once, idempotent on `attempt_id` | ✅ `test_lesson_engagement_use_cases.py::test_is_idempotent_on_attempt_id`, `test_lesson_engagement_endpoints.py::test_repeating_the_same_attempt_id_is_idempotent` |
| 003 | Completing every lesson in a skill unlocks the next skill | ✅ `test_lesson_completion_service.py::TestCycleTrackingAndSkillUnlock` (6 tests, including "not the final lesson" and "no next skill" edge cases) |
| 003 | Replaying an already-completed skill raises crown level, capped at 5 | ✅ Same class, `test_replaying_every_lesson_again_raises_the_crown_level`, `test_crown_level_is_capped_at_five` |
| 003 | An interrupted (beans-exhausted) attempt cannot be completed | ✅ `test_lesson_engagement_use_cases.py::test_raises_beans_exhausted_when_wrong_count_exceeds_beans_balance` |
| 004-daily-streak-and-freeze | Streak increments once/day, resets on a missed day unless frozen | ✅ `test_streak_policy.py` (7 tests covering every branch) |
| 004 | Streak-freeze granted at crown level 5, consumed on exactly one missed day | ✅ `test_lesson_completion_service.py::test_reaching_crown_level_five_grants_exactly_one_streak_freeze`, `test_streak_policy.py::test_one_missed_day_with_a_freeze_available_continues_the_streak` |

## Cross-Bolt Amendments (Verified Together)

- **`004-lesson-content-service`**: lesson-content response now includes `correct_choice_id`/`correct_sequence` (ADR-5). Its own tests were updated in place (`test_lesson_endpoints.py::test_includes_correct_answer_data_per_adr5`, `test_lesson_security.py::TestAnswerKeyFieldsShapedPerADR5`) rather than left failing or silently deleted — both now assert the new, correct behavior. Full bolt 004 suite re-run and passing.
- **`006-core-lesson-loop-ui`** (Flutter): `LessonController` now generates a per-attempt `attemptId`; `LessonApi.completeLesson` gained that required parameter. `FakeLessonApi` and `ControllableLessonApi` updated; a new idempotency test added (`fake_lesson_api_test.dart::'repeating the same attemptId does not double-award XP or streak'`). Full Flutter suite (66/66) and `flutter analyze` re-run clean after the change — no behavior change to the already-verified requeue/beans/modal flows.
- **Missed-exercise-loops-back feature** (requested mid-session, applied to `006` before this bolt started): unaffected by this bolt's backend work — confirmed still passing in the same full-suite run.

## Issues Found

| Issue | Severity | Status |
|-------|----------|--------|
| ADR-4 (bolt 004) planned a per-exercise `SubmitExerciseAnswer` endpoint that would have violated the "no network call per exercise" NFR | High (would have blocked this bolt) | Resolved — ADR-5 supersedes it; see Technical Design |
| `requirements.md`'s server-side-grading assumption (via ADR-4) was inconsistent with `006`'s already-built client-side grading | Medium | Resolved by the same ADR-5 decision, which the already-shipped UI turned out to already assume correctly |
| No real per-exercise server-side re-validation at completion (client-reported `correct_count`/`total_count` is trusted, bounded only by beans availability) | Low | Accepted trade-off, documented in ADR-5 — flagged as revisitable if a competitive/monetized feature is ever added |

## Ready for Operations

- [x] All acceptance criteria met
- [x] Code coverage: 100% on all bolt-005 modules (`domain/lesson/services.py` additions, `application/lesson_use_cases.py` additions, `infrastructure/db/lesson_repositories.py` additions); 86% on the whole `app/` package, shortfall fully accounted for by out-of-scope external-verifier/bootstrap/CLI code (same as bolt 004's treatment)
- [x] No critical/high severity issues open (both flagged issues above are resolved or accepted-by-design)
- [x] Idempotency verified at both the use-case and HTTP levels
- [x] Cross-bolt amendments (004, 006) re-verified with their full suites, not just spot-checked
