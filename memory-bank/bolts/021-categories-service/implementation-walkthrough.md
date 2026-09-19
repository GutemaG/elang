---
stage: implement
bolt: 021-categories-service
created: '2026-09-19T21:40:00Z'
---

## Implementation Walkthrough: categories-service

### Summary of changes

Added a category level above skills end to end on the backend, made progression linear within a category with every category open, and exposed categories through `GET /skill-tree` additively (ADR-11). The shipped Flutter client needs no change to keep working.

### Structure

- **Domain**: a new `Category` aggregate; `Skill` gains a required `category_id`; a new pure `SkillPath` value object is the single definition of "first skill" and "next skill after X" within one category. `SkillTreeProgressionPolicy` and `LessonCompletionService` both use it, so the tree read, the lesson-access check (via `state_for_skill`) and the completion unlock cannot disagree. A `CategoryRepository` contract was added.
- **Application**: `get_skill_tree` now reads the category list, orders skills by category then position, and returns the categories. The two hardcoded unit constants are gone; `unit_title`/`unit_subtitle` are derived from the first category (empty if none exist).
- **Infrastructure**: `CategoryModel` and the amended `SkillModel` (required category FK, per-category order uniqueness); a `SqlAlchemyCategoryRepository`; the skill repository returns skills with their category. One Alembic revision (`a7d1c5e29b04`).
- **API**: `SkillTreeResponse` gains `categories`; each skill entry gains `category_id`; all existing fields are unchanged; the two unit fields stay, marked deprecated.
- **Seed**: minimal change only - a Foundations & Greetings category is upserted and the two existing skills attach to it. The four new categories are bolt 022.

### Migration behaviour

The revision creates `categories`, inserts "Foundations & Greetings" using the same deterministic id the seed derives (verified by a test so they cannot drift), adds `skills.category_id` nullable, backfills every existing skill, then makes it NOT NULL with a foreign key and swaps the global skill-order uniqueness for a per-category one. The downgrade reverses it and is only valid while skill order values are globally unique.

### Decisions made during implementation

- Skill ordering across categories is done in the application layer using the category list, so the skill repository needs no join and test fixtures without a category row still behave.
- The skill-tree query count rose by exactly one (the category list), a constant. The performance bound was raised from 8 to 9 with a comment.
- Fixtures: every test that builds a skill now supplies a category id; a shared fake category repository was added.

### Deviations from the design

None of substance. One incidental: running the formatter touched an unrelated file (`app/domain/services.py`); I reverted that.

### Applied to the dev database

Backed up `backend/dev.db` to `dev.db.bak-pre-021`, ran the migration (now at `a7d1c5e29b04`) and re-ran the seed. Result: one category, both skills attached to it, the 2 progress rows and the user untouched, no duplicate category.

### Notes for later bolts

- Bolt 022: an existing seed test selects the skill with order 1 and expects exactly one; it will need adjusting once several categories each have a skill at order 1.
- Bolt 023: the client should stop reading the deprecated `unit_title`/`unit_subtitle`; removing them from the backend is a follow-up.

### Test status at end of this stage

Full backend suite passes (364 tests) and `ruff check` is clean. Test details belong to Stage 5.
