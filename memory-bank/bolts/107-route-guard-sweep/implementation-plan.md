---
stage: plan
bolt: 107-route-guard-sweep
created: '2026-10-13T15:00:00Z'
---

## Implementation Plan: route-permissions

### Objective

Story 010 (FR-9). A new admin route can't skip the role decision.

### Decisions

- **D1** `admin_route_rules.py` is the one table: `SUPER_ONLY`,
  `COURSE`, `CHILD`, `BODY_LESSON`, `LANGUAGE`, `OPEN`.
- **D2** `tests/integration/test_admin_route_guard.py` reads the
  production app (`create_app()`), so every included router counts.
  Each `/api/v1/admin` route must have exactly one rule, no rule may
  name a missing route, and the route's dependency tree must hold the
  rule's check (`require_super_admin`, `require_course`, the kind's
  `require_*_course`, `require_language`); open and body routes must not
  be super admin only.
- **D3** The cross-course attempts are the parametrised 404 tests of
  bolts 104–106; this bolt doesn't repeat them.

### Acceptance Criteria

- [x] Every criterion of story 010.
- [x] Full suite passes.

---

## Implement (2026-10-13)

- D1–D3 as planned.
- FastAPI 0.141 keeps included routers whole (`_IncludedRouter`), so the
  sweep reads their routes through `effective_candidates()`, which
  carries the routers' dependencies too.

---

## Test (2026-10-13)

- `tests/integration/test_admin_route_guard.py`: 123 passed.
- Full backend suite: 2239 passed.

| Criterion | Test |
|---|---|
| Every admin route has exactly one rule | `test_every_admin_route_has_exactly_one_rule` |
| Every route requires an admin | `test_every_admin_route_requires_an_admin` |
| Each rule's check is on its routes | `test_super_admin_routes_carry_the_super_admin_check`, `test_course_routes_carry_the_course_check`, `test_child_routes_carry_their_kinds_check`, `test_language_routes_carry_the_language_check` |
| Open routes aren't super admin only | `test_open_routes_are_not_super_admin_only` |
| Cross-course attempts 404 and change nothing | bolts 104–106 tests |
