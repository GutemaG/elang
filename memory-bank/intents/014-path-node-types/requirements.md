---
intent: 014-path-node-types
phase: inception
status: draft
created: '2026-09-21T05:20:00Z'
updated: '2026-09-21T05:20:00Z'
---

# Requirements: Path Node Types

## Intent Overview

Give the learning path more than one kind of stop. Today every node is a lesson, so a
category is a short line of identical circles. Add reward chests, review nodes and a
category-final challenge, so a section reads as a journey with a shape. Type: New Feature
(schema + API + content + UI) — comparable in size to intent 010, not a layout tweak.

Opened from a UX review on 2026-09-21. Units, stories and bolts are **not yet
generated**; this intent holds requirements only until it is picked up.

**Verified against real source before writing** (not assumed):
- **There is no node type today.** `Skill` is `id`, `title`, `order_index`, `category_id`
  and nothing else. Every skill-tree node is a lesson by construction; a chest or a review
  node cannot be represented at all.
- The client mirrors that: `SkillTreeNode` carries `id`, `lessonId`, `title`, `subtitle`,
  `state`, `categoryId`, `crownLevel`, and `SkillPathNode` renders exactly three states —
  locked, active, completed.
- **The "sparse path" is content, not layout.** Intent 010's seed gives each new course
  one category with 2 skills of 2 lessons (FR-9). Even with new node types, a fuller path
  needs more seeded content.
- Progression is per category and linear within it (ADR-11: `order_index` unique per
  category, one shared `SkillPath` rule for "first / next skill in a category"). Any new
  node type has to fit that rule or amend it.
- Amole is an idempotent ledger with `UNIQUE(source, reference_id)` (ADR-8), so a chest
  reward has a natural, safe way to be granted exactly once.
- Review nodes overlap the existing SRS: Practice already selects due vocab for the active
  course (intent 008, ADR-12). A review node should reuse that, not fork it.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| A category reads as a journey, not a list | A category contains more than one kind of node | Must |
| Rewards are visible along the path | Chests appear at intervals and pay Amole exactly once | Must |
| Review has a place in the path | A review node uses the learner's due words for that course | Should |
| Nothing already shipped regresses | Existing suites pass; existing courses keep their progress | Must |

## Functional Requirements

### FR-1: Node Type in the Model
- **Description**: A path entry gains a type — lesson, chest, review, or category test —
  in the schema, the skill-tree response and the client model. Existing rows migrate to
  the lesson type.
- **Acceptance Criteria**:
  - Migration is non-destructive and reversible on a database with users and progress
  - Every existing node reads as a lesson afterwards, with progress intact
  - The skill-tree response stays additive, as ADR-11 and ADR-12 kept it
  - An older client ignoring the new field still renders a usable path
- **Priority**: Must

### FR-2: Progression With Mixed Types
- **Description**: The per-category linear rule (ADR-11) is extended to say what unlocks a
  chest, a review and a category test, and what completing each unlocks.
- **Acceptance Criteria**:
  - The rule lives in the one shared `SkillPath` definition, not duplicated per caller
  - A locked node of any type is not startable and still returns 403
  - Completing a lesson still unlocks the next entry in that category only
  - Switching course is unaffected (ADR-12: lessons gated by their own course)
- **Priority**: Must

### FR-3: Chest Rewards
- **Description**: A chest pays Amole when opened, exactly once, through the existing
  ledger.
- **Acceptance Criteria**:
  - The award is idempotent on `(source, reference_id)`, as ADR-8 provides
  - Re-opening a chest pays nothing and says so
  - A chest opened offline and synced later pays exactly once
- **Priority**: Must

### FR-4: Review Nodes
- **Description**: A review node runs a Practice session over the learner's due vocab for
  that course, reusing the existing SRS rather than a parallel one.
- **Acceptance Criteria**:
  - The session comes from the existing due-items path, scoped to the active course
  - Answers update the same Leitner boxes Practice updates
  - With nothing due, the node is disabled with a clear reason, not hidden
- **Priority**: Should

### FR-5: Category Test
- **Description**: A final challenge per category, drawn from that category's vocabulary.
- **Acceptance Criteria**:
  - Available only once the category's lessons are complete
  - Passing is recorded per category and visible on the banner
  - Failing is repeatable without penalty beyond the normal Beans cost
- **Priority**: Could

### FR-6: Path Rendering
- **Description**: Each node type is visually distinct on the path, keeping the existing
  serpentine layout and the pinned category banner from intent 011.
- **Acceptance Criteria**:
  - Each type is distinguishable without relying on colour alone
  - The download affordance stops overlapping the node's edge (UX review, 2026-09-21)
  - Locked, active and completed still read distinctly for every type
  - No overflow at 320dp and 360dp at 1.3x text
- **Priority**: Must

### FR-7: Seed a Fuller Path
- **Description**: Extend the idempotent seed so a category demonstrates the mix of types.
- **Acceptance Criteria**:
  - Re-running the seed creates no duplicates
  - At least one category shows lessons, a chest and a review together
  - Added content satisfies existing content validation
  - NFR-3 of intent 010 still applies: new Afaan Oromo and Amharic content is not
    native-speaker reviewed
- **Priority**: Must

## Non-Functional Requirements

### NFR-1: Data Integrity
- Migration preserves users, progress, attempts, XP, Amole, vocab progress and downloads.

### NFR-2: Performance
- The skill-tree read keeps its constant query count with mixed node types.

### NFR-3: Offline
- The per-course dashboard cache (ADR-14) round-trips every node type; a chest or review
  node cached for one course is never shown for another.

### NFR-4: Reward Integrity
- No path to awarding a chest twice, including offline replay and retries.

## Scope

**In scope**: node type in schema, API and client; progression rules for mixed types;
chest rewards through the existing ledger; review nodes over the existing SRS; an optional
category test; path rendering per type; seed content; the download-badge overlap fix.

**Out of scope**: bottom navigation; custom illustrations, mascots or cultural iconography
(declined for now on 2026-09-21); a dedicated Fidel section; leaderboards; friends or
social features; per-course streaks.

## Open Questions (for Technical Design, not Inception)
- Whether a node type belongs on `skills` or on a new path-entry table above it.
- Whether a chest is a row with progress, or derived from position in the category.
- Whether a category test is a lesson with a flag or a genuinely different entity.
- How a review node interacts with the dashboard's existing Practice entry card, which
  already offers the same session from outside the path.
