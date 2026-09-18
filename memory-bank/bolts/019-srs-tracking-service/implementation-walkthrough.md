# Implementation Walkthrough: 019-srs-tracking-service

## Corrected During Stage 4

Reading the real repository layer (forbidden at Stages 1-2) showed the Stage-1 domain model's assumption of an "amendment to `ExerciseRepository`" was wrong — no such Protocol exists in this codebase. `Exercise` is only ever accessed as a member of the `Lesson` aggregate through `LessonRepository`. The needed capability (resolve a vocab item to one exercise that tests it) was added as `LessonRepository.list_exercises_by_vocab_item_ids` instead, documented inline in `repositories.py` explaining the correction, per this project's established "corrected during Stage 4" transparency convention (bolt 013/017 precedent).

Everything else (entities, value objects, `LeitnerBoxPolicy`, `VocabItemRepository`/`UserVocabProgressRepository`) matched the Stage 1-2 design once real source was read — no further corrections were needed.

## New Backend Surface

- **Domain**: `VocabItem`, `UserVocabProgress` entities; `Exercise.vocab_item_id` (nullable); `LeitnerBoxIntervals`/`IncorrectResetInterval`/`MIN_BOX_LEVEL`/`MAX_BOX_LEVEL` constants; `LeitnerBoxPolicy` (pure); `VocabItemRepository`/`UserVocabProgressRepository` Protocols; `LessonRepository.list_exercises_by_vocab_item_ids`.
- **Application**: `complete_lesson` gains `vocab_progress_repo`/`missed_exercise_ids` params and a per-vocab-linked-exercise side effect inside the existing `attempt_id` idempotency boundary; new `get_due_items`/`get_due_count` use cases sharing `UserVocabProgressRepository`'s due predicate.
- **Infrastructure**: `VocabItemModel`, `UserVocabProgressModel` (composite PK), `ExerciseModel.vocab_item_id`; `SqlAlchemyVocabItemRepository`, `SqlAlchemyUserVocabProgressRepository`; migration `3348a939c2b4` (purely additive, no `batch_alter_table` needed for the two new tables, but required for the FK-bearing column add to `exercises` on SQLite).
- **API**: `CompleteLessonRequest.missed_exercise_ids` (ADR-10); new `practice_routers.py` (`GET /api/v1/practice/due-count`, `GET /api/v1/practice/due-items`), registered in `main.py` and the test `conftest.py`.
- **Seed data**: 8 real vocab items, linked to the 8 "how do you say X" multiple-choice exercises already in the curriculum.

## Cross-Unit Touch (ADR-10)

Per the user's explicit Stage-3 decision, this bolt also touches the already-shipped `002-core-lesson-loop-ui` unit to satisfy story 002's AC2:

- `LessonController` now tracks and exposes `missedExerciseIds` (derived from its existing retry-queue membership — no new grading logic).
- `LessonApi`/`HttpLessonApi`/`FakeLessonApi`/`ControllableLessonApi` (test double) all gained the new parameter.
- `PendingSyncEntry`/`SqflitePendingSyncQueueStore` (schema version bumped to 2, with an `onUpgrade` migration)/`SyncEngine` thread the field through the offline-replay path unchanged, so an offline-completed lesson's vocab accuracy matches an online one's.
