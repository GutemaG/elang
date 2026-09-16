---
stage: design
bolt: 011-match-pairs-service
created: '2026-09-17T05:20:00Z'
---

## Technical Design: Match-Pairs Service

### Architecture Pattern

No new pattern — reuses `001-lesson-service`'s existing layered architecture (Presentation → Application → Domain → Infrastructure) exactly as bolts 004/005 established it. `match_pairs` slots into the existing polymorphic-content pattern from **ADR-3** (single `exercises` table, `type` discriminator, JSON `content`/`answer_key` columns).

### Layer Structure

```text
┌─────────────────────────────┐
│      Presentation           │  Existing lesson-content FastAPI router(s) — unchanged path/method
├─────────────────────────────┤
│      Application             │  Existing lesson-content-serving use case — extended to pass through match_pairs content, no new use case
├─────────────────────────────┤
│        Domain                │  ExerciseType.MATCH_PAIRS, MatchPairsContent, TermTranslationPair (see ddd-01-domain-model.md)
├─────────────────────────────┤
│     Infrastructure           │  Existing exercises table (JSON content column) — no schema change
└─────────────────────────────┘
```

### API Design

- **No new endpoint.** The existing lesson-content endpoint (the same one that already serves `multiple_choice`/`listening`/`sentence_construction` exercises within a lesson) is extended so that when an exercise's `type == "match_pairs"`, its `content` field is serialized as:

  ```json
  {
    "pairs": [
      { "left": "ቡና", "right": "coffee" },
      { "left": "ውሃ", "right": "water" }
    ]
  }
  ```

- No request schema change (this is a read path — content is served, not submitted, since grading is client-side per ADR-5).
- No changes to the `/lessons/{id}/complete` endpoint or its request/response schema — a lesson containing a `match_pairs` exercise completes through that endpoint exactly as any other lesson does today (bounded-ledger validation, unchanged).

### Data Model

- **Corrected during Stage 4 (Implement), 2026-09-17** — this section originally claimed no migration was needed. That was wrong: reading the actual `ExerciseModel` (`backend/app/infrastructure/db/lesson_models.py`) at Implement time surfaced `ck_exercises_type`, a `CheckConstraint("type IN ('multiple_choice', 'listening', 'sentence_construction')")` — a real constraint this bolt must widen. This is exactly the risk the bolt type's "no source code reading in Stages 1-2" rule exists to flag *for*: a design decision made without reading the schema turned out to be incomplete.
- **A migration IS required**: `exercises.content`/`answer_key` are JSON (ADR-3, correct as originally stated), but the `type` column has a `CHECK` constraint enumerating the valid values, which does not auto-widen. Delivered as migration `c726efa81972` using `op.batch_alter_table(...)` (SQLite cannot `ALTER`/drop a `CHECK` constraint in place; batch mode recreates the table on SQLite and issues a normal `ALTER` on PostgreSQL — safe on both, verified via downgrade/upgrade round-trip).
- `answer_key` for `match_pairs` rows: **not** left `NULL` as originally planned either — see the Domain Model correction below. `MatchPairsContent` (rendered tiles) and `PairAnswerKey` (correct pairing) are separate, mirroring `multiple_choice`'s existing `content`/`answer_key` split, not merged into one self-revealing `content` blob.
- Seed data: one new row (order_index 5) added to the existing "Coffee & Tea" lesson in `backend/app/infrastructure/db/seed_lesson_content.py`, following the same idempotent `uuid5`-derived-id pattern already used for the other 3 types.

### Domain Model Correction (also found at Implement time)

Stage 1's `MatchPairsContent`/no-`answer_key` design (each `{left, right}` pair *is* its own ground truth) turned out to be inconsistent with the actual codebase: `Exercise.answer_key` is a **mandatory, non-optional** field (`backend/app/domain/lesson/entities.py`), and every existing type keeps `content` (renderable) and `answer_key` (correct-answer) strictly separate — e.g. `multiple_choice`'s `content.choices` lists options, `answer_key.correct_choice_id` says which is right. Corrected shape, now implemented:

- `MatchPairsContent(left_tiles: tuple[Choice, ...], right_tiles: tuple[Choice, ...])` — two independently-shuffleable columns, reusing the existing `Choice` value object (already used by the other 3 types) instead of a new `TermTranslationPair` type.
- `PairAnswerKey(correct_pairs: tuple[tuple[str, str], ...])` — `(left_choice_id, right_choice_id)` tuples referencing `content`'s tile ids.

This also matches the actual API response pattern (`lesson_schemas.py`): every exercise type flattens both its content *and* its answer fields into one discriminated response model (e.g. `MultipleChoiceExerciseResponse` has both `choices` and `correct_choice_id`). `MatchPairsExerciseResponse` follows suit: `left_tiles`, `right_tiles`, `correct_pairs`.

### Security Design

No new security concern. Reuses the existing session-token-authenticated lesson-content endpoint; `match_pairs` content carries no more sensitive data than the other 3 exercise types (it's curriculum content, not user data).

### NFR Implementation

- **Zero added network round-trips**: content is served once, alongside the other exercises in the lesson-content response; grading happens client-side with zero backend calls (consistent with `002-core-lesson-loop`'s existing "no network call per exercise" NFR and ADR-5).
- **No regression to other 3 exercise types**: the change is additive (one new `type` discriminator value + one new `content` shape); nothing about the existing serialization path for the other types is touched.
