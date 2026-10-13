---
stage: plan
bolt: 103-super-admin-routes
created: '2026-10-13T12:05:00Z'
---

## Implementation Plan: route-permissions

### Objective

Story 005 (FR-5). Configuration, course writes, learners and feedback
become super admin only. A course admin gets 403 `super_admin_only`
and nothing is written.

### What the code says (checked before planning)

- **F1** Every admin router has `dependencies=[Depends(require_admin)]`
  at router level. No route has its own `dependencies=`.
- **F2** `admin_learner_routers.router` (learners, reports) and
  `feedback_routers.admin_router` hold only FR-5 routes.
- **F3** The other FR-5 routes share routers with routes course admins
  keep: `admin_routers.router` (courses, languages, app config),
  `voice_routers.admin_router` (settings PUT, usage),
  `sound_routers.admin_router` (chart create, delete).
- **F4** `require_super_admin` (bolt 102) depends on `require_admin`;
  FastAPI resolves both once per request.

### Decisions

- **D1 Whole routers:** `admin_learner_routers.router` and
  `feedback_routers.admin_router` swap `require_admin` for
  `require_super_admin` at router level.
- **D2 Single routes:** add `dependencies=[Depends(require_super_admin)]`
  to each route decorator:

  | File | Routes |
  |---|---|
  | `admin_routers.py` | `POST /courses`, `PATCH /courses/{course_id}`, `DELETE /courses/{course_id}`, `POST /languages`, `PATCH /languages/{code}`, `DELETE /languages/{code}`, `GET /app-config`, `PATCH /app-config` |
  | `voice_routers.py` | `PUT /settings/{language}`, `GET /usage` |
  | `sound_routers.py` | `POST /sound-charts`, `DELETE /sound-charts/{language}` |

  Route bodies don't change. Router-level `require_admin` stays, so the
  401/403 `not_admin` order is unchanged.
- **D3 One list, shared with bolt 107:** the (method, path) pairs above
  go in `tests/integration/admin_route_rules.py` as `SUPER_ONLY`, so the
  sweep test in bolt 107 reads the same list.

### Deliverables

- The router and route changes (D1, D2).
- `tests/integration/admin_route_rules.py` with `SUPER_ONLY` (D3).
- `tests/integration/test_super_admin_routes.py`:
  - parametrised over `SUPER_ONLY`: a course admin (with the seeded
    course) gets 403 `super_admin_only`;
  - parametrised over `SUPER_ONLY`: a stored (non-owner) super admin is
    not refused (status is not 403; bodies are left to each route's own
    tests);
  - a refused `POST /courses`, `PATCH /app-config` and
    `DELETE /languages/{code}` change nothing in the database.

### Acceptance Criteria

- [x] Every criterion of story 005.
- [x] `ruff` clean; `mypy` no new errors.
- [x] Full backend suite passes.

---

## Implement (2026-10-13)

- `admin_learner_routers.router` and `feedback_routers.admin_router`
  use `require_super_admin` at router level (D1).
- `dependencies=[Depends(require_super_admin)]` on the 12 single routes
  in `admin_routers.py`, `voice_routers.py` and `sound_routers.py` (D2).
  Route bodies unchanged; router-level `require_admin` kept.
- `tests/integration/admin_route_rules.py`: `SUPER_ONLY` (17 routes),
  `PLACEHOLDERS` and `concrete(path)` (D3).
- A route on the list that didn't exist would fail the course-admin
  test (404, not 403), so the list can't name a missing route.
- No deviations from the plan.

---

## Test (2026-10-13)

- `tests/integration/test_super_admin_routes.py`: 35 passed.
- Full backend suite: 1973 passed.
- `ruff` clean; `mypy app` shows only the 4 earlier errors.

| Story 005 criterion | Test |
|---|---|
| The FR-5 routes use `require_super_admin` | `SUPER_ONLY` in `admin_route_rules.py` |
| A course admin gets 403 `super_admin_only` on each | `test_a_course_admin_is_refused` (17 cases) |
| A stored super admin can call each | `test_a_stored_super_admin_is_not_refused` (17 cases) |
| Nothing is written when refused | `test_refused_writes_change_nothing` |

No issues found.
