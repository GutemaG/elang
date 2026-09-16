---
unit: 001-match-pairs-service
bolt: 011-match-pairs-service
stage: model
status: complete
updated: '2026-09-17T05:10:00Z'
---

# Static Model - Match-Pairs Service

## Bounded Context

Extends the existing **Lesson Content** bounded context (`001-lesson-service`, established in bolts 004/005). No new bounded context is introduced — `match_pairs` is a 4th variant of the existing `Exercise` entity's polymorphic content, governed by the same rules as `multiple_choice`, `listening`, and `sentence_construction`.

## Domain Entities

| Entity | Properties | Business Rules |
|--------|------------|-----------------|
| `Exercise` (existing, unchanged) | `id`, `lesson_id`, `type: ExerciseType`, `content: JSON`, `order_index` | Content shape is determined entirely by the `type` discriminator (ADR-3's polymorphic-table pattern) — this bolt adds one more valid shape for `content` when `type == MATCH_PAIRS`, nothing else about `Exercise` changes |

## Value Objects

**Corrected during Stage 4 (Implement), 2026-09-17** — the shapes below were revised after reading the actual codebase (forbidden until Stage 4 per the bolt type's rules; this is exactly the kind of gap that constraint is meant to surface). The original plan had `MatchPairsContent` be its own `answer_key`-free ground truth via a `TermTranslationPair` value object. That contradicted two things only visible in the real code: `Exercise.answer_key` is a mandatory field, and every existing type keeps `content` (renderable) strictly separate from `answer_key` (correct-answer), reusing the existing `Choice` value object rather than inventing a new one. See `ddd-02-technical-design.md`'s "Domain Model Correction" section for the full explanation.

| Value Object | Properties | Constraints |
|--------------|------------|--------------|
| `MatchPairsContent` | `left_tiles: tuple[Choice, ...]`, `right_tiles: tuple[Choice, ...]` | ≥2 left tiles; `right_tiles` same length as `left_tiles`. Reuses the existing `Choice` value object (already used by the other 3 types) — no new tile type. The correct association lives entirely in the sibling `PairAnswerKey`, not here |
| `PairAnswerKey` | `correct_pairs: tuple[tuple[str, str], ...]` | ≥2 pairs; each tuple is `(left_choice_id, right_choice_id)` referencing `content`'s tile ids |

## Aggregates

| Aggregate Root | Members | Invariants |
|-----------------|---------|------------|
| `Lesson` (existing, unchanged) | `Exercise` entities (including any `match_pairs`-typed ones) | Unchanged from `001-lesson-service` — a `match_pairs` exercise is just one more child entity type within the existing aggregate boundary |

## Domain Events

None new. This bolt introduces no new domain event — `LessonCompleted` and other existing events from `001-lesson-service` are untouched, since (per the Constraints section below) no grading logic lives in this unit at all.

## Domain Services

None new. **This is the key scope correction from this stage**: the original bolt plan (from Inception) included a grading service here. Applying the mandatory prior-decision lookup surfaced **ADR-5** (`memory-bank/bolts/005-lesson-engagement-service/adr-5-client-side-grading-with-bounded-server-ledger.md`): all exercise grading in this codebase is client-side — the backend serves both `content` (renderable) and `answer_key` (correct-answer, per the Value Objects correction above) in the same lesson-content response, and only bounds the Beans/XP ledger; it never computes or re-verifies per-exercise correctness. There is therefore no `MatchPairsGradingService` or equivalent in this unit. That responsibility belongs to `002-match-pairs-ui` (client-side), covered by its existing story `001-match-pairs-exercise-screen`.

## Repository Interfaces

| Repository | Entity | Methods |
|------------|--------|---------|
| `ExerciseRepository` (existing, unchanged) | `Exercise` | No new methods — `match_pairs` exercises are read/written through the existing repository exactly like the other 3 types, since content is JSON per ADR-3 |

## Ubiquitous Language

| Term | Definition |
|------|------------|
| `match_pairs` | The 4th exercise type: the learner matches Amharic-term tiles to their English-translation tiles by tapping one from each column |
| `ExerciseType` | The existing discriminator enum (`multiple_choice`, `listening`, `sentence_construction`, and now `match_pairs`) on the polymorphic `exercises` table (ADR-3), whose `CHECK` constraint required widening (see Technical Design) |

## Story Coverage

- **001-serve-match-pairs-exercise-content**: fully covered — `Exercise`/`MatchPairsContent`/`PairAnswerKey` above define exactly what this story needs to serve
- ~~002-grade-match-pairs-attempts~~: retired at this stage (see Domain Services above); not covered here by design — see `002-match-pairs-ui`'s domain model when that unit starts
