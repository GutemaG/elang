---
stage: test
bolt: 021-categories-service
created: '2026-09-19T22:00:00Z'
---

## Test Report: categories-service

### Summary

- **Backend**: 364/364 passed (`uv run pytest`), `ruff check` clean. Up from 330 before this bolt: 34 new tests, plus fixture updates across 13 existing test files (every skill now needs a category id).
- **Coverage**: 100% line coverage on every domain, application, repository, model and schema module this bolt touched (`domain/lesson/*`, `lesson_use_cases.py`, `lesson_repositories.py`, `lesson_models.py`, `lesson_schemas.py`, `lesson_dependencies.py`). `lesson_routers.py` stays at 86% and `seed_lesson_content.py` at 92%; the uncovered lines are the pre-existing untouched return statements and the CLI `main()` entry, unchanged from before this bolt.
- **Migration**: now covered by automated tests (a first for this project, which had relied on manual checks). They run Alembic in a subprocess against throwaway SQLite files: upgrade on a populated database, fresh-database upgrade, and a downgrade round trip. Also applied for real to `dev.db` (backed up first) with data verified afterwards.
- **Flutter regression**: 164/164 non-e2e tests pass. No Flutter code changed for this bolt (the response change is additive), so this confirms the shipped client still parses the new response shape's existing fields.

### New Test Files

- `tests/unit/test_category_progression.py` (16 tests): `SkillPath` (grouping, first, next-after, last skill, unknown skill, empty path, single-skill category); the policy across categories (one active skill per category for a new user, grouping order, progress in one category not affecting another, `state_for_skill` agreement, locked skill rejected by the access policy); completion unlocking only within the same category and unlocking nothing at a category's last or only skill.
- `tests/integration/test_categories_endpoints.py` (9 tests, real DB and HTTP): categories returned in order with their fields; every skill carries `category_id` and skills are grouped by category order; deprecated `unit_title`/`unit_subtitle` come from the first category; existing per-skill fields unchanged; new user has exactly one active skill per category; completing a skill unlocks only the next skill in its own category; completing a category's last skill does not error or unlock anything; a locked skill's lesson returns 403 in a non-first category; the first skill of a non-first category is reachable.
- `tests/integration/test_categories_migration.py` (6 tests): existing skills backfilled into Foundations; existing progress rows byte-identical after upgrade; two categories can reuse the same skill order value; a skill with no category is rejected; a fresh database upgrades to head; downgrade restores skills and drops the category table and column.
- `tests/integration/test_seed_lesson_content.py` (3 new tests): every seeded skill belongs to a seeded category; re-running the seed creates no duplicate categories; the seed's Foundations id equals the migration's independently derived id (guards against drift that would create a second Foundations).
- Extended: `test_lesson_use_cases.py` (category list threaded through `get_skill_tree`, deprecated fields derived from the first category), `test_lesson_performance.py` (query bound 8 to 9 for the one new category query, still asserted constant at 50 skills).

### Acceptance Criteria Validation

- ✅ **001-category-content-model-and-migration**: existing skills land in "Foundations & Greetings"; users, progress and other data unchanged on a populated database; clean downgrade; a skill without a category is rejected by the schema.
- ✅ **002-per-category-progression**: brand-new user sees exactly one active skill per category; completing skill N unlocks N+1 in the same category only; a category's final skill unlocks nothing and does not error; a locked skill's lesson is 403 in a non-first category; an existing user's completed/active states and crown levels are unchanged after migration (progress rows byte-identical; both skills remain in the same relative order in Foundations).
- ✅ **003-skill-tree-api-with-categories**: categories listed in order, each skill mapped to exactly one category, existing fields unchanged, hardcoded constants removed, query count constant (performance test, 50 skills, one extra query).

### Issues Found

None outstanding. Two things were caught and handled during the stage: the formatter touched an unrelated file (`app/domain/services.py`), which was reverted; and the first draft of the performance assertion needed its bound raised by exactly the one intended query.

### Known Gaps and Follow-ups

- The deprecated `unit_title`/`unit_subtitle` remain in the API; removal is a follow-up once the Flutter client (bolt 023) stops reading them.
- The migration downgrade fails loudly if several categories reuse the same skill order value (documented in ADR-11); it is a data-safety choice, not a bug.
- Bolt 022: one existing seed test selects the skill with order 1 and expects a single match; it will need updating when multiple categories each have a first skill.

### Recommendations

Bolt `022-category-content-seed` can now add the four categories against a stable schema and API. Bolt `023-categories-ui` can build against the real `categories` list and per-skill `category_id`.
