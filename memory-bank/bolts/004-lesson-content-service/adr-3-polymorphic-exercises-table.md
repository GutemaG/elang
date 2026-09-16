---
bolt: 004-lesson-content-service
created: 2026-09-16T09:25:00Z
status: accepted
superseded_by: null
---

# ADR-3: Single polymorphic `exercises` table with JSON `content`/`answer_key` columns

## Context

The lesson engine supports exactly 3 exercise types (`multiple_choice`, `listening`, `sentence_construction`), fixed by `requirements.md` FR-2 and closed for this intent's scope (speech/pronunciation exercises are explicitly deferred). Each type needs different rendering data (`choices` vs. `audio_url` + `choices` vs. `word_bank`) and different correct-answer data (`correct_choice_id` vs. `correct_sequence`), but all 3 share the same surrounding shape: an ordered exercise within a lesson, with a prompt, that gets graded. Stage 2 (Technical Design) needed to decide how to persist this in `database-schema.md` before Stage 4 (Implement) could build the `exercises` table.

## Decision

Model exercises as a single `exercises` table with a `type` discriminator column, a `prompt` text column, and two JSON columns: `content` (the type-specific data the API is allowed to serialize back to the client) and `answer_key` (the type-specific correct-answer data, never serialized — see ADR-4). Application code reads `type` to know how to interpret `content`/`answer_key` and constructs the matching domain value object (`MultipleChoiceContent`, `ListeningContent`, or `SentenceConstructionContent`).

## Rationale

With exactly 3 known, closed types and no plan to add exercise types within this intent, the choice is effectively between (a) one polymorphic table, (b) one table per type, or (c) one wide table with a column per possible field across all types. Given the small, fixed type set and that the only query pattern this bolt needs is `SELECT ... WHERE lesson_id = ? ORDER BY order_index`, a polymorphic table keeps that query trivial and index-friendly, while per-type tables would force either 3 near-identical tables with a fan-out `UNION`-style query to reconstruct a lesson's ordered exercise list, or an inheritance-mapping layer neither `001-auth-service` nor `tech-stack.md`/`data-stack.md` establishes any precedent for. `sqlalchemy.JSON` (not Postgres-only `JSONB`) is used specifically because this bolt never queries *inside* the JSON — it's read out whole and interpreted in Python — so it round-trips identically on SQLite (local dev/test) and PostgreSQL (deployment) without hitting `data-stack.md`'s documented SQLite/Postgres JSON-operator gap.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| One table per exercise type (`multiple_choice_exercises`, `listening_exercises`, `sentence_construction_exercises`) | Fully typed columns, DB-level constraints per type | Reconstructing a lesson's ordered exercise list requires a 3-way `UNION`/fan-out query or an application-side merge-and-sort across 3 repositories; adds real complexity for 3 fixed, small tables | The extra normalization buys nothing at this scale/type-count and actively complicates the one query this bolt actually runs |
| One wide `exercises` table with a nullable column per possible field (`choices_json`, `audio_url`, `word_bank_json`, `correct_choice_id`, `correct_sequence_json`) | Single table, no JSON parsing needed for individual scalar fields | Every row has several always-`NULL` columns depending on `type`; no natural place to add a 4th type later without another schema migration touching every row | Polymorphic-via-JSON gets the same "one table" benefit without the sparse-column smell, and is easier to extend by type later (a 4th type just needs a new `content`/`answer_key` shape, not new columns) |
| Single polymorphic table with JSON `content`/`answer_key` (chosen) | One simple table, one simple query, easy to extend by type, no SQLite/Postgres JSON-operator dependency since nothing queries inside the JSON | Less DB-level type safety on `content`/`answer_key` shape (enforced in the domain/application layer instead) | N/A — this is the decision |

## Consequences

### Positive
- The `exercises` table and its one repository method (`LessonRepository.get_by_id`, which loads a lesson's exercises as part of its aggregate) stay simple regardless of how many exercise types eventually exist.
- No SQLite/Postgres divergence risk from JSON operators, since nothing in this bolt (or, per Decision 1/ADR-4, in bolt `005`'s answer-key lookup) needs to query inside the JSON columns — both are always read out whole by primary key or `lesson_id`.
- Adding a 4th exercise type later (explicitly out of scope for this intent, but plausible for a future one) is a domain/application-layer change (new value object + a new `type` string), not a schema migration.

### Negative
- `content`/`answer_key` shape correctness (e.g. "a `listening` exercise's `content` must have `audio_url`") is enforced only in application code (when constructing the domain value object from the JSON), not by a DB constraint — a hand-edited row with a mismatched `type`/`content` pair would only be caught when read back, not at write time by the database itself.

### Risks
- If a future exercise type needs genuinely relational data (e.g. a many-to-many with some other entity, not just a self-contained JSON blob), this pattern won't extend cleanly and would need its own decision at that point. Not a concern for the 3 types in scope now.

## Related

- **Stories**: 001-serve-skill-tree-and-lesson-content, 005-seed-curriculum-content
- **Standards**: `memory-bank/standards/data-stack.md` (SQLite/Postgres JSON-operator gap this decision deliberately avoids triggering)
- **Previous ADRs**: None directly related (first content-modeling ADR in this project); complements ADR-4 (server-side-only `answer_key`), which is the reason `content` and `answer_key` are kept as two separate JSON columns rather than one.
