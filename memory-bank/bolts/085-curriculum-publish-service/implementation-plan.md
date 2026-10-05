---
stage: plan
bolt: 085-curriculum-publish-service
created: '2026-10-05T12:46:00Z'
---

## Implementation Plan: curriculum-service

### Objective

Stories 005-006 (FR-7, FR-8 storage, FR-9): keep a lesson's draft
exercises, and publish one finished lesson into the live course beside its
existing content.

### What the code says (checked before planning)

- **F1 Building the tree.** `admin_content_use_cases.create_node(repo,
  ctx, level, parent_id, title=…, subtitle=…)` places a section
  (`categories`), skill or lesson last in its parent;
  `SqlAlchemyAdminContentRepository` has `get`, `add`, `children`,
  `next_order_index`, `delete_row` and `touch_lesson` (moves the lesson's
  content version so phones refetch).
- **F2 Exercises.** `validate_exercise(type, prompt, content, answer_key,
  allow_local_media=…)` is what every admin write uses; nothing references
  an exercise, so deleting one is safe; `vocab_item_id` on an exercise is
  what Practice uses to bring a word back.
- **F3 Vocabulary** items are a course's `word` and `translation`; none are
  made by the admin API yet (seeds only).
- **F4 Progress** is kept per skill and lesson by id, so a lesson that keeps
  its id keeps learners' progress.

### Decisions

- **D1 Where the curriculum meets the course.** New nullable columns, one
  migration `e2c7a9d4b6f3` (batch mode for SQLite):
  - `curriculum_entries.published_id`: the category, skill or lesson made
    from this entry; `published_exercise_ids` (JSON) and `published_at` on
    a lesson entry.
  - `curriculum_rows.vocab_item_id`: the word's vocabulary item.
  - New table `curriculum_exercises`: a lesson's draft exercises in order
    (`type`, `prompt`, `content`, `answer_key`, `vocab_ref` — the row it
    practises, `generated` — the body it was generated as, `edited`),
    `updated_at`.
- **D2 Draft exercises: `GET` and `PUT .../lessons/{ref}/exercises`.**
  The PUT replaces the lesson's list (1-50). Refused (`409
  lesson_not_ready`) unless every row is reviewed and recorded; each body
  validated like the exercise endpoints, every failure listed (`422
  invalid_import`, by index); a `vocab_ref` must be a word of this lesson.
- **D3 Publish: `POST .../lessons/{ref}/publish`.** In one transaction:
  - Refused (`409 lesson_not_ready`, `details.reason`: `rows` or
    `exercises`) unless the rows are ready and there are draft exercises.
  - The section's category, the skill and the lesson are found by
    `published_id` (if they still exist in this course) or made last in
    their parent with `create_node`; titles are the curriculum's on first
    publish and are not changed afterwards (an admin may rename them).
  - Each word row gets a vocabulary item (made, or its word and translation
    updated).
  - The exercises this lesson published before are deleted, and the draft
    ones are added after any hand-made ones, linked to their word's
    vocabulary item; the lesson is touched.
  - `published_at` and the ids are saved; the answer names the category,
    skill and lesson ids.
- **D4 Publish state in the read.** Each lesson entry gets
  `publish_state`: `not_published`, `published`, or `changed` (a row or
  draft exercise changed after `published_at`), `published_id` and
  `published_at`; and `exercise_count` (its draft exercises).
- **D5 Errors.** `LessonNotReadyError` (`409 lesson_not_ready`).

### Deliverables

- Migration, models, repository, use cases, schemas, routes
- Tests: save drafts (ready check, validation, vocab_ref), publish (first
  time makes the tree, beside hand-made content, vocab and links,
  republish keeps the lesson id and replaces only its own exercises,
  missing tree items remade, touches the lesson, state in the read,
  "changed" after an edit), migration

### Dependencies

- Bolt 082's tables and endpoints

### Acceptance Criteria

- [ ] Draft exercises are saved only for a ready lesson, validated
- [ ] Publish refuses with the reason; otherwise makes or reuses the tree
- [ ] Hand-made categories, skills, lessons and exercises are untouched
- [ ] Republish keeps the lesson id; its old exercises are replaced
- [ ] Words become vocabulary items linked from their exercises
- [ ] The lesson's content version moves; all in one transaction
- [ ] The read shows Not published / Published / Changed
- [ ] ruff and the full backend suite pass

## Implement (2026-10-05T12:52:00Z)

- Migration `e2c7a9d4b6f3` (down to `d8b3f6a2c4e1`): `published_id`,
  `published_exercise_ids`, `published_at` on `curriculum_entries`;
  `vocab_item_id` on `curriculum_rows`; table `curriculum_exercises`.
- `curriculum_models.py`: the columns and `CurriculumExerciseModel`;
  `curriculum_repository.py`: a lesson's (or every) draft exercises,
  clearing them.
- `curriculum_use_cases.py`: publish state (Not published / Published /
  Changed, comparing times in UTC whatever the database gives back);
  draft exercises listed and saved (ready check, 1-50, each validated with
  `validate_exercise`, `vocab_ref` a word of the lesson, every problem
  by index); `publish_lesson` (finds or makes the category, skill and
  lesson with `create_node`, a vocabulary item per word, deletes only
  the exercises it published before, adds the drafts after hand-made
  ones linked to their words, touches the lesson).
- `LessonNotReadyError` (`409 lesson_not_ready`, reason `rows` with
  counts, or `exercises`).
- Schemas and routes: the entry's publish fields in the read; `GET` /
  `PUT .../lessons/{ref}/exercises`; `POST .../lessons/{ref}/publish`.
- Deviation: titles are copied on first publish only, so an admin's
  rename in the tree is kept.

## Test (2026-10-05T13:02:59Z)

- `tests/integration/test_curriculum_publish.py` (9), against the seeded
  course: drafts kept in order once ready; refused until ready (counts);
  validated like any exercise (by index, `vocab_ref`); 404s; publish
  refused without rows ready or exercises; the first publish makes the
  section, skill and lesson after the seeded ones, which are unchanged,
  with the exercises and a vocabulary item linked; a second lesson joins
  the same skill; publishing again keeps the lesson id, keeps a hand-made
  exercise, replaces its own, moves the lesson's version, updates the same
  vocabulary item, and the state goes Changed then Published; a section
  deleted by hand is made again.
- `tests/integration/test_curriculum_publish_migration.py` (2): single
  head (moved from `test_curriculum_migration.py`), upgrade and
  downgrade keep the curriculum's rows.

Results: `ruff check .` clean; mypy: no errors in the curriculum code
(the 4 elsewhere are from before); `pytest` 1711 passed.
