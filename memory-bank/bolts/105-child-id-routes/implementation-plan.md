---
stage: plan
bolt: 105-child-id-routes
created: '2026-10-13T14:10:00Z'
---

## Implementation Plan: route-permissions

### Objective

Story 008 (FR-7). Routes named by a section, skill, lesson, exercise or
vocab item, and the uploads and generation that name a lesson in their
body, check the course behind it.

### Decisions

- **D1** `SqlAlchemyAdminContentRepository.course_of(kind, id)`: one
  query, joining up to `categories.course_id`; `None` for an unknown id.
- **D2** `dependencies.check_course_of(access, repo, kind, id)`: for a
  course admin, an item outside their courses is that kind's unknown-id
  404 (`No such {kind}`, `entity`, `id`), the same as `_require`
  raises. A super admin, or no id, passes without a query.
- **D3** One small dependency per path parameter —
  `require_section_course`, `require_skill_course`,
  `require_lesson_course`, `require_exercise_course`,
  `require_vocab_course` — added to the 17 routes in `admin_routers.py`.
- **D4** Body ids: `create_audio_upload`, `create_image_upload` and
  `admin_generate_voice` call `check_course_of` with `body.lesson_id`.
- **D5** `CHILD` and `BODY_LESSON` in `admin_route_rules.py`.

### Acceptance Criteria

- [x] Every criterion of story 008.
- [x] `ruff` clean; `mypy` no new errors; full suite passes.

---

## Implement (2026-10-13)

- D1–D5 as planned. 17 routes guarded (the 16 listed in story 008 plus
  `POST /lessons/{lesson_id}/exercises/import`).
- `tests/conftest.py`: `make_client` now overrides
  `get_addis_voice_client` with `None`, so no test reaches Addis AI even
  when `ADDIS_API_KEY` is in `backend/.env`. Found while testing: a
  generate call that passed the new guard reached the real service
  (two short takes, about 0.2 ETB in all). Tests that need the voice
  service already set their own fake.

### Deviations from Plan

- The conftest safety override above was not planned.

---

## Test (2026-10-13)

- `tests/integration/test_child_id_routes.py`: 58 passed.
- Full backend suite: 2239 passed.

| Criterion | Test |
|---|---|
| `course_of` for each kind; unknown → None | `test_course_of_finds_each_kind` |
| Another course's item → that kind's 404; unchanged | `test_another_courses_item_is_not_found_and_unchanged` (17) |
| Own item gets through | `test_an_item_in_their_course_gets_through` (17) |
| Unknown id is the same 404 | `test_an_unknown_id_is_the_same_404` (17) |
| Uploads and generate with `lesson_id` | `test_a_lesson_named_in_the_body_is_checked`, `test_a_lesson_in_their_course_named_in_the_body_gets_through` |
