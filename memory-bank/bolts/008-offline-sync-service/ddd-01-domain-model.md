---
stage: model
bolt: 008-offline-sync-service
created: '2026-09-16T21:30:00Z'
---

## Static Model: 001-offline-sync-service

### Entities

- **LessonAttempt** (existing aggregate root from bolt 005, amended): `id`, `user_id`, `lesson_id`, `attempt_id` (client-generated idempotency key), `correct_count`, `total_count`, `beans_consumed`, `xp_awarded`, `server_received_at` (existing), **`client_completed_at`** (NEW — the offline-completion timestamp reported by the client). Business rules: completion is idempotent on `attempt_id` (ADR-5, unchanged); XP/Beans effects remain bounded by the account's real Beans balance at attempt start (ADR-5, unchanged); NEW — `client_completed_at` must pass `CompletionTimestampValidator` before the attempt is accepted, and streak/XP-day attribution uses its calendar day rather than `server_received_at`'s.

### Value Objects

- **CompletionTimestamp**: wraps the raw client-supplied timestamp for one completion. Constraints: must not be in the future beyond a small clock-skew allowance; must not predate the user's account creation date; exact numeric bounds are a Technical Design decision, not fixed here. Immutable; equality by value (same instant = same value object).
- **ContentVersion**: a version marker for one skill's or lesson's content. Constraints: changes if and only if the underlying content changed; stable and repeatable for unchanged content across repeated fetches. Immutable; equality by value.

### Aggregates

- **LessonAttempt** (existing, from bolt 005 — amended here): Members: `attempt_id`, `client_completed_at` (CompletionTimestamp), `correct_count`, `total_count`, beans/XP effects. Invariants: (existing) idempotent on `attempt_id`; (existing) beans/XP effects bounded by real account Beans balance; (NEW) `client_completed_at` must be validated before the attempt is persisted as completed — an attempt failing validation is rejected outright, not silently clamped.
- **Skill** / **Lesson content** (existing, from bolt 004 — amended here): Invariant addition: exposes a stable `ContentVersion` derived from its own last-modified state, with no new mutable state introduced to track it.
- **UserStreak** (existing, from bolt 005 — behavior amended, structure unchanged): Invariant addition: day attribution for a given `LessonAttempt` is keyed by that attempt's `CompletionTimestamp` calendar date, not by whatever moment the server happened to process the request.

### Domain Events

- **LessonAttemptCompleted**: Trigger: a completion request for a new `attempt_id` passes validation. Payload: `attempt_id`, `user_id`, `lesson_id`, `client_completed_at`, `correct_count`, `total_count`, `beans_delta`, `xp_awarded`.
- **LessonAttemptReplayed**: Trigger: a completion request arrives whose `attempt_id` already exists. Payload: `attempt_id`, the original (unchanged) result returned to the caller. Distinguishes "nothing new happened" from `LessonAttemptCompleted` for observability, without requiring separate storage.
- **LessonAttemptRejected**: Trigger: a completion request's `client_completed_at` fails `CompletionTimestampValidator`. Payload: `attempt_id`, rejection reason. No ledger effect occurs.

### Domain Services

- **CompletionTimestampValidator**: Operations: `validate(raw_timestamp, account_created_at, now) -> CompletionTimestamp | Rejected`. Dependencies: system clock, the user's account creation date (existing `users` row).
- **StreakAttributionService** (existing, from bolt 005 — amended): Operations: `attributeCompletionToDay(user_id, completion_timestamp: CompletionTimestamp)` — now takes an explicit `CompletionTimestamp` argument instead of implicitly using "now". Dependencies: `UserStreakRepository`.
- **ContentVersionResolver**: Operations: `versionFor(skill_id | lesson_id) -> ContentVersion`. Dependencies: existing Skill/Lesson repositories' last-modified metadata (exact source — a stored column vs. derived from `updated_at` — is a Technical Design decision).

### Repository Interfaces

- **LessonAttemptRepository** (existing, from bolt 005): Entity: `LessonAttempt` — Methods: (existing) `save`, (existing or to-confirm-in-design) `findByAttemptId(attempt_id) -> LessonAttempt | None`, used to short-circuit a replay before any ledger effect is recomputed.
- **UserStreakRepository** (existing, from bolt 005): Entity: `UserStreak` — Methods: unchanged; the caller now supplies an explicit date rather than relying on the repository to assume "today".
- **SkillRepository / LessonRepository** (existing, from bolt 004): Entity: `Skill` / `Lesson` — Methods: existing content-fetch methods, amended to also surface whatever metadata `ContentVersionResolver` needs (last-modified timestamp or equivalent).

### Ubiquitous Language

- **Offline completion**: A `LessonAttempt` whose `client_completed_at` differs meaningfully from the moment the server actually received the request.
- **Replay**: A completion request for an `attempt_id` already recorded; must be a no-op that returns the original result, never re-applying ledger effects.
- **Content version**: A signal derived from a skill/lesson's content state that a client compares against its cached copy to decide whether a re-download is needed.
- **Plausibility bound**: The validation rule limiting how far `client_completed_at` may diverge from reality (future clock skew, or predating the account) before a completion is rejected outright rather than trusted.
