---
unit: 001-lesson-service
bolt: 004-lesson-content-service
stage: model
status: complete
created: 2026-09-16T09:05:00Z
---

## Static Model: Lesson Content Service

### Bounded Context

Lesson content and skill-tree structure for Buna, read-side only. Owns: the catalog of skills, lessons, and exercises (the curriculum), and computing a given user's per-skill state (locked/active/completed) and crown level from that user's existing progress rows. Does not own: writing/mutating `UserSkillProgress` (unlocking a skill, incrementing crown level — story 003/004, bolt `005-lesson-engagement-service`), answer validation or Beans consumption (story 002, bolt `005`), or XP/streak (stories 003/004, bolt `005`). This bolt seeds the `UserSkillProgress` table's schema but never writes a row to it — a user with zero rows is a fully valid, expected state this bolt must handle correctly (new-user bootstrap).

### Entities

- **Skill**: `id`, `title`, `order_index` (its position in the skill tree, lowest = first) — Business rules: `order_index` is unique across all skills (defines a single, total ordering — no branching tree in Phase 1, matching the design's serpentine single-path layout); a skill's own row never carries per-user state (that's `UserSkillProgress`'s job).
- **Lesson**: `id`, `skill_id` (owning skill), `title`, `order_index` (position within its skill), `exercises` (ordered list of `Exercise`) — Business rules: `order_index` is unique within a given `skill_id`; a `Lesson` is always fetched together with its full, ordered `exercises` list — this is not an optional eager-load, it's the entity's shape, because the "one request per lesson" performance NFR requires the whole lesson to be a single unit of retrieval.
- **Exercise**: `id`, `lesson_id`, `order_index`, `type` (`multiple_choice` | `listening` | `sentence_construction`), `prompt`, `content` (type-specific rendering data — see Value Objects), `answer_key` (type-specific correct-answer data — see Value Objects) — Business rules: `order_index` unique within a given `lesson_id`; `content`'s shape must match `type` (a `listening` exercise always carries an `audio_url`, a `sentence_construction` exercise always carries a `word_bank`, etc.); `answer_key` exists on every exercise regardless of type, but is a **write-only-to-the-client concern** — nothing in this bounded context ever serializes `answer_key` back to an API caller (see Ubiquitous Language: "server-side-only answer key").
- **UserSkillProgress**: `user_id`, `skill_id`, `unlocked` (bool), `crown_level` (int, 0-5), `completed_at` (nullable) — Business rules: a row's mere existence for a `(user_id, skill_id)` pair means that skill has been unlocked for that user at least once; `completed_at IS NULL` on an existing row means the skill is unlocked but not yet fully completed (state = active); `completed_at IS NOT NULL` means completed at least once (state = completed, `crown_level >= 1`); **no row at all** for a `(user_id, skill_id)` pair is the default, expected state for every skill a user hasn't touched yet — this bolt computes the correct default state (`active` for the very first skill by `order_index`, `locked` for every other skill) on the fly rather than requiring a pre-seeded row, per story 001's explicit edge case. This bolt only ever reads this table; all writes belong to bolt `005`.

### Value Objects

- **ExerciseType**: one of `multiple_choice` | `listening` | `sentence_construction` — Constraints: exactly the 3 types fixed by `requirements.md` FR-2; no open extensibility assumed in this bolt (a 4th type would be a new Domain Model decision, not a config toggle).
- **Choice**: `id`, `text` — Constraints: immutable; used both for multiple-choice/listening answer options and for sentence-construction word-bank tiles (the same shape — a labeled, selectable/orderable tile — recurs across 2 of the 3 exercise types, per the design system's "Choice & Match Tiles" component).
- **MultipleChoiceContent**: `choices` (ordered list of `Choice`, as presented to the user) — Constraints: at least 2 choices; exactly one of them is correct per the corresponding `ChoiceAnswerKey`.
- **ListeningContent**: `audio_url`, `choices` (ordered list of `Choice`) — Constraints: `audio_url` is never empty; same choice-list shape as `MultipleChoiceContent` (the difference from `multiple_choice` is purely that the prompt is audio, not text).
- **SentenceConstructionContent**: `word_bank` (ordered list of `Choice` tiles, as presented — may include distractor tiles not used in the correct sequence) — Constraints: at least as many tiles as the correct sequence's length; distractor tiles are allowed and expected (tests the learner's ability to pick the right words, not just their order).
- **ChoiceAnswerKey**: `correct_choice_id` (references a `Choice.id` from the sibling `content.choices`) — Constraints: used by `multiple_choice` and `listening` exercises; must reference an id that actually exists in the exercise's own `content.choices`.
- **SequenceAnswerKey**: `correct_sequence` (ordered list of `Choice.id`s, referencing `content.word_bank`) — Constraints: used by `sentence_construction` exercises; every id in the sequence must exist in the exercise's own `content.word_bank`; the sequence may be a strict subset of `word_bank` (distractor tiles are never part of the correct sequence).
- **SkillState**: one of `locked` | `active` | `completed` — Constraints: computed, never stored directly; derived per-user from `UserSkillProgress` (or its absence) plus the skill's `order_index` relative to all other skills, by `SkillTreeProgressionPolicy` below.
- **CrownLevel**: integer, `0-5` — Constraints: `0` means "not yet completed" (paired with `SkillState.locked` or `SkillState.active`); `1-5` only ever appears paired with `SkillState.completed`, per FR-6 (this bolt reads whatever `UserSkillProgress.crown_level` currently holds; incrementing it is out of scope — bolt `005`).

### Aggregates

- **Skill** (Aggregate Root): Members: `Skill` entity only — Invariants: `order_index` is globally unique; a `Skill` has no awareness of any specific user (per-user state lives entirely in the separate `UserSkillProgress` aggregate, deliberately, so that seeding/editing curriculum content never needs to touch or reason about user data).
- **Lesson** (Aggregate Root): Members: `Lesson` entity + its full ordered `Exercise` list (including each `Exercise`'s `content` and `answer_key` value objects) — Invariants: `order_index` unique within `skill_id`; the aggregate is always loaded and returned as a whole (lesson + all its exercises) — there is no valid partial state where a `Lesson` is fetched without its exercises, matching the "no per-exercise round trip" NFR at the aggregate-boundary level, not just the API level.
- **UserSkillProgress** (Aggregate Root): Members: `UserSkillProgress` entity only — Invariants: at most one row per `(user_id, skill_id)` pair; `crown_level > 0` implies `completed_at IS NOT NULL`; a `UserSkillProgress` row is a plain reference to `user_id`/`skill_id` (not an eager-loaded `User`/`Skill`), matching the same independence pattern `001-auth-service`'s `AuthSession` used relative to `User` — this bolt's `SkillTreeProgressionPolicy` composes `Skill` + `UserSkillProgress` read-side without either aggregate depending on the other's transactional boundary.

### Domain Events

None in this bolt. Content (`Skill`/`Lesson`/`Exercise`) is created exclusively by the seed process (story 005), not by any user-facing command — there is no meaningful "SkillCreated" event a consumer would react to at this bolt's scope. `UserSkillProgress` is read-only here, so no state-changing event (e.g. a future `SkillUnlocked`) originates from this bolt either; that belongs to bolt `005`, which is where `UserSkillProgress` rows actually get written for the first time.

### Domain Services

- **SkillTreeProgressionPolicy**: Operations: `compute_states(skills: list[Skill], progress_rows: list[UserSkillProgress]) -> list[SkillTreeEntry]` where `SkillTreeEntry` pairs a `Skill` with its computed `SkillState` and `CrownLevel` — Dependencies: none external (pure domain logic). Sorts skills by `order_index`; for each skill, looks up a matching `UserSkillProgress` row by `skill_id`. If a row exists: `completed_at is None` → `active`/crown 0, else → `completed`/`crown_level` from the row. If no row exists: the skill at the lowest `order_index` (the "first" skill) → `active`/crown 0; every other skill → `locked`/crown 0. This is the single source of truth for "what does a skill look like to this user right now," used identically by both the skill-tree read and the lesson-access check below (so the two can never disagree about a skill's state).
- **LessonAccessPolicy**: Operations: `ensure_accessible(skill_state: SkillState) -> None` (raises `SkillLockedError` if `skill_state == locked`, otherwise no-op) — Dependencies: none external. Enforces story 001's "a locked skill's lesson must be unreachable even by direct lesson ID" rule at the domain layer, so the guarantee doesn't depend on the API layer remembering to check it.

### Repository Interfaces

- **SkillRepository**: Entity: `Skill` — Methods: `list_all() -> list[Skill]` (all skills, any order — callers sort by `order_index` via the policy above, but a repository-level `ORDER BY order_index` is the natural implementation).
- **LessonRepository**: Entity: `Lesson` — Methods: `get_by_id(lesson_id) -> Lesson | None` (loads the lesson plus its full ordered `Exercise` list in one call, per the aggregate's shape above).
- **UserSkillProgressRepository**: Entity: `UserSkillProgress` — Methods: `list_by_user(user_id) -> list[UserSkillProgress]` (every progress row this user has, regardless of skill — used to compute the whole skill tree in one pass without N+1 per-skill lookups).

### Ubiquitous Language

- **Skill tree**: The ordered sequence of `Skill` nodes a user progresses through; currently a single linear path (no branching), matching the Highland Pulse design's serpentine layout.
- **Skill state**: One of `locked` / `active` / `completed` — always computed per-user from `UserSkillProgress` (or its deliberate absence), never a stored column on `Skill` itself.
- **Crown level**: The 1-5 mastery badge shown on a completed skill node; `0` is not a displayed crown, it's the "not completed" sentinel this bolt's read path returns internally.
- **Lesson content payload**: The single-request response containing a `Lesson` and its full ordered `exercises` — the unit that satisfies the "no per-exercise round trip" NFR.
- **Answer key**: The correct-answer data (`ChoiceAnswerKey` / `SequenceAnswerKey`) stored alongside every `Exercise` but never serialized to an API response in this bolt — grading is a server-side-only concern (a Technical Design decision this bolt makes explicit for bolt `005` to build against, since bolt `005`'s `SubmitExerciseAnswer` is the first consumer of `answer_key`).
- **Word bank**: The set of tiles (including distractors) presented for a `sentence_construction` exercise, from which the learner assembles the correct sequence.
- **New-user bootstrap**: The rule that a user with zero `UserSkillProgress` rows still gets a fully correct skill tree (first skill `active`, rest `locked`) without any separate "initialize progress" step — enforced by `SkillTreeProgressionPolicy` treating "no row" as a first-class, expected input, not an error case.

### Open Items Carried Into Stage 2 (Technical Design)

- **Exposing `answer_key` in the lesson-content API response or not** — the domain model above already establishes `answer_key` exists on every `Exercise` and is logically distinct from `content`, precisely so Stage 2 can decide (and document, since bolt `005` depends on it) whether the presentation layer ever serializes it. The domain model's own bias, encoded in the Ubiquitous Language entry above, is server-side-only grading — Stage 2 confirms this as the actual contract.
- **How `content`/`answer_key` are physically stored** (one polymorphic table with JSON columns vs. one table per exercise type) is a Stage 2 persistence decision — the domain model deliberately expresses `content`/`answer_key` as typed value objects so either storage strategy can back them without changing this model's shape.
- **Deterministic vs. random IDs for seeded content**, needed for story 005's idempotent-reseed requirement, is a Stage 2/Construction detail — the domain model doesn't care how `Skill.id`/`Lesson.id`/`Exercise.id` are generated, only that they're stable identifiers.
