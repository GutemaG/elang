---
stage: plan
bolt: 087-path-lessons-service
created: '2026-10-06T09:00:00Z'
---

## Implementation Plan: path-lessons-service

### Objective

Story 001 (FR-1): each skill of `GET /api/v1/skill-tree` carries its
lessons, in order, each with `id`, `title` and `done`.

### What the code says (checked before planning)

- **F1** `get_skill_tree` (`application/lesson_use_cases.py`) already
  reads every skill's lesson ids in one grouped query
  (`list_lesson_ids_by_skills`, ordered by `order_index`) and the user's
  `completed_lesson_ids_this_cycle` per skill, to pick `lesson_id` and
  count `lessons_done` / `lesson_count`.
- **F2** A completed skill's later plays are reviews (`_complete_review`):
  its cycle set is not added to, so `done` there is whatever the pass left
  (empty after the pass that completed it). The app shows a completed
  skill's lessons as done whatever `done` says.

### Decisions

- **D1** A new grouped read, `list_lessons_by_skills(skill_ids)`, returns
  `(id, title)` per lesson in order, in one query; `get_skill_tree` uses
  it in place of the ids-only read and derives the ids from it, so the
  query count is unchanged.
- **D2** `SkillTreeSummary.lessons_by_skill: dict[str, list[PathLesson]]`
  with `PathLesson(id, title, done)`; `done` is membership in the current
  pass's set, the same fact `lessons_done` counts.
- **D3** `SkillTreeEntryResponse.lessons: list[PathLessonResponse]`,
  defaulting to `[]`: purely additive.

### Deliverables

- Repository protocol, SQL repository and the fake: `list_lessons_by_skills`
- `get_skill_tree`, the summary, schema and router
- Tests: the use case (order, done, a skill with none), the endpoint
  (field present, done after a lesson), the repository (one query,
  ordering)

### Acceptance Criteria

- [x] `lessons` on every skill, ordered, with `done`
- [x] Existing fields unchanged; existing tests pass
- [x] Same number of queries
- [x] ruff, mypy (no new errors) and pytest pass

## Implement (2026-10-06T09:02:00Z)

- `LessonRepository.list_lessons_by_skills` (protocol, SQL repository,
  `FakeLessonRepositoryWithSkillIndex`): `(id, title)` per lesson, in
  `order_index` order, one query.
- `get_skill_tree` reads it in place of `list_lesson_ids_by_skills` and
  derives the ids from it, so the query count is unchanged;
  `SkillTreeSummary.lessons_by_skill` holds `PathLesson(id, title, done)`.
- `SkillTreeEntryResponse.lessons: list[PathLessonResponse]`, default `[]`.
- API note: each skill of `GET /api/v1/skill-tree` now has
  `"lessons": [{"id": "...", "title": "Hello", "done": true}, ...]`;
  `done` is the lesson being in the skill's current pass, the same set
  `lessons_done` counts. A completed skill's later plays are reviews and
  leave it as it was, so a client shows a completed skill's lessons as
  done whatever `done` says.

## Test (2026-10-06T09:08:31Z)

- `test_lesson_engagement_repositories.py`: lessons grouped with titles,
  in order; no skill ids gives `{}`.
- `test_lesson_use_cases.py`: one of two lessons done gives `done` true,
  then false, in order.
- `test_lesson_endpoints.py`: a new learner's skill lists its lesson, not
  done.
- `test_skill_tree_next_lesson_id.py`: after completing the first lesson
  it is done and the second is not; the skill stays active.

Results: ruff and format clean; mypy 4 errors, all from before (none in
the changed code); `pytest` 1713 passed.
