---
stage: test
bolt: 024-courses-service
created: '2026-09-20T18:30:00Z'
---

## Test Report: courses-service

### Summary

- **Full backend suite**: 470/470 passed (393 existing + 77 new); `ruff check` and `ruff format --check` clean
- **Unit tests**: 31 new (17 domain rules, 14 use cases against fakes)
- **Integration tests**: 43 new (33 endpoint tests against a real temp-file SQLite database, 10 migration tests running Alembic on throwaway databases)
- **Security tests**: 2 new (per-user isolation, malformed switch request), inside the endpoint file
- **Performance tests**: 3 new (query counts)
- **Coverage**: 90% of `app/` overall; the new modules `course.py`, `course_use_cases.py`, `course_schemas.py` at 100%, `course_routers.py` at 89%

### Test Files

- [x] `tests/unit/test_course_domain.py` - language pair rules; the three language codes; course selection policy (activate, resolve pair, fallback); `activate_course_for_user` mirrors the learning language and refuses a coming-soon course; onboarding pair resolution (default English, Amharic speaker to Afaan Oromo, same language, no course, bad from-language); lesson-course gate
- [x] `tests/unit/test_course_use_cases.py` - course list order, active marked, completed/total skills, empty courses as 0/0; switching persists course and mirror, unknown 404, coming soon rejected with no write, current course no-op; language change through preferences uses the current from-language; signup with a pair creates no user when the pair is unavailable
- [x] `tests/integration/test_courses_endpoints.py` - course list; switch (success, persists across sessions and re-login, 404, 422, unchanged on failure, same course, auth); course-scoped tree (only active course, switching, empty course, new-to-course bootstrap, independent progress restored exactly on switching back, XP/streak/beans account-wide); lessons gated by their own course (non-active completion recorded in its own course, locked skill 403 in another course, coming-soon lesson 403 for start and complete); Practice scoped to the active course; signup with a pair, default English, unavailable pair rejected with no account, same language twice; `PATCH language` compatibility and mirror invariant; per-user isolation
- [x] `tests/integration/test_courses_migration.py` - English to Amharic created; categories, vocab and users backfilled; skills, skill progress and vocab progress byte-identical; two courses may reuse a category order index; course rules enforced by the database; orphans rejected; fresh database reaches head; downgrade keeps data and restores the schema; upgrade after downgrade; downgrade fails loudly when two courses share a category order
- [x] `tests/performance/test_course_performance.py` - course list is exactly 3 queries with 31 courses; course-scoped skill tree stays within 10 queries across 3 courses x 5 categories x 4 skills; scoped due-count is 1 query
- [x] Existing fixtures updated (`tests/fakes.py`, `conftest.py` with the English to Amharic course in every test database, plus 15 test files) with no test deleted or weakened

### Acceptance Criteria Validation

- ✅ **001-course-model-and-migration**: migration preserves all rows and downgrades cleanly (migration tests, plus a rehearsal on a copy of the real `dev.db`); duplicate pair, same language and unknown status rejected by the database; a coming-soon course with no categories stores fine
- ✅ **002-active-course-per-user**: switch persists across sessions; unknown 404, coming soon 422 with no change; existing users land on English to Amharic; signup with a pair activates it; unavailable pair rejects signup and creates no user; `selected_language` and `active_course_id` agree after signup, switch and `PATCH`
- ✅ **003-course-list-api**: all courses in stable order, coming soon included, exactly one active, 3 queries regardless of course count, unauthenticated rejected
- ✅ **004-course-scoped-skill-tree-and-progress**: only the active course returned; new-to-course bootstrap; switching away and back restores states exactly; other course unaffected by a completion; XP/streak/beans unchanged; locked lesson 403 in every course; coming-soon lesson not startable; existing response fields unchanged (all prior skill-tree tests pass); query count within bound
- ✅ **005-course-scoped-practice**: due count and items only from the active course; switching changes them; schedules untouched; single query
- ⏳ **Queued-offline sync of a non-active course**: the backend rule is proven (a course B lesson completes while A is active and counts in B); the full client queue behaviour belongs to bolt 027

### Issues Found

- No defects found in the implementation. Three existing test fixtures had relied on skills pointing at a category row that did not exist; the tree now drops such orphan skills, so those fixtures create the category (recorded in the implementation walkthrough).
- `course_routers.py` has 2 uncovered lines (a defensive branch); not worth a test.

### Recommendations

- **Restart the backend** to serve the new routes, then check the picker data by hand with `GET /api/v1/courses` once a client exists (bolt 026).
- **Fallback for an active course that later becomes `coming_soon`** exists in the policy but is not wired into a read path; add it when a course is first taken offline.
- **Follow-up cleanup**: `unit_title`/`unit_subtitle` (ADR-11) and the redundant `selected_language` column (ADR-13) can be removed once no client reads them.
- **Bolt 025** seeds the Afaan Oromo courses; bolts 026 and 027 build the client picker and offline handling on this API.
