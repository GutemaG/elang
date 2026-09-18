---
stage: model
bolt: 019-srs-tracking-service
created: '2026-09-17T21:00:00Z'
---

## Static Model: srs-tracking-service

### Entities

- **VocabItem** (new): `id`, `word` (target-language text), `translation`, `created_at`. Content only — no per-user state, no per-user awareness, same category as `Skill`/`Lesson` (`004-lesson-content-service`).
- **UserVocabProgress** (new): `user_id`, `vocab_item_id`, `box_level` (1-5), `next_review_at`, `last_seen_at`. Business rules: `1 <= box_level <= 5`; at most one row per `(user_id, vocab_item_id)`; a user with no row for a given item has never seen it graded yet (no default state needed — the row is created on first appearance, per story `002`).
- **Exercise** (existing, extended): gains an optional `vocab_item_id` — not every exercise necessarily links to exactly one vocab item (per requirements.md's Assumptions), so this is nullable, not required.

### Value Objects

- **LeitnerBoxIntervals**: the fixed mapping `{1: 1 day, 2: 3 days, 3: 7 days, 4: 14 days, 5: 30 days}` — named constants, same pattern as `REFILL_COST_AMOLE`/`AMOLE_*` tuning constants, not a runtime-configurable table.
- **IncorrectResetInterval**: a fixed 1-day offset for an incorrect answer's `next_review_at`, stated as its own constant rather than reusing box 1's interval value — per story `003`'s explicit note, so a future change to box 1's interval can't silently change "how soon does a wrong answer resurface."

### Aggregates

- **VocabItem** (aggregate root, trivial — content only, no invariants beyond its own fields, same shape as `Skill`).
- **UserVocabProgress** (aggregate root): invariant `1 <= box_level <= 5`; at most one row per `(user_id, vocab_item_id)` — same "one row per user per X" wallet-like shape as `UserSkillProgress`/`UserBeans`, **not** an append-only ledger (ADR-8's reasoning: single writer per update, no audit-trail requirement, so a mutable row is the right call here, unlike Amole).

### Domain Events

- **VocabItemAnswered**: Trigger: `complete_lesson` processes a vocab-linked exercise within a completed lesson. Payload: `user_id`, `vocab_item_id`, `was_correct`. Not a literal event class in this codebase's style (no existing domain service publishes discrete event objects — `LessonCompletionOutcome`-style return values are the actual convention) but documented here as the conceptual trigger the Leitner transition responds to.

### Domain Services

- **LeitnerBoxPolicy** (new, pure — no repository/DB dependency, learned from bolt `017`'s Stage-4 correction that domain services in this codebase never hold I/O dependencies): Operations: `apply(current_box_level, was_correct, now) -> (new_box_level, next_review_at)`. Correct: `new_box_level = min(5, current_box_level + 1)`, `next_review_at = now + LeitnerBoxIntervals[new_box_level]`. Incorrect: `new_box_level = 1`, `next_review_at = now + IncorrectResetInterval`. Mirrors `StreakPolicy`'s/`BeanLedger`'s shape: takes plain values, returns plain values, no aggregate-loading responsibility.

### Repository Interfaces

- **VocabItemRepository**: Entity: `VocabItem`. Methods: `get_by_id(vocab_item_id) -> VocabItem | None` (content lookup for due-item resolution).
- **UserVocabProgressRepository**: Entity: `UserVocabProgress`. Methods: `get(user_id, vocab_item_id) -> UserVocabProgress | None`, `upsert(progress) -> None` (fetch-then-insert-or-update, same convention as `SqlAlchemyUserSkillProgressRepository.upsert`), `list_due(user_id, now, limit) -> list[UserVocabProgress]` (`WHERE user_id = ? AND next_review_at <= now ORDER BY next_review_at LIMIT ?`), `count_due(user_id, now) -> int` (same predicate, no `LIMIT`, sharing one underlying query builder so the two can't drift apart per FR-4).
- **Amendment to `ExerciseRepository`** (existing, `001-lesson-service`): needs a way to resolve "which exercise(s) test this vocab item" for due-item session assembly (story `004`'s "each with enough data to resolve their linked exercise(s)") — exact method shape (e.g. `list_by_vocab_item_id`) is a Technical Design decision once the real `ExerciseRepository`/`LessonRepository` interfaces are read at Stage 4, not fixed here.

### Ubiquitous Language

- **Vocab item**: a canonical word/phrase, content only, independent of any single exercise.
- **Box level**: 1-5, the Leitner spacing bucket a user's progress on one vocab item currently sits in.
- **Next review at**: the timestamp after which an item becomes due again.
- **Due**: `next_review_at <= now`.
- **First appearance**: a vocab-linked exercise the user has never been graded on before — creates a `UserVocabProgress` row at box 1 (not "box 0" — there is no box 0; first appearance and "just reset by a wrong answer" are the same starting state).

### Open Question Carried to Technical Design (flagged, not resolved here)

Per ADR-5, the server currently receives only aggregate `correct_count`/`total_count` from a lesson completion, not per-exercise detail — meaning `complete_lesson`'s request likely does **not** currently carry enough information to know which specific vocab-linked exercises were answered correctly vs. incorrectly. This may require widening the completion request contract (a real, if small, API change) rather than being a pure server-side addition. Read `CompleteLessonRequest`'s actual current shape and the Flutter `LessonController`'s actual current completion call at Stage 4 before assuming either way — do not design around a guess.

### Story Coverage

- `001-vocab-item-content-model`: `VocabItem`, `Exercise`'s new `vocab_item_id`.
- `002-vocab-progress-retrofit`: `UserVocabProgress`, the `VocabItemAnswered` trigger, the open question above.
- `003-leitner-box-algorithm`: `LeitnerBoxPolicy`, `LeitnerBoxIntervals`, `IncorrectResetInterval`.
- `004-due-items-and-count-endpoints`: `UserVocabProgressRepository.list_due`/`count_due`, the `ExerciseRepository` amendment.
