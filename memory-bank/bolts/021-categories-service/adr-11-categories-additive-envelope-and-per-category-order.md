---
bolt: 021-categories-service
created: '2026-09-19T20:45:00Z'
status: accepted
superseded_by: null
---

# ADR-11: Categories as a first-class level: per-category skill ordering, additive skill-tree envelope, and one shared `SkillPath` rule

## Context

Until now the curriculum was a flat, globally ordered list of skills under one hardcoded "Unit 1" banner. Three facts, verified against real source during Inception, constrain how a category level can be added:

- `skills` carries a **global** `uq_skills_order_index`, and both `SkillTreeProgressionPolicy` (first-skill bootstrap) and `LessonCompletionService` (unlock `ordered[current_index + 1]`) walk that one global list. Progression is therefore implicitly "one chain".
- `GET /skill-tree` returns `unit_title`/`unit_subtitle` from two backend constants, and the Flutter client parses them as required strings (`json['unit_title'] as String`).
- The skill-tree read, the lesson-access check (`state_for_skill`) and the completion unlock must never disagree about which skill is open.

## Decision

1. **Skill order is unique per category**, not globally: replace `uq_skills_order_index` with `UNIQUE(category_id, order_index)`. `order_index` now means "position inside the category".
2. **The skill-tree response changes additively** (ADR-10's precedent): keep the flat `skills` list, add a `categories` list and a `category_id` on every skill, and keep `unit_title`/`unit_subtitle` (deprecated), derived from the first category rather than hardcoded. No existing field is removed or renamed.
3. **One shared rule**: a pure `SkillPath` value object (`first`, `next_after(skill_id)`) in `domain/lesson/`, used by both `SkillTreeProgressionPolicy` and `LessonCompletionService`. Every category is open from the start; progression is linear only within a category.

## Rationale

Per-category ordering matches the domain meaning of the field and keeps content authoring local to a category. The additive envelope keeps the shipped app working during the window between this backend bolt (021) and the UI bolt (023), and follows the way this project already widened `CompleteLessonRequest`. A single `SkillPath` definition removes the risk of the three consumers drifting apart.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Keep global `order_index` uniqueness | No constraint swap in the migration | Global counter leaks into every future category's content authoring; field meaning stays muddy | Per-category is the natural meaning; the migration cost is one-time |
| Nested `categories[].skills[]` response | Cleaner shape | Breaks the current Flutter parser immediately; app unusable until bolt 023 | Additive envelope is safe at every intermediate commit |
| Remove `unit_title`/`unit_subtitle` now | No deprecated fields | Crashes the shipped client until 023 lands | Keep, derive from first category, remove later |
| Progression rule as a method on the policy | Fewer types | Completion service would depend on the policy for an unrelated concern | Separate value object keeps both services independent |

## Consequences

### Positive

- Every category is open, and its progression is independent of the others.
- The shipped app keeps working after bolt 021 alone.
- One definition of "first / next in category" for tree read, access check and completion unlock.

### Negative

- The migration must swap a unique constraint (SQLite batch mode), and downgrade is only safe while order values are globally unique (documented in the migration).
- `unit_title`/`unit_subtitle` linger as deprecated fields until a later cleanup.
- `Skill` gains a required `category_id`, so many test fixtures change.

### Risks

- Risk: a later code path re-introduces global ordering. Mitigation: tests assert independence between categories (completing a skill in one category changes nothing in another).
- Risk: the deprecated fields are never removed. Mitigation: recorded as a follow-up in bolt 023's Plan.

## Related

- **Stories**: `001-category-content-model-and-migration`, `002-per-category-progression`, `003-skill-tree-api-with-categories`
- **Standards**: none new
- **Previous ADRs**: follows ADR-10's additive-contract-widening precedent; ADR-3's content-table pattern is unchanged
