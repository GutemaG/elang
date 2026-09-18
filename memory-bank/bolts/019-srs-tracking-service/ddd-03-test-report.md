---
stage: test
bolt: 019-srs-tracking-service
created: '2026-09-17T23:00:00Z'
---

## Test Report: srs-tracking-service

### Summary

- **Backend unit tests**: 316/316 passed, 100% line coverage on every touched module (`app/application/lesson_use_cases.py`, `app/domain/lesson/*`, `app/infrastructure/db/lesson_repositories.py`)
- **Backend integration tests**: included in the 316 (real temp-file SQLite via `TestClient`/`db_session`) — new `test_practice_endpoints.py`, new vocab-repository classes in `test_lesson_engagement_repositories.py`
- **Migration**: `alembic upgrade head` / `downgrade -1` / `upgrade head` verified manually against a real copy of `dev.db` — round-trips cleanly, preserves all existing rows (17 exercises before and after), matching this project's existing convention that migrations aren't exercised by the automated pytest suite (`tests/conftest.py` builds schema via `Base.metadata.create_all`, bypassing Alembic entirely, same as every prior bolt)
- **Seed script**: verified end-to-end against a real migrated DB copy — 8 vocab items seeded, 8 exercises linked (`vocab_item_id` set), idempotent re-run behavior inherited from the existing seed-script pattern (not re-tested independently, no logic changed there)
- **Flutter**: `flutter analyze` clean (only the same pre-existing info-level lints from before this bolt); `flutter test` 159/159 non-e2e tests passing (up from 158 — 1 new `sync_engine_test.dart` case plus 1 new assertion in an existing `lesson_screen_test.dart` case), the same 7 pre-existing e2e failures (require a live backend at `localhost:8000`, unrelated to this bolt)

### Acceptance Criteria Validation

- ✅ **001-vocab-item-content-model**: `vocab_items` table + `exercises.vocab_item_id` FK exist; migration verified; seed script links 8 real vocab items to their teaching exercises
- ✅ **002-vocab-progress-retrofit**: `complete_lesson` creates a box-1 row on first appearance, updates an existing row via `LeitnerBoxPolicy` on a repeat appearance (box-up when not in `missed_exercise_ids`, box-reset when it is), does nothing for a lesson with no vocab-linked exercises, and does not double-update on a retried `attempt_id` (`TestCompleteLessonVocabProgress`, backend unit + integration)
- ✅ **003-leitner-box-algorithm**: `LeitnerBoxPolicy` verified in isolation — correct moves up one box (capped at 5) using the destination box's own interval; incorrect resets to box 1 using the dedicated `INCORRECT_RESET_INTERVAL`, proven distinct from box 1's own interval value (`test_leitner_box_policy.py`)
- ✅ **004-due-items-and-count-endpoints**: `GET /api/v1/practice/due-count` and `GET /api/v1/practice/due-items` both backed by the same `UserVocabProgressRepository` predicate (`list_due`/`count_due`), verified to agree with each other and with real due/not-yet-due data at both the unit (fake-repo) and integration (real-DB, real-HTTP) level

### ADR-10 Verification (contract widening)

- `CompleteLessonRequest.missed_exercise_ids` defaults to `[]`, verified via `test_first_completion_creates_a_box_1_row` (an older client sending no field still completes successfully)
- Flutter's `LessonController` now exposes the same retry-queue membership it already tracked internally (no new grading logic) — verified end-to-end through `LessonScreen`'s widget tests: a missed-then-corrected exercise reports its id in `missedExerciseIds` even though the lesson finished with every exercise eventually correct
- The offline-sync path (`PendingSyncEntry`/`SqflitePendingSyncQueueStore`/`SyncEngine`) threads `missedExerciseIds` through unchanged on replay, verified via a new `sync_engine_test.dart` case — an offline-completed lesson's vocab accuracy is not degraded relative to an online one
- `SqflitePendingSyncQueueStore`'s on-disk schema bumped to version 2 with an `onUpgrade` migration (new column, default `''` = no misses) — not covered by an automated test, since no existing test harness exercises the real sqflite-backed store directly (consistent with this being a pre-existing gap in this project's test infrastructure, not one introduced here)

### Issues Found

None. No real bugs surfaced this bolt (unlike bolt 017's `autoflush` gap) — the composite-primary-key `upsert` pattern and shared due-predicate were both modeled closely enough on existing precedent (`UserSkillProgress`, `AmoleTransaction`) that the real-DB integration tests passed on the first try.

### Recommendations

- Bolt `020-practice-ui` can now build against real `due-count`/`due-items` response shapes and a real, working `complete_lesson` vocab side effect.
- If a future bolt ever needs full per-exercise (not just "was ever missed") completion detail, `missed_exercise_ids` would need a second widening — flagged here so that decision starts from an accurate picture of what already exists, not a guess.
