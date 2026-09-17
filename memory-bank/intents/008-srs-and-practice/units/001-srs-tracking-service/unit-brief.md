---
unit: 001-srs-tracking-service
intent: 008-srs-and-practice
phase: inception
status: ready
created: '2026-09-17T16:55:00Z'
updated: '2026-09-17T16:55:00Z'
---

# Unit Brief: SRS Tracking Service

## Purpose

Introduce a vocab-item content model, track per-user progress against it via a Leitner-box spacing algorithm, and expose due-items/due-count endpoints for the Practice UI to consume.

## Scope

### In Scope
- New `vocab_items` table (content, seeded to cover at least part of the existing curriculum)
- New nullable `exercises.vocab_item_id` FK
- New `user_vocab_progress` table (box level, `next_review_at`, last-seen)
- Retrofit of `complete_lesson` to insert/update `user_vocab_progress` rows for every vocab-linked exercise in a completed lesson
- Leitner-box algorithm (5 boxes, 1/3/7/14/30-day intervals; correct = up one box, incorrect = reset to box 1 / tomorrow)
- Due-items endpoint (`WHERE user_id = ? AND next_review_at <= now() ORDER BY next_review_at LIMIT N`)
- Due-count endpoint (cheap `COUNT`)
- Explicit offline decision: Practice disabled entirely offline (no local computation)

### Out of Scope
- Any UI (owned by `002-practice-ui`)
- Linking every existing exercise to a vocab item (partial coverage is acceptable per requirements.md's Assumptions)
- A parallel practice-completion record type — whether Practice sessions produce `LessonAttempt`-shaped records or something new is a Technical Design decision, not fixed here

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Vocab Item Content Model | Must |
| FR-2 | Per-User Vocab Progress Tracking | Must |
| FR-3 | Leitner-Box Spacing Algorithm | Must |
| FR-4 | Due-Items and Due-Count Endpoints | Must |
| FR-5 | Explicit Offline Behavior | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `VocabItem` (new) | Canonical word/phrase content | `id`, `word`, `translation`, `created_at` |
| `UserVocabProgress` (new) | Per-user, per-vocab-item SRS state | `user_id`, `vocab_item_id`, `box_level` (1-5), `next_review_at`, `last_seen_at` |
| `Exercise` (existing, extended) | Gains optional `vocab_item_id` | — |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| `RecordVocabAnswer` (new, called from `complete_lesson` per vocab-linked exercise) | Applies the Leitner transition | user_id, vocab_item_id, was_correct, now | updated/inserted progress row |
| `ListDueVocab` (new) | Due items for session assembly | user_id, limit | vocab items + their linked exercises, ordered by `next_review_at` |
| `CountDueVocab` (new) | Badge count | user_id | count |

---

## Technical Context

### Suggested Technology
Python/FastAPI/SQLAlchemy, extending `backend/app/domain/lesson/` (new entities/value objects for `VocabItem`/`UserVocabProgress`), new repositories, an Alembic migration for the two new tables + the FK column, index on `user_vocab_progress(user_id, next_review_at)`.

### External Dependencies
None.

---

## Constraints

- `complete_lesson`'s vocab-progress side-effect must compose correctly with the existing offline-replay idempotency check (a delayed sync retried for an already-processed `attempt_id` must not double-update progress) — read `complete_lesson`'s and the offline-sync path's real current implementation at Stage 4 before finalizing.
- Read `database-schema.md`'s `exercises` table definition again at Stage 4 before writing the migration — this unit-brief's assumption that no vocab reference exists anywhere was verified once during requirements-gathering but should be re-confirmed against the real current schema at Construction time, since other work may land first.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 019-srs-tracking-service | ddd-construction-bolt | 001, 002, 003, 004 | Vocab content model + progress retrofit + due endpoints |

---

## Notes

Larger and more foundational than the original build prompt assumed — this is a greenfield data model addition to a shipped service, not activation of dormant columns.
