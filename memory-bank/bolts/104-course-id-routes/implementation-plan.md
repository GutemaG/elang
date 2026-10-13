---
stage: plan
bolt: 104-course-id-routes
created: '2026-10-13T13:30:00Z'
---

## Implementation Plan: route-permissions

### Objective

Stories 006 and 007 (FR-6, FR-7). A course admin's course list holds
only their courses, and every route with `{course_id}` in its path
refuses another course with the same 404 as an unknown id.

### What the code says (checked before planning)

- **F1** `GET /admin/courses` → `repo.list_courses()` (all courses with
  learner counts), mapped by `_course(...)`.
- **F2** Routes with `{course_id}` in `admin_routers.py`:
  `GET /courses/{course_id}/tree`, `POST /courses/{course_id}/sections`,
  `PUT /courses/{course_id}/sections/order`,
  `GET /courses/{course_id}/vocab`. (`PATCH`/`DELETE /courses/{id}` are
  super admin only since bolt 103.)
- **F3** `curriculum_routers.router` has prefix
  `/api/v1/admin/courses/{course_id}/curriculum`: all 7 Workbook routes,
  publish included, take `course_id`.
- **F4** An unknown course is `ContentNotFoundError("No such course",
  entity="course", id=...)` → 404 `content_not_found` with
  `details: {entity, id}`.
- **F5** FastAPI fills a dependency's `course_id` parameter from the
  path, and a router-level dependency can use a prefix placeholder.

### Decisions

- **D1 `require_course`** in `dependencies.py`:
  `async def require_course(course_id: str, access = Depends(require_admin))`.
  If `not access.can_open_course(course_id)`, raise the same
  `ContentNotFoundError("No such course", entity="course", id=course_id)`
  as F4. A super admin passes without a database read; an unknown id
  still gets its 404 from the route as today.
- **D2 Where it goes:**
  - `curriculum_routers.router`: router-level, next to `require_admin`.
  - The four F2 routes: `dependencies=[Depends(require_course)]`.
- **D3 Filtered list:** `list_courses` takes the access; a course admin
  gets `[c for c in courses if access.can_open_course(c.id)]`. Courses
  are few (4), so filtering after the one query is enough; order is
  unchanged.
- **D4 `AdminContext.access` = None** stays "no request behind it"; this
  bolt needs no use-case change, because the checks sit on the routes.
- **D5 Rules table:** `admin_route_rules.py` gains `COURSE` — the 11
  (method, path) pairs of D2 — for bolt 107.

### Deliverables

- `require_course`; the router-level and per-route dependencies.
- Filtered `GET /admin/courses`.
- `COURSE` in `admin_route_rules.py`.
- `tests/integration/test_course_id_routes.py` (seeded course plus a
  second course added in the test):
  - course list: course admin sees only theirs; none → `[]`; owner and
    stored super admin see both;
  - parametrised over `COURSE`: another course's id → 404 with the
    unknown-course body; nothing written (snapshot of `sections`,
    `curriculum_*` tables);
  - parametrised over `COURSE`: their own course's id → not 404/403
    from the guard (status is not 403 and the body is not the
    `entity: course` 404);
  - a course admin publishes a lesson in their course's Workbook
    (reuse the existing publish test's setup).

### Acceptance Criteria

- [x] Every criterion of stories 006 and 007.
- [x] `ruff` clean; `mypy` no new errors.
- [x] Full backend suite passes.

---

## Implement (2026-10-13)

- `dependencies.require_course(course_id, access)`: the unknown-course
  404 (`content_not_found`, `details: {entity: course, id}`) for a
  course admin without the course (D1).
- Router-level on `curriculum_routers.router`; per route on the tree,
  `POST …/sections`, `PUT …/sections/order` and `GET …/vocab` (D2).
- `GET /admin/courses` filters with `access.can_open_course` (D3).
- `COURSE` (11 routes) in `admin_route_rules.py` (D5).
- The owner decided to go ahead without checkpoints from here on
  (2026-10-13); bolts 104–114 are recorded without stops.

### Deviations from Plan

- The test's second course is English to Tigrinya: the seed already
  creates all four real courses, so a made-up pair avoids the unique
  language-pair constraint.

---

## Test (2026-10-13)

- `tests/integration/test_course_id_routes.py`: 27 passed.
- Full backend suite: 2239 passed.

| Criterion | Test |
|---|---|
| Course list filtered; none → `[]`; super admins see all | `TestCourseList` |
| Another course → unknown-course 404, nothing written | `test_another_course_is_not_found_and_unchanged` (11) |
| Own course gets through | `test_their_own_course_gets_through` (11) |
| A course admin publishes in their course | `test_a_course_admin_publishes_a_lesson_in_their_course` |
