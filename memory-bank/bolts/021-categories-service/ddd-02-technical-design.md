---
stage: design
bolt: 021-categories-service
created: '2026-09-19T20:30:00Z'
---

## Technical Design: categories-service

Stage 2 does not read source. Everything below rests on facts verified during Inception (skills schema and `uq_skills_order_index`, the two progression code paths, the hardcoded unit constants, the seed's structure, the Flutter parser reading `unit_title`/`unit_subtitle`). Anything not verified then is listed under "Verify at Stage 4".

### Architecture Pattern

Same layered pattern as the rest of `001-lesson-service`: pure domain rules in `domain/lesson/`, use cases in `application/`, SQLAlchemy repositories in `infrastructure/db/`, FastAPI routers/schemas in `infrastructure/api/`. No new pattern is introduced; this is an amendment of existing layers.

### Layer Structure

```text
┌──────────────────────────────────────────────┐
│ Presentation  lesson_schemas / lesson_routers │  + CategoryResponse, category_id, categories
├──────────────────────────────────────────────┤
│ Application   get_skill_tree                  │  reads categories; unit constants removed
├──────────────────────────────────────────────┤
│ Domain        Category, Skill(+category_id),  │  SkillPath shared by policy + completion
│               SkillTreeProgressionPolicy,     │
│               LessonCompletionService         │
├──────────────────────────────────────────────┤
│ Infrastructure CategoryModel, SkillModel FK,  │  Alembic migration, repositories, seed
│                CategoryRepository, seed       │
└──────────────────────────────────────────────┘
```

### Design Decisions (for your approval)

**D1. Skill ordering uniqueness: make it per-category (recommended).**
Replace the global `uq_skills_order_index` with `UNIQUE(category_id, order_index)`. A skill's `order_index` then means "position within its category", matching the domain model, and the seed does not need a global counter (each category's skills are 1, 2). The two existing skills keep order_index 1 and 2 inside Foundations. Cost: the migration must swap the constraint (SQLite needs Alembic batch mode). Alternative: keep the global constraint and give new skills indices 3 to 10; less migration work, but it leaks a global counter into content authoring and every future category. Any code that sorts skills globally by `order_index` (the two services) is being rewritten by this bolt anyway.

**D2. Skill-tree response envelope: flat `skills` plus a `categories` list, additive (recommended).**
- Add `categories: [{id, title, subtitle, order_index}]` to `SkillTreeResponse`.
- Add `category_id` to each `SkillTreeEntryResponse`.
- Keep `skills` as the existing flat list, ordered by category order then skill order.
- Keep `unit_title` and `unit_subtitle` in the response, but derive them from the **first category** instead of hardcoded constants, marked deprecated. Reason: the current Flutter parser does `json['unit_title'] as String`, so removing them would crash the app between this bolt and bolt 023. This satisfies FR-3's "hardcoded constants removed from the backend" while following ADR-10's additive precedent. The fields can be dropped in a later cleanup once the client stops reading them.
Alternative: nested `categories[].skills[]`, which is cleaner but breaks the current client immediately.

**D3. Shared progression rule: a small pure `SkillPath` value object in `domain/lesson/` (recommended).**
`SkillPath.group(skills) -> dict[category_id, SkillPath]`; each path exposes `first` and `next_after(skill_id)` (returns `None` for the last skill). `SkillTreeProgressionPolicy` and `LessonCompletionService` both build paths from the same skill list and use these two methods, so there is exactly one definition. `LessonAccessPolicy` is unchanged and keeps consuming `state_for_skill`. Alternative: a method on the policy; rejected because the completion service would then depend on the policy for something unrelated to states.

**D4. Migration strategy (data-preserving, one revision after `c29bf2c53433`).**
1. Create `categories`.
2. Insert "Foundations & Greetings" with the deterministic id `uuid5(CONTENT_NAMESPACE, "category:foundations-and-greetings")`, using the same namespace derivation as the seed (`uuid5(NAMESPACE_DNS, "buna.app/lesson-content")`, re-derived inline; the migration must not import app code). The seed will then upsert the same row rather than creating a duplicate.
3. Add `skills.category_id` nullable, backfill every existing skill to that id.
4. Batch-alter: make it NOT NULL with an FK to `categories.id`; drop `uq_skills_order_index`; add `UNIQUE(category_id, order_index)`.
5. Downgrade reverses in the opposite order (restoring the global unique constraint is safe only while order_index values remain globally unique; downgrade documents this).
Existing users, progress, attempts, XP, Amole and vocab rows are not touched. Backup the dev DB before applying (I did this for the previous migration).

**D5. Seed change belongs in this bolt (minimal).**
Once `category_id` is NOT NULL, the existing seed can no longer insert skills. Bolt 021 therefore makes the smallest seed change: define the Foundations category and attach the two existing skills to it. The four new categories are bolt 022.

### Data Model

- **`categories`** (new): `id` String(36) PK, `title` String(255) NOT NULL, `subtitle` String(255) NOT NULL, `order_index` Integer NOT NULL, `created_at` timestamp; `UNIQUE(order_index)`.
- **`skills`** (amended): `category_id` String(36) NOT NULL, FK to `categories.id`; `uq_skills_order_index` replaced by `UNIQUE(category_id, order_index)`; index on `category_id`.
- **Domain**: `Category` frozen dataclass; `Skill` gains required `category_id` (required, not defaulted, so an orphan skill is unrepresentable; every test fixture that builds a `Skill` needs updating, handled with one shared helper).

### API Design

- **`GET /api/v1/skill-tree`**: response gains `categories` (list of `CategoryResponse {id, title, subtitle, order_index}`) and per-skill `category_id`. `unit_title`/`unit_subtitle` remain, sourced from the first category. All other fields unchanged.
- No new endpoints. No request changes. `GET /lessons/{id}` behaviour and the locked-skill 403 are unchanged (they go through `state_for_skill`, now category-aware).

### Progression Behaviour (exact rules)

- For each category, order its skills by `order_index`.
- Skill with a progress row: COMPLETED if `completed_at` set (with its crown level), otherwise ACTIVE.
- Skill with no row: ACTIVE if it is the first skill of its category, otherwise LOCKED.
- On skill completion: unlock `path.next_after(skill_id)` if it exists; if `None`, return no unlock and no title (no error).
- Existing user with Greetings completed and Food & Drink active: unchanged, because both are in Foundations in the same relative order. Other categories show their first skill active via the on-the-fly bootstrap, needing no stored rows.

### Security Design

- Read-only change to an authenticated endpoint; no new inputs. Content-access enforcement (locked skill → 403) still flows through `state_for_skill`, so it holds for every category. A test asserts this for a non-first skill of a non-Foundations category.

### NFR Implementation

- **Performance (NFR-2)**: `get_skill_tree` already loads all skills; categories add exactly one more `list_all` query, a constant, not per category or per skill. Grouping is in memory (O(skills)). The existing performance test's query bound must be re-checked (expected +1).
- **Data integrity (NFR-1)**: nullable-add, backfill, then NOT NULL inside one migration; verified by a migration test on a populated database and a downgrade round trip.
- **Reliability**: completion unlock has a single code path; the last-skill-in-category case returns cleanly.

### Test Plan (detail at Stage 5)

- Unit: `SkillPath` (first, next_after, last, single-skill category, empty), policy across multiple categories, completion unlock within category and at category end.
- Integration: skill-tree returns categories in order with `category_id`; brand-new user sees one ACTIVE per category; completing skill 1 of a category unlocks only skill 2 of that category; locked skill's lesson 403 in a non-Foundations category; deprecated `unit_title` present and equal to the first category's title.
- Migration: upgrade on a populated DB preserves rows; downgrade round trip.
- Regression: full existing backend suite; performance test.

### Verify at Stage 4 (not verified in this source-blind stage)

- Exact current code of `SkillTreeProgressionPolicy`, `LessonCompletionService`, `get_skill_tree` and the repositories (only line-level facts from Inception are assumed).
- Whether anything else sorts skills globally by `order_index` or depends on `uq_skills_order_index` (repositories, `list_lesson_ids_by_skills`, tests, seed).
- The performance test's actual query-count assertion.
- Number of test fixtures constructing `Skill`/`SkillModel` that need `category_id`.
- Whether `tests/fakes.py` needs a `FakeCategoryRepository`.

### Story Coverage

- 001: `Category`, `categories` table, D1, D4, D5.
- 002: `SkillPath` (D3), amended policy and completion service.
- 003: `CategoryResponse`, `category_id`, D2, constant query count.
