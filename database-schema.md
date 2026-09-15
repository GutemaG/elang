# Database Schema

> **Scope note**: This file defines only the tables that exist as of the `001-auth-service` bolt's Technical Design (`memory-bank/bolts/001-auth-service/ddd-02-technical-design.md`): `users` and `auth_sessions`. It is **not** a speculative full Phase-1 schema. Future intents (lesson content, gamification/XP/Beans/Amole, SRS, leagues, subscriptions, etc.) will each add their own tables here via their own Technical Design (Stage 2) stage, once those intents actually go through requirements and domain modeling — not before. `memory-bank/standards/data-stack.md` references this file and `database-erd.mermaid` as the eventual full picture; both grow incrementally, bolt by bolt.
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

**Explicitly not modeled here** (out of this bolt's scope, per `unit-brief.md` and the domain model): no `email` column (never used for dedup or stored, per Apple private-relay concerns — nothing in this bolt's flows requires persisting it), no role/permission column (single implicit student role in Phase 1), no XP ledger / streak / Beans / Amole columns (future `gamification-engine` intent's own tables).

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
