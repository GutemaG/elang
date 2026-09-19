---
stage: model
bolt: 021-categories-service
created: '2026-09-19T20:10:00Z'
---

## Static Model: categories-service

### Entities

- **Category** (new): `id`, `title`, `subtitle` (Amharic tagline), `order_index`, `created_at`. Content only, no per-user state, same category of thing as `Skill`/`Lesson`. Business rules: `order_index` is unique across categories; a category may hold zero skills (harmless, renders nothing).
- **Skill** (existing, extended): gains a required `category_id`. Business rules: every skill belongs to **exactly one** category; a skill's position within its category is given by its `order_index`.
- **UserSkillProgress** (existing, unchanged): still per-user, per-skill (`unlocked`, `crown_level`, `completed_at`, `completed_lesson_ids_this_cycle`). Progress is not stored per category; a category's completion is always derived from its skills' progress.

### Value Objects

- **SkillPath** (new, conceptual): the ordered sequence of skills inside one category. Its two questions define all progression: "which skill is first?" and "which skill follows skill X?" (none for the last). Equality by value; no identity of its own.
- **CategorySummary** (derived, read-side): `category`, `skill_count`, `completed_count` - computed for presentation, never stored.

### Aggregates

- **Category** (aggregate root, trivial - content only). It does not *contain* skills; skills reference it by id, keeping `Skill` its own root exactly as today so lesson/exercise aggregates are untouched.
- **Skill** (aggregate root): new invariant - `category_id` must reference an existing category.
- **UserSkillProgress** (aggregate root): unchanged invariants.

### Domain Events

- **SkillCompleted**: Trigger: `LessonCompletionService` finishes the final lesson of a skill's cycle. Payload: `user_id`, `skill_id`. Effect (amended): unlocks the next skill **in the same category's path**, not the next skill in the global list. If the skill is last in its category, no unlock occurs and no error is raised. Documented as a conceptual trigger; the codebase uses `LessonCompletionOutcome`-style return values rather than event objects (same convention as bolt 019).

### Domain Services

- **SkillTreeProgressionPolicy** (existing, amended, pure): Operations: `compute_states(skills, progress_rows) -> entries` and `state_for_skill(...)`. Amended rule: group skills by category; within each category order by `order_index`; a skill with a progress row is COMPLETED or ACTIVE as today; a skill with **no** row is ACTIVE only if it is first in its category's path, otherwise LOCKED. Every category is therefore open from the start.
- **LessonCompletionService** (existing, amended, pure): unlock step uses the skill's category path rather than the global ordering.
- **Shared rule**: "first skill of a category" and "next skill after X in its category" must have a single definition used by both services and by the lesson-access check (`LessonAccessPolicy` consumes `state_for_skill`), so the tree read, the access check and the completion unlock cannot disagree. Where that single definition physically lives is a Technical Design decision.

### Repository Interfaces

- **CategoryRepository** (new): Entity: `Category`. Methods: `list_all() -> list[Category]` ordered by `order_index`.
- **SkillRepository** (existing, amended): returned `Skill` entities now carry `category_id`. No new method needed for the tree read (it already lists all skills); any completion-time lookup of "skills in this skill's category" can be answered from the already-loaded skill list.
- **UserSkillProgressRepository**, **LessonRepository**, exercise/vocab repositories: unchanged.

### Ubiquitous Language

- **Category**: a named group of related skills (e.g. "Family & People"). Replaces the previously hardcoded "Unit".
- **Skill path**: the ordered skills within one category; progression is linear along it.
- **Open category**: every category is available from the start; only the first skill of its path is initially active.
- **First skill / next skill (in category)**: the two questions the progression rule answers.
- **Foundations & Greetings**: the first category, holding the two pre-existing skills (Greetings & Basics, Food & Drink).

### Open Questions Carried to Technical Design (flagged, not resolved here)

1. Whether `uq_skills_order_index` stays globally unique or becomes unique per category.
2. The `GET /skill-tree` response envelope (nested `categories[].skills[]` vs. flat `skills` plus a `categories` list), and which is additive-safe for the current Flutter client.
3. The physical home of the shared "path" rule (a helper in `domain/lesson/`, a method on the policy, or a small value-object class).
4. Migration strategy on a populated SQLite/Postgres database (nullable-add, backfill, then NOT NULL) and the ordering of skills after backfill.

### Story Coverage

- `001-category-content-model-and-migration`: `Category`, `Skill.category_id`, `CategoryRepository`, first-category backfill rule.
- `002-per-category-progression`: `SkillPath`, amended `SkillTreeProgressionPolicy` and `LessonCompletionService`, `SkillCompleted`.
- `003-skill-tree-api-with-categories`: `CategorySummary` (read-side), `CategoryRepository.list_all`, open questions 1-2 for the response shape.
