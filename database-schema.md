# Database Schema

> **Scope note**: This file grows incrementally, bolt by bolt, as each intent goes through requirements and domain modeling. As of `001-auth-service`'s Technical Design (`memory-bank/bolts/001-auth-service/ddd-02-technical-design.md`) it defined `users` and `auth_sessions`. `004-lesson-content-service`'s Technical Design (`memory-bank/bolts/004-lesson-content-service/ddd-02-technical-design.md`) added `skills`, `lessons`, `exercises`, and `user_skill_progress`. `005-lesson-engagement-service`'s Technical Design (`memory-bank/bolts/005-lesson-engagement-service/ddd-02-technical-design.md`) adds `user_beans`, `user_streaks`, `lesson_attempts` below, plus a new column on `user_skill_progress`. It is **not** a speculative full Phase-1 schema. `memory-bank/standards/data-stack.md` references this file and `database-erd.mermaid` as the eventual full picture.
>
> **Engine**: PostgreSQL (real deployment target) / SQLite via `aiosqlite` (local dev + automated tests), same SQLAlchemy async models — types below are written Postgres-first with SQLite-compatibility notes where they diverge, per `memory-bank/standards/data-stack.md`.

---

## `users`

Backs the `User` aggregate (`memory-bank/bolts/001-auth-service/ddd-01-domain-model.md`). One row per Buna account, created on first successful sign-in via either provider.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY`, generated server-side (`uuid4`) | Surrogate key. Never the dedup key. |
| `auth_provider` | `VARCHAR(16)` | `NOT NULL`, `CHECK (auth_provider IN ('google', 'apple'))` | Part of `ProviderIdentity` VO. |
| `provider_user_id` | `VARCHAR(255)` | `NOT NULL` | Provider's stable subject identifier (Google `sub`, Apple stable user identifier). Never email. Part of `ProviderIdentity` VO. |
| `selected_language` | `VARCHAR(8)` | `NOT NULL` | ISO-639-1-style code, e.g. `am`. Set exactly once at creation — never updated by this bolt's logic. |
| `daily_xp_target` | `INTEGER` | `NOT NULL`, `CHECK (daily_xp_target > 0)` | Derived from `DailyGoalPreset` at creation via the minutes→XP mapping (see Technical Design). Set exactly once. |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite, UTC assumed) | `NOT NULL`, `DEFAULT now()` | Account creation time. |

**Constraints**:
- `UNIQUE (auth_provider, provider_user_id)` — enforces the `ProviderIdentity` aggregate invariant: identity is unique per provider identity, never per email. This is the sole account-dedup mechanism.

**Indexes**:
- Implicit unique index from the `UNIQUE (auth_provider, provider_user_id)` constraint above — this is also the primary lookup path for `UserRepository.find_by_provider_identity(...)`, so no separate index is needed.
- Primary key index on `id` (for `UserRepository.get_by_id(...)`).

**Explicitly not modeled here** (out of this bolt's scope, per `unit-brief.md` and the domain model): no `email` column (never used for dedup or stored, per Apple private-relay concerns — nothing in this bolt's flows requires persisting it), no role/permission column (single implicit student role in Phase 1). XP/streak/Beans/Amole state lives in `005-lesson-engagement-service`'s own tables below (`user_beans`, `user_streaks`, `lesson_attempts`), not on this table — `requirements.md`'s Constraints section explicitly has this intent (not a hypothetical future `gamification-engine` intent) own those tables.

---

## `auth_sessions`

Backs the `AuthSession` aggregate. One row per issued session token; a `users` row may have multiple concurrent `auth_sessions` rows (multi-device sign-in).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY`, generated server-side (`uuid4`) | Surrogate key. |
| `user_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `NOT NULL`, `FOREIGN KEY REFERENCES users(id)` | Plain reference, not an eager-loaded relationship — keeps session validation independent of the `User` aggregate's transactional boundary, per the domain model. |
| `token_hash` | `VARCHAR(64)` | `NOT NULL` | `SHA-256` hex digest of the opaque session token value. The raw token is never persisted — see Technical Design's Security Design section. |
| `issued_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite, UTC assumed) | `NOT NULL`, `DEFAULT now()` | |
| `expires_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite, UTC assumed) | `NOT NULL` | Session lifetime is an implementation-level constant set at Stage 4, not fixed here. |

**Constraints**:
- `UNIQUE (token_hash)` — enforces the `SessionToken` aggregate invariant: `token.value` (and therefore its hash) is globally unique.

**Indexes**:
- Implicit unique index from `UNIQUE (token_hash)` — this is the lookup path for `AuthSessionRepository.find_by_token(...)` (`SessionValidationService` hashes the incoming token, then looks up by this index).
- Index on `user_id` — supports future multi-session-per-user queries (e.g. "list my active sessions"), not required by any of this bolt's three stories today but cheap to add alongside the foreign key.
- Primary key index on `id` (for `AuthSessionRepository.get_by_id(...)`).

**Explicitly not modeled here**: no `revoked_at`/soft-delete column and no `revoke`/`delete` repository method — no logout story exists yet in this bolt's scope (per the domain model's explicit note); add both only when a future story requires session revocation.

---

## `skills`

Backs the `Skill` aggregate (`memory-bank/bolts/004-lesson-content-service/ddd-01-domain-model.md`). One row per skill-tree node (content, not per-user state).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY` | Deterministic (`uuid5(CONTENT_NAMESPACE, slug)`) for seeded content — not `uuid4` — so the seed script is idempotent by construction (ADR-3/Decision 3 in the technical design). |
| `title` | `VARCHAR(255)` | `NOT NULL` | Skill-tree node display title, e.g. "Greetings & Basics". |
| `order_index` | `INTEGER` | `NOT NULL`, unique | Position in the (currently single, linear) skill tree; lowest = first. Named `order_index`, not `order`, to avoid the SQL reserved word. |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite, UTC assumed) | `NOT NULL`, `DEFAULT now()` | |

**Constraints**: `UNIQUE (order_index)` — enforces the `Skill` aggregate's invariant that `order_index` is globally unique.

**Indexes**: Primary key index on `id`; implicit unique index from `UNIQUE (order_index)`.

---

## `lessons`

Backs the `Lesson` aggregate. One row per lesson, always loaded together with its full ordered `exercises` (see below) — never a valid partial fetch.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY` | Deterministic, same scheme as `skills.id`. |
| `skill_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `NOT NULL`, `FOREIGN KEY REFERENCES skills(id)` | Owning skill. |
| `title` | `VARCHAR(255)` | `NOT NULL` | |
| `order_index` | `INTEGER` | `NOT NULL` | Position within `skill_id`. |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL`, `DEFAULT now()` | |

**Constraints**: `UNIQUE (skill_id, order_index)`.

**Indexes**: Primary key index on `id`; `ix_lessons_skill_id` on `skill_id` (supports `LessonRepository`'s implicit skill-scoped lookups and the unique constraint above).

---

## `exercises`

Backs the `Exercise` entity (member of the `Lesson` aggregate, not its own aggregate root). Single polymorphic table for all 3 exercise types — see ADR-3 (`memory-bank/bolts/004-lesson-content-service/adr-3-polymorphic-exercises-table.md`) for why per-type tables were rejected.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY` | Deterministic, same scheme as `skills.id`. |
| `lesson_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `NOT NULL`, `FOREIGN KEY REFERENCES lessons(id)` | |
| `order_index` | `INTEGER` | `NOT NULL` | Position within `lesson_id`. |
| `type` | `VARCHAR(32)` | `NOT NULL`, `CHECK (type IN ('multiple_choice', 'listening', 'sentence_construction'))` | Discriminator; the 3 types fixed by `requirements.md` FR-2. |
| `prompt` | `TEXT` | `NOT NULL` | The instruction/phrase-to-translate shown to the learner. |
| `content` | `JSON` | `NOT NULL` | Type-specific **renderable** data (`choices`, `word_bank`, `audio_url`) — this, and only this, is what the lesson-content API response serializes. |
| `answer_key` | `JSON` | `NOT NULL` | Type-specific **correct-answer** data (`correct_choice_id` or `correct_sequence`). Originally never serialized to an API response (ADR-4); **as of `005-lesson-engagement-service`, it is included in the lesson-content response** (ADR-5, `memory-bank/bolts/005-lesson-engagement-service/adr-5-client-side-grading-with-bounded-server-ledger.md`, which supersedes ADR-4) — grading moved client-side to satisfy the "no network call per exercise" NFR; the account ledger stays server-bounded instead (see ADR-5). |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL`, `DEFAULT now()` | |

**Constraints**: `UNIQUE (lesson_id, order_index)`; `CHECK` on `type`.

**Indexes**: Primary key index on `id`; `ix_exercises_lesson_id` on `lesson_id` (the sole query pattern this bolt needs: `WHERE lesson_id = ? ORDER BY order_index`).

**JSON column note**: `sqlalchemy.JSON` (not Postgres-only `JSONB`) is used deliberately — nothing in this bolt (or bolt `005`'s future answer-key lookup) queries *inside* `content`/`answer_key`; both are always read out whole by primary key or `lesson_id`, so this sidesteps `data-stack.md`'s documented SQLite/Postgres JSON-operator gap entirely.

---

## `user_skill_progress`

Backs the `UserSkillProgress` aggregate. Per-user, per-skill progress state. Read-only as of `004-lesson-content-service`; **`005-lesson-engagement-service` is its first writer** — a user with zero rows is still a fully valid, expected state (new-user bootstrap, computed on the fly by `SkillTreeProgressionPolicy`).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY`, generated server-side (`uuid4`) | Runtime-created row (unlike seeded content above), so a random surrogate key, same convention as `users`/`auth_sessions`. |
| `user_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `NOT NULL`, `FOREIGN KEY REFERENCES users(id)` | Plain reference, not an eager-loaded relationship — same independence pattern as `auth_sessions.user_id` relative to `User`. |
| `skill_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `NOT NULL`, `FOREIGN KEY REFERENCES skills(id)` | |
| `unlocked` | `BOOLEAN` | `NOT NULL`, `DEFAULT true` | A row's mere existence already implies unlocked; this column exists for forward-compatibility (e.g. a future soft-lock without deleting the row) but is not exercised by any read path in this bolt beyond being trivially `true`. |
| `crown_level` | `INTEGER` | `NOT NULL`, `DEFAULT 0`, `CHECK (crown_level >= 0 AND crown_level <= 5)` | `0` = not yet completed; `1-5` per FR-6, only meaningful once `completed_at IS NOT NULL`. |
| `completed_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NULLABLE` | `NULL` = unlocked but not yet completed (state = active); set = completed at least once (state = completed). |
| `completed_lesson_ids_this_cycle` | `JSON` | `NOT NULL`, `DEFAULT '[]'` | **Added by `005-lesson-engagement-service`.** Lesson ids (within this skill) completed since the last crown-level milestone — FR-6's "replay every lesson again to raise the crown level" tracking. Resets to `[]` each time it grows to cover every lesson in the skill. |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL`, `DEFAULT now()` | |

**Constraints**: `UNIQUE (user_id, skill_id)` — at most one progress row per user per skill; `CHECK` on `crown_level` range.

**Indexes**: Primary key index on `id`; `ix_user_skill_progress_user_id` on `user_id` (the lookup path for `UserSkillProgressRepository.list_by_user(...)`, used to compute a user's whole skill tree in one query).

---

## `user_beans`

Backs the `UserBeans` aggregate (`memory-bank/bolts/005-lesson-engagement-service/ddd-01-domain-model.md`). Per-user Beans + Amole wallet. One row per user, created lazily on first write (a refill or a lesson completion that consumes a bean) — a user with no row is a valid default state (full beans, `STARTING_AMOLE_BALANCE` Amole, no regen owed).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY`, `FOREIGN KEY REFERENCES users(id)` | One row per user — the user id is the primary key directly, no separate surrogate key needed (same pattern choice as a 1:1 wallet, not a 1:many history table). |
| `current_count` | `INTEGER` | `NOT NULL`, `CHECK (current_count >= 0)` | Regenerated lazily on every read/write from `last_regen_at`, never a scheduled job (Technical Design's `BeanLedger`). Capped at `BEANS_MAX = 5`, enforced in application logic, not a DB constraint (the max is a tunable constant, not a schema invariant). |
| `last_regen_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL` | Advances only by whole regen intervals actually consumed, so partial progress toward the next bean isn't lost between reads. |
| `amole_balance` | `INTEGER` | `NOT NULL`, `CHECK (amole_balance >= 0)` | The minimal beans-refill currency `requirements.md` explicitly scopes in (no full gem economy/IAP). |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL`, `DEFAULT now()` | |

**Indexes**: Primary key index on `user_id` (the sole lookup path).

---

## `user_streaks`

Backs the `UserStreak` aggregate. Per-user daily-streak state. One row per user, created lazily on first lesson completion — a user with no row has streak 0, no freeze.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `PRIMARY KEY`, `FOREIGN KEY REFERENCES users(id)` | Same 1:1-wallet pattern choice as `user_beans`. |
| `current_streak` | `INTEGER` | `NOT NULL`, `DEFAULT 0`, `CHECK (current_streak >= 0)` | Increments at most once per UTC calendar day (Technical Design Decision 5 — no per-user timezone tracking). |
| `last_completed_date` | `DATE` | `NULLABLE` | `NULL` only before the account's first-ever completion. UTC calendar date, not a timestamp — day-boundary comparisons (`StreakPolicy`) are date arithmetic, not datetime arithmetic. |
| `active_freeze_count` | `INTEGER` | `NOT NULL`, `DEFAULT 0`, `CHECK (active_freeze_count >= 0)` | Consumed one-at-a-time to protect exactly one missed calendar day. Granted automatically whenever any skill's crown level first reaches 5 (Technical Design Decision 3 — mirrors the already-built `FakeLessonApi`'s documented mechanic). |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL`, `DEFAULT now()` | |

**Indexes**: Primary key index on `user_id`.

---

## `lesson_attempts`

Backs the `LessonAttempt` aggregate. One row per genuinely completed lesson attempt — the idempotency record for story 003's "exactly once" XP-award requirement, and the source of truth for the skill-tree HUD's lifetime/daily XP totals.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | **Client-supplied, never server-generated** — this is the idempotency key (ADR-5, Decision 2). `LessonController` (Flutter) generates it once per lesson attempt and echoes it on every completion retry. |
| `user_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `NOT NULL`, `FOREIGN KEY REFERENCES users(id)` | |
| `lesson_id` | `UUID` (Postgres) / `TEXT` (SQLite) | `NOT NULL`, `FOREIGN KEY REFERENCES lessons(id)` | |
| `correct_count` | `INTEGER` | `NOT NULL` | Client-reported (trusted, but bounded by beans availability at completion time — ADR-5, Decision 1). |
| `total_count` | `INTEGER` | `NOT NULL` | Must equal the lesson's actual exercise count (validated at completion; rejected otherwise). |
| `xp_awarded` | `INTEGER` | `NOT NULL`, `CHECK (correct_count >= 0 AND correct_count <= total_count)` | A real, queryable column (not buried in `result`) so lifetime/daily XP sums are plain `SUM(...)` queries — no cross-DB JSON-operator dependency (`data-stack.md`). |
| `completed_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL` | |
| `result` | `JSON` | `NOT NULL` | The rest of `LessonCompletionOutcome` (skill-unlock title, crown level, streak fields, accuracy) — replayed verbatim on an idempotent retry rather than recomputed, so a repeat `complete` call for the same `id` sees exactly what was true at that original completion. |
| `created_at` | `TIMESTAMPTZ` (Postgres) / `TIMESTAMP` (SQLite) | `NOT NULL`, `DEFAULT now()` | |

**Indexes**: Primary key index on `id`; `ix_lesson_attempts_user_completed` on `(user_id, completed_at)` — supports both the lifetime-XP sum and the `[start, end)` UTC-day-range sum for `daily_xp_total`, without a dialect-specific `date()`/`DATE_TRUNC` function.
