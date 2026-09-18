---
stage: design
bolt: 019-srs-tracking-service
created: '2026-09-17T21:30:00Z'
---

## Technical Design: srs-tracking-service

### Architecture Pattern

Same layered architecture as every prior backend unit in this codebase (`001-lesson-service`, `001-offline-sync-service`, `001-amole-service`): Domain → Application → Infrastructure → Presentation, with domain services kept pure (no I/O) per the convention re-affirmed by ADR-8/bolt 017's Stage-4 correction. No new pattern introduced.

### Layer Structure

```text
┌─────────────────────────────┐
│      Presentation           │  lesson_routers.py (extended) + new practice router
├─────────────────────────────┤
│      Application            │  complete_lesson (extended) + get_due_items/get_due_count use cases
├─────────────────────────────┤
│        Domain               │  VocabItem, UserVocabProgress, LeitnerBoxPolicy
├─────────────────────────────┤
│     Infrastructure          │  vocab_items/user_vocab_progress tables + repos
└─────────────────────────────┘
```

- **Domain**: `VocabItem`, `UserVocabProgress` entities; `LeitnerBoxIntervals`/`IncorrectResetInterval` value objects; `LeitnerBoxPolicy` (pure).
- **Application**: `complete_lesson` gains a further side effect — for each vocab-linked exercise resolved as answered within the completion, load-or-create the user's `UserVocabProgress` row, run it through `LeitnerBoxPolicy.apply`, and upsert. New standalone use cases `get_due_items(user_id, limit)` and `get_due_count(user_id)`, thin wrappers over the repository's shared predicate.
- **Infrastructure**: `VocabItemModel`, `UserVocabProgressModel` (SQLAlchemy), `ExerciseModel` gains nullable `vocab_item_id`; `SqlAlchemyVocabItemRepository`, `SqlAlchemyUserVocabProgressRepository`.
- **Presentation**: extend nothing on the request/response shape yet where avoidable (see Open Question below — resolved at Stage 4); add two new read endpoints for due-items/due-count.

### API Design

- **`GET /api/v1/practice/due-count`**: Method: GET — Request: none (current user from auth) — Response: `{ "due_count": int }`.
- **`GET /api/v1/practice/due-items?limit=N`**: Method: GET — Request: query param `limit` (default TBD at Stage 4, e.g. 20) — Response: `{ "items": [{ "vocab_item_id": str, "word": str, "translation": str, "exercise_id": str, "box_level": int, "next_review_at": datetime }] }`. Each item carries enough to resolve its exercise for session assembly (story `004`'s requirement) — exact exercise-resolution shape depends on the `ExerciseRepository` amendment, finalized at Stage 4.
- **`POST /api/v1/lessons/{lesson_id}/complete`** (existing, `001-lesson-service`/`005-lesson-engagement-service`): no request-contract change is designed here. **Open question carried from Stage 1, still unresolved**: if the current request truly only carries aggregate `correct_count`/`total_count` (per ADR-5), this endpoint cannot know which specific vocab-linked exercises were right/wrong, and vocab-progress tracking would need to fall back to a coarser signal (e.g., all vocab items shown in the lesson move as a block, in the same direction as the aggregate result) or the request contract must widen to include a per-exercise result list. **This is a Stage 4 decision, not a Stage 2 one** — Stage 4 will read `CompleteLessonRequest`'s actual current schema and the Flutter completion call before choosing between "widen the contract" (small breaking API change, needs an ADR) and "block-level vocab update" (no contract change, coarser accuracy). Both are technically named here so Stage 3's ADR Analysis can consider whether a contract widening (if chosen) is ADR-worthy.

### Data Model

- **`vocab_items`** (new): Columns: `id` (UUID PK), `word` (text, not null), `translation` (text, not null), `created_at` (timestamp, not null). No relationships beyond being referenced by `exercises`/`user_vocab_progress`.
- **`user_vocab_progress`** (new): Columns: `user_id` (UUID, FK → `users.id`, not null), `vocab_item_id` (UUID, FK → `vocab_items.id`, not null), `box_level` (int, not null, `CHECK (box_level BETWEEN 1 AND 5)`), `next_review_at` (timestamp, not null), `last_seen_at` (timestamp, not null). Relationships: composite primary key `(user_id, vocab_item_id)` — enforces the domain model's "at most one row per pair" invariant at the DB layer, same style as `user_skill_progress`. Index on `(user_id, next_review_at)` to serve `list_due`/`count_due` cheaply.
- **`exercises`** (existing, amended): adds nullable `vocab_item_id` (UUID, FK → `vocab_items.id`, nullable — not every exercise links to a vocab item, per requirements.md's Assumptions).
- **Migration shape**: purely additive (two new tables, one new nullable column) — unlike bolt 017's `amole_transactions` migration, this needs no `batch_alter_table` (no drop/constraint-narrowing on SQLite), just standard `op.create_table`/`op.add_column`. Seed-data backfill (linking existing seeded exercises to new `vocab_items` rows) is a Stage 4 concern once the real seed script (`004-lesson-content-service`'s seed data) is read.

### Security Design

- **Due-items/due-count endpoints**: scoped to the authenticated caller only (current-user dependency, same as every other per-user endpoint in this codebase) — user_id is never accepted as a request parameter, only derived from the auth token.
- **No new secrets/external calls**: purely internal DB-backed logic, no new attack surface beyond the existing auth boundary.

### NFR Implementation

- **Idempotent replay (composes with ADR-6)**: `complete_lesson`'s existing attempt_id-based idempotency guard (verified for real at Stage 4) must gate the new vocab-progress side effect exactly like it already gates Beans/XP/Amole — a replayed offline-sync completion for an already-processed `attempt_id` must not run `LeitnerBoxPolicy.apply` a second time. Design intent: piggyback on the existing guard rather than add a second one, to avoid two idempotency mechanisms drifting apart.
- **Due-count/due-items consistency (FR-4)**: both endpoints call into `UserVocabProgressRepository.count_due`/`list_due`, which share one underlying `WHERE user_id = ? AND next_review_at <= now()` predicate builder — implemented once, so the two numbers structurally cannot disagree.
- **Offline behavior (FR-5)**: Practice is disabled entirely offline (Inception decision, not revisited here) — due-items/due-count endpoints require live connectivity like any other non-cached endpoint; no local-cache/offline-compute design is needed for this unit, unlike `003-offline-caching-and-sync`'s lesson-pack caching.
- **Zero regression to non-vocab-linked exercises**: `vocab_item_id` is nullable on `exercises` and the new side effect only fires when a completed exercise resolves to a non-null `vocab_item_id` — exercises with no link are untouched by this bolt's logic.

### Story Coverage

- `001-vocab-item-content-model`: `vocab_items` table, `exercises.vocab_item_id`.
- `002-vocab-progress-retrofit`: `complete_lesson` extension, `user_vocab_progress` table, the open contract question.
- `003-leitner-box-algorithm`: `LeitnerBoxPolicy` invoked from the application layer.
- `004-due-items-and-count-endpoints`: the two new endpoints and the shared predicate.
