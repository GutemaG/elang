---
stage: implement
bolt: 001-auth-service
created: 2026-09-15T16:30:00Z
---

# Implementation Notes: Auth Service (Stage 4)

## Summary

Implemented the full FastAPI backend for `001-auth-service` at `backend/` in
this monorepo, covering all 3 stories (persist pending onboarding selections,
Google OAuth authentication, Sign in with Apple) behind the 3 endpoints
specified in `ddd-02-technical-design.md`: `POST /api/v1/auth/google`,
`POST /api/v1/auth/apple`, `GET /api/v1/auth/session`. The layered
domain/application/infrastructure structure from Stage 2 was followed
directly, and both ADRs (session token SHA-256 hashing; Apple JWT-over-JWKS
verification with no vendor SDK) were implemented as decided.

The project was scaffolded with `uv init` + `uv add` (uv is available and
confirmed as the Python package manager in `tech-stack.md`). An initial
Alembic migration creating `users` and `auth_sessions` was generated via
`alembic revision --autogenerate` and verified runnable against a fresh
SQLite database. `ruff check`, `ruff format`, and `mypy` were all run against
the full `app/` tree and pass with zero errors. A hand-written, throwaway
smoke-test script (not committed, not a pytest test file -- Stage 5 is a
separate later step) exercised all 3 endpoints end-to-end against SQLite
with fake token verifiers, covering: new-user creation with a pending
selection, returning-user sign-in with the selection ignored, session
validation (valid, unknown/expired, missing header), and the invalid-language
rejection path on both a new and a returning user. All checks passed.

## Structure Overview

```text
backend/
├── pyproject.toml            # uv-managed deps + ruff/mypy config
├── alembic.ini                # points at app/infrastructure/db/migrations
├── .env.example                # placeholder secrets only
├── app/
│   ├── main.py                  # FastAPI app, lifespan-managed verifier singletons
│   ├── config.py                 # pydantic-settings Settings, .env-driven
│   ├── domain/                    # pure Python, zero framework imports
│   ├── application/                # use cases + event logging
│   └── infrastructure/
│       ├── db/                      # SQLAlchemy models, repos, Alembic migrations
│       ├── external/                  # Google/Apple token verifiers
│       └── api/                        # routers, schemas, exception handler
```

## Completed Work

- `backend/pyproject.toml` -- uv-managed project manifest: FastAPI, SQLAlchemy[asyncio], aiosqlite, asyncpg, alembic, google-auth, requests, pyjwt, cryptography, pydantic, pydantic-settings, httpx, uvicorn; dev group: ruff, mypy; `[tool.ruff]`/`[tool.mypy]` config.
- `backend/uv.lock` -- resolved lockfile from `uv add`, committed for reproducible installs.
- `backend/.env.example` -- placeholder env vars (DB URL, Google client ID, Apple Services/Team/Key/Bundle IDs, JWKS URL/issuer, session TTL, JWKS cache TTL); no real secrets.
- `backend/.gitignore` -- excludes `.venv/`, `.env`, `*.db`, cache dirs.
- `backend/alembic.ini` -- Alembic config; `sqlalchemy.url` is a fallback only, overridden at runtime by `env.py` reading `DATABASE_URL`.
- `backend/app/main.py` -- FastAPI app factory; lifespan builds `GoogleTokenVerifier`/`AppleTokenVerifier` as long-lived `app.state` singletons; registers the router and exception handler; `/health` endpoint.
- `backend/app/config.py` -- `Settings` (pydantic-settings) loading `DATABASE_URL`, Google/Apple config, session TTL, JWKS cache TTL from `.env`/environment.
- `backend/app/domain/entities.py` -- `User`, `AuthSession` aggregate roots (dataclasses).
- `backend/app/domain/value_objects.py` -- `ProviderIdentity`, `LanguageCode`, `DailyGoalPreset`, `DailyXPTarget`, `PendingOnboardingSelection`, `SessionToken`, `AuthProvider`; the minutes-to-XP lookup table and no-pending-selection defaults.
- `backend/app/domain/events.py` -- `UserRegistered`, `UserAuthenticated`, `SessionIssued`, `AuthenticationRejected` dataclasses (payload shapes only; logged, not bussed).
- `backend/app/domain/exceptions.py` -- `AuthDomainError` base + `InvalidTokenError`, `ExpiredTokenError`, `InvalidPendingSelectionError`, `ProviderUnreachableError`, `MissingCredentialsError`, each carrying `error_code`.
- `backend/app/domain/repositories.py` -- `UserRepository`, `AuthSessionRepository` as `typing.Protocol`s.
- `backend/app/domain/services.py` -- `AuthenticationService` (shared verify-then-create-or-load-then-issue-session flow), `OnboardingAttachmentPolicy` (minutes-to-XP mapping + new-user defaults, validated only on the account-creation branch), `SessionValidationService`, `TokenVerifier` protocol.
- `backend/app/application/use_cases.py` -- `authenticate_with_google`, `authenticate_with_apple`, `validate_session`; `PendingSelectionInput` DTO; structured logging of the 4 domain events (ids/enums only, never tokens).
- `backend/app/infrastructure/db/models.py` -- `UserModel`, `AuthSessionModel` SQLAlchemy models mirroring `database-schema.md` exactly, including all constraints/indexes.
- `backend/app/infrastructure/db/session.py` -- async engine/session factory; `get_db_session` FastAPI dependency committing on success, rolling back on exception (the transaction boundary for "no partial writes").
- `backend/app/infrastructure/db/repositories.py` -- `SqlAlchemyUserRepository`, `SqlAlchemyAuthSessionRepository`; SHA-256 token hashing (ADR-1); UTC-normalization of datetimes read back from SQLite (see Deviations).
- `backend/app/infrastructure/db/migrations/env.py` -- async-engine Alembic environment wired to `app.config`/`app.infrastructure.db.models.Base.metadata`.
- `backend/app/infrastructure/db/migrations/versions/bc3acb0ae17a_create_users_and_auth_sessions_tables.py` -- initial migration creating `users` and `auth_sessions` with all constraints/indexes; verified runnable.
- `backend/app/infrastructure/external/google_verifier.py` -- `GoogleTokenVerifier` wrapping `google-auth`'s `verify_oauth2_token`, run off-thread; maps failures to `InvalidTokenError`/`ExpiredTokenError`/`ProviderUnreachableError`.
- `backend/app/infrastructure/external/apple_verifier.py` -- `AppleTokenVerifier`: raw JWT-over-JWKS via `PyJWT`+`cryptography` (ADR-2), in-memory JWKS cache with TTL, refetch-once on unknown `kid`.
- `backend/app/infrastructure/logging_config.py` -- structured logging setup; JSON in non-local envs, human-readable in dev; `SensitiveDataFilter` strips token-shaped fields defensively.
- `backend/app/infrastructure/api/schemas.py` -- Pydantic request/response models matching the technical design's API tables exactly.
- `backend/app/infrastructure/api/dependencies.py` -- FastAPI DI wiring: per-request repositories + app-level verifier singletons into the domain services.
- `backend/app/infrastructure/api/error_handlers.py` -- single exception handler mapping `AuthDomainError` subclasses to the error-code/HTTP-status table.
- `backend/app/infrastructure/api/routers.py` -- the 3 endpoints (`/auth/google`, `/auth/apple`, `/auth/session`); no business logic, only request/response mapping.

## Key Decisions

- **Pending-selection validation deferred until the account-creation branch is confirmed.** The domain model states a returning user's pending selection "has no effect whatsoever," which on inspection has to include skipping validation entirely, not just skipping the write. `AuthenticationService` therefore resolves new-vs-returning first (via `find_by_provider_identity`) and only constructs/validates the `PendingOnboardingSelection` value object inside `OnboardingAttachmentPolicy.resolve_selection_for_new_user`, called exclusively on the new-user branch. A malformed pending selection on a returning user's sign-in is silently ignored rather than rejected with 400 -- verified by the smoke test.
- **`AuthSessionRepository.find_by_token` takes the raw token value**, exactly as the domain model specifies, with SHA-256 hashing happening inside the SQLAlchemy repository implementation. This keeps ADR-1's hashing detail out of the domain layer entirely, matching the domain model's own note that storage representation is an infrastructure concern.
- **Google/Apple verifiers are app-level singletons on `app.state`**, built once in the FastAPI lifespan, not per-request. Both own long-lived resources (an HTTP client; for Apple, the in-memory JWKS cache) that must persist across requests for the caching design in `ddd-02-technical-design.md`'s Scalability NFR to mean anything.
- **DB transaction boundary lives in the `get_db_session` FastAPI dependency** (commit on success, rollback on any exception), not inside the repositories or domain service. This satisfies "no partial writes on failure" (an `InvalidPendingSelectionError` raised mid-flow rolls back any user-insert the session already flushed) without giving the domain layer any awareness of transactions.

## Deviations from Plan

- **SQLite does not round-trip timezone-aware datetimes** even through a `DateTime(timezone=True)` column -- values read back are naive, which broke `SessionToken.is_expired`'s comparison against `datetime.now(timezone.utc)` with a `TypeError` (caught by the smoke test, not anticipated in the design docs). Fixed with a `_ensure_utc` normalization helper in `app/infrastructure/db/repositories.py`, applied to every datetime read back from a model before constructing a domain object. This is purely an infrastructure-layer fix; the domain layer's assumption that all datetimes it handles are timezone-aware is preserved and never violated. PostgreSQL round-trips timezone info correctly, so this only matters for local dev/test, but the fix is unconditional (cheap, and correct either way).
- **`google-auth`'s `requests` transport needs the `requests` package explicitly** (not pulled in as a transitive dependency) -- added to `pyproject.toml`. Not mentioned in the design docs' External Dependencies table; a build-time discovery.
- Two of ADR-2's flagged "Stage 4 implementation-level details" were resolved here as build decisions, per the ADR's own deferral: session TTL defaults to 30 days (configurable via `SESSION_TTL_DAYS`), and the Apple JWKS routine-refresh TTL defaults to 1 hour (configurable), independent of the refetch-once-on-unknown-`kid` fallback which always takes precedence regardless of TTL freshness.

## Dependencies Added

Runtime: `fastapi`, `uvicorn[standard]`, `sqlalchemy[asyncio]`, `aiosqlite`, `asyncpg`, `alembic`, `google-auth`, `requests` (transitive requirement of `google-auth`'s HTTP transport, added explicitly), `pyjwt`, `cryptography`, `pydantic`, `pydantic-settings`, `python-dotenv`, `httpx`.
Dev: `ruff`, `mypy`.

## Verification Performed

- `uv run ruff check app` -- 0 errors (one project-level ignore added for `B008`, FastAPI's documented `Depends(...)`-as-default idiom).
- `uv run ruff format app --check` -- all files already formatted.
- `uv run mypy app` -- "Success: no issues found in 26 source files".
- `uv run alembic upgrade head` against a scratch SQLite DB -- created `users`/`auth_sessions` correctly; schema inspected and matches `database-schema.md`.
- Manual end-to-end smoke test (FastAPI `TestClient` + SQLite + fake token verifiers, not committed to the repo) -- all 8 scenarios passed: new-user creation with pending selection and correct XP mapping, returning-user sign-in with pending selection ignored (including a malformed one), session validation valid/invalid/missing-header, and invalid-language rejection on a new user with no account persisted.
- Real Google/Apple network calls were **not** exercised (no real OAuth client ID / Apple credentials available in this environment) -- `GoogleTokenVerifier`/`AppleTokenVerifier` were validated by code review against ADR-1/ADR-2 and by the smoke test's fake-verifier substitution at the `TokenVerifier` protocol boundary, not by hitting live provider endpoints.
