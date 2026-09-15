# Data Stack

## Overview
Relational data (users, content, progress, ledgers) lives in PostgreSQL; Redis backs the live leaderboard (sorted sets, Phase 2) and serves as the Celery broker/result backend from Phase 1 onward.

## Database
- **PostgreSQL** — primary store. Full schema and 7 core flows (signup, lesson session, SRS query, streak job, league rotation, subscription entitlement, content review) are defined separately in `database-schema.md` / `database-erd.mermaid` — this standard doesn't duplicate them, just records the choice and rationale.
- **Redis (sorted sets)** — cache + future live leaderboard; also the Celery broker for streak checks, league rotation, and notification jobs.

Postgres was chosen (implicitly, by the schema design) over a document store because the domain is heavily relational: users → progress → ledgers (XP/Amole as append-only transaction tables) → content hierarchy (courses → units → lessons → exercises → vocab_items). Ledger tables in particular need transactional integrity that a relational DB gives for free.

## ORM / Database Client
Confirmed for a FastAPI + PostgreSQL stack:
- **SQLAlchemy (async)** for the ORM/query layer
- **Alembic** for migrations

This is the de facto standard pairing with FastAPI, has first-class async support (matching FastAPI's async request handlers), and gives explicit control over the append-only ledger tables (`xp_transactions`, `amole_transactions`) where raw SQL-like control over inserts matters.

## Local Development & Testing
- **SQLite** (via `aiosqlite`) — used as the database backend for local development and automated tests during Construction, swapped in through the same SQLAlchemy async engine interface (no code changes, just a different connection string/fixture).
- **PostgreSQL** remains the target for any real deployment (staging/production) — this is a dev-speed convenience, not a change to the production data stack decision above.
- **Known gaps to watch**: SQLite lacks some Postgres features the schema may eventually lean on (native JSON operators, certain constraint types, true concurrent writers). If a story's tests depend on Postgres-specific behavior, run those against a real Postgres instance (e.g. via a docker-compose service) instead of SQLite.

## Decision Relationships
- Redis is provisioned early even though the leaderboard itself is Phase 2, because Celery (streak checks, notifications) needs a broker from day one.
- The append-only ledger pattern (`xp_transactions`, `amole_transactions`) is a Postgres-native fit — SQLAlchemy's session/transaction model maps directly onto "insert a row, never mutate."
- SRS due-item queries (`user_vocab_progress.next_review_at`) are a straightforward indexed range query in Postgres — no need for a separate time-series store at this scale.
