---
unit: 001-auth-service
bolt: 001-auth-service
stage: design
status: complete
created: 2026-09-15T13:20:00Z
---

# Technical Design - Auth Service

## Architecture Pattern

**Layered/Clean Architecture (domain-driven), single FastAPI service** — matching `coding-standards.md`'s prescribed backend layout (`app/domain/`, `app/application/`, `app/infrastructure/`, `app/main.py`) and the DDD construction-bolt workflow already used for Stage 1.

Rationale:
- The domain model (Stage 1) already has explicit aggregates (`User`, `AuthSession`), value objects, and domain services (`AuthenticationService`, `OnboardingAttachmentPolicy`, `SessionValidationService`) with repository interfaces — a layered architecture is the natural translation, with each layer's dependency direction pointing inward toward the domain (domain has zero framework/DB imports).
- No CQRS, event sourcing, or microservice split is warranted at this scale (3 stories, 2 aggregates, low initial volume per `unit-brief.md`) — a single service module is sufficient and matches `tech-stack.md`'s single FastAPI backend.
- Domain events (`UserRegistered`, `UserAuthenticated`, `SessionIssued`, `AuthenticationRejected`) are modeled but **not** wired to a message bus/event store in this bolt — Phase 1 has no consumer for them yet (the future `gamification-engine` intent is the first plausible subscriber). They are implemented as structured log entries (see NFR Implementation) with the shape reserved for a real event bus later. This keeps the domain model's event vocabulary intact without building speculative infrastructure.

## Layer Structure

```text
┌─────────────────────────────────────────────┐
│      Presentation (app/infrastructure/api)   │  FastAPI routers: /auth/google,
│                                               │  /auth/apple, /auth/session
├───────────────────────────────────────────────┤
│      Application (app/application)           │  Use cases: AuthenticateWithGoogle,
│                                               │  AuthenticateWithApple, ValidateSession
├───────────────────────────────────────────────┤
│        Domain (app/domain)                   │  User, AuthSession aggregates;
│                                               │  AuthenticationService,
│                                               │  OnboardingAttachmentPolicy,
│                                               │  SessionValidationService;
│                                               │  repository interfaces (Protocols)
├───────────────────────────────────────────────┤
│     Infrastructure (app/infrastructure)       │  SQLAlchemy models + repository impls
│                                               │  (db/), GoogleTokenVerifier /
│                                               │  AppleTokenVerifier (external/)
└─────────────────────────────────────────────┘
```

- **Presentation** (`app/infrastructure/api/`): FastAPI routers only. Parses/validates the HTTP request into a DTO, calls the relevant application use case, maps the result/domain exception to an HTTP response. No business logic.
- **Application** (`app/application/`): One use case per operation (`authenticate_with_google`, `authenticate_with_apple`, `validate_session`). Orchestrates domain services + repositories inside a single DB transaction; translates domain results into DTOs for the presentation layer. No direct SQLAlchemy or HTTP imports.
- **Domain** (`app/domain/`): Pure Python — `User`, `AuthSession` entities; `ProviderIdentity`, `LanguageCode`, `DailyGoalPreset`, `DailyXPTarget`, `PendingOnboardingSelection`, `SessionToken` value objects; `AuthenticationService`, `OnboardingAttachmentPolicy`, `SessionValidationService`; repository interfaces as `typing.Protocol`s. Zero dependencies on FastAPI, SQLAlchemy, or provider SDKs.
- **Infrastructure** (`app/infrastructure/`): `db/` — SQLAlchemy async models (`UserModel`, `AuthSessionModel`), Alembic migrations, `SqlAlchemyUserRepository`/`SqlAlchemyAuthSessionRepository` implementing the domain's repository Protocols. `external/` — `GoogleTokenVerifier` (wraps `google-auth`), `AppleTokenVerifier` (JWT verification against Apple's JWKS endpoint). `api/` — FastAPI routers + Pydantic request/response schemas.

## API Design

Base path: `/api/v1/auth`. All endpoints are unauthenticated except session validation, which authenticates *by* the session token itself (no separate bearer scheme layered on top).

| Endpoint | Method | Request | Response | Status |
|----------|--------|---------|----------|--------|
| `/api/v1/auth/google` | POST | `{ "id_token": string, "pending_selection"?: { "language": string, "daily_goal_minutes": 5\|10\|15\|20 } }` | `{ "session_token": string, "expires_at": string(ISO8601), "user": { "id": string, "selected_language": string, "daily_xp_target": int, "is_new_user": bool } }` | 200 (success), 400, 401, 502 |
| `/api/v1/auth/apple` | POST | `{ "identity_token": string, "pending_selection"?: { "language": string, "daily_goal_minutes": 5\|10\|15\|20 } }` | Same shape as `/auth/google` | 200 (success), 400, 401, 502 |
| `/api/v1/auth/session` | GET | Header: `Authorization: Bearer {session_token}` | `{ "valid": true, "user": { "id": string, "selected_language": string, "daily_xp_target": int } }` on valid; `{ "valid": false }` on invalid | 200 (valid or invalid — see Error Handling), 401 |

Notes:
- `is_new_user` in the auth response lets the client distinguish "onboarding selections were actually applied" (new account) from "your local pending selection was ignored" (returning user) without a separate lookup — directly supports story 001's AC3 being observable by the client.
- Session validation returns `200 { "valid": false }` for an expired/unknown token rather than a 401, because "invalid session" is an expected, non-error outcome for the app-restart flow (client should re-auth, not treat it as a server error). A malformed/missing `Authorization` header is a 401 (request-shape error, not a domain outcome).
- No logout/revoke endpoint — matches the domain model's explicit note that `AuthSessionRepository` has no `revoke`/`delete` method in this bolt (no story requires it).

### Error Codes (map directly to `AuthenticationRejected.reason`)

| `error_code` | HTTP Status | Meaning |
|---|---|---|
| `invalid_token` | 401 | Token failed cryptographic/signature/issuer verification, or is tampered |
| `expired_token` | 401 | Token is well-formed but past its expiry |
| `invalid_pending_selection` | 400 | `pending_selection.language` is not a supported `LanguageCode` |
| `provider_unreachable` | 502 | Google/Apple verification endpoint could not be reached — retryable, distinct from `invalid_token` per stories 002/003's edge cases |

Error response body: `{ "error_code": "invalid_token", "message": "..." }` per `coding-standards.md`'s structured error convention. No `user_id`, token contents, or claim contents are ever included, matching the domain model's `AuthenticationRejected` payload rule.

## Data Model

Two tables. Full column definitions live in `database-schema.md` at the repo root (single source of truth) — this section summarizes the mapping from Stage 1's aggregates.

| Table | Columns (summary) | Relationships |
|-------|---------|---------------|
| `users` | `id`, `auth_provider`, `provider_user_id`, `selected_language`, `daily_xp_target`, `created_at` | One `users` row ↔ one `User` aggregate. Unique constraint on `(auth_provider, provider_user_id)` enforces the `ProviderIdentity` dedup invariant. |
| `auth_sessions` | `id`, `user_id`, `token_hash`, `issued_at`, `expires_at` | Many `auth_sessions` rows per `users` row (multi-device sign-in, per story 002's edge case). `user_id` is a plain foreign key reference, not an eager-loaded relationship, matching the `AuthSession` aggregate's deliberate independence from `User`'s transactional boundary. |

`ProviderIdentity`, `LanguageCode`, `DailyXPTarget`, and `SessionToken` are value objects with no table of their own — they map to columns on `users`/`auth_sessions` (see `database-schema.md`).

## Security Design

| Concern | Approach |
|---------|----------|
| Authentication (Google) | Verify `id_token` server-side using the official `google-auth` Python package (`google.oauth2.id_token.verify_oauth2_token`), checking signature, issuer (`accounts.google.com` / `https://accounts.google.com`), audience (our OAuth client ID), and expiry. The verified `sub` claim becomes `provider_user_id`. Never trust a client-asserted user ID. |
| Authentication (Apple) | Verify `identity_token` (a JWT) against Apple's published JWKS (`https://appleid.apple.com/auth/keys`), checking signature, issuer (`https://appleid.apple.com`), audience (our app's bundle ID / Services ID), and expiry, using `PyJWT` with `cryptography` for RS256 verification (fetch + cache Apple's JWKS; standard JWT-over-JWKS approach, no Apple-specific SDK required). The verified `sub` claim becomes `provider_user_id`. |
| Authorization | None beyond authentication in Phase 1 — single student role, no permission tiers (per domain model: "a `User` is always student-role"). Session validation is the only authorization check: does this token map to a live, unexpired session. |
| Session token secrecy | `SessionToken.value` is a cryptographically random opaque string (`secrets.token_urlsafe(32)`, ~256 bits of entropy) generated server-side at issuance — never derived from provider claims. Never logged (enforced via a logging filter, see NFR Implementation), never included in `AuthenticationRejected` or any event payload. |
| Session token storage at rest | Stored **hashed**, not plaintext — `auth_sessions.token_hash` holds `SHA-256(token_value)`. The raw token is returned to the client exactly once (in the auth/session-validation response) and never persisted in recoverable form. Session validation hashes the incoming token and looks up by `token_hash` (equality lookup on a hash is safe here — the token has high entropy and isn't a low-entropy secret like a password, so a fast hash is sufficient and preserves indexed lookup performance; no bcrypt/argon2 needed). This resolves the domain model's deferred "storage representation" open item. |
| Data encryption | Postgres at-rest encryption via the hosting platform's standard volume encryption (deployment-level, not application-level — no additional app-layer field encryption needed for Phase 1's data: no raw tokens, no passwords, no payment data in this bolt's tables). Transport is HTTPS-only (enforced at the ingress/load-balancer level, not in this bolt's scope). |
| PII/token logging | Structured `logging` per `coding-standards.md`: a logging filter/formatter strips `id_token`, `identity_token`, `session_token`, and `token_hash` fields from any log record before it's emitted, defense-in-depth alongside the discipline of never passing them to `logger.info(...)` calls in the first place. |

## NFR Implementation

| Requirement | Design Approach |
|-------------|-----------------|
| Performance | Both auth endpoints make exactly one outbound call (to Google's token-info verification or Apple's JWKS, the latter cached in-memory with standard `kid`-based rotation handling) plus one DB round trip (find-or-create) inside a single transaction. Session validation is a single indexed lookup on `auth_sessions.token_hash` (unique index) — no `User` load unless the session is valid, matching the domain model's `SessionValidationService` ordering. |
| Scalability | Stateless FastAPI handlers (async, per `tech-stack.md`) — horizontal scaling is just adding instances behind the load balancer; no in-process session state. Apple's JWKS cache is process-local with a TTL matching Apple's key-rotation cadence, so it scales per-instance without a shared cache dependency for this bolt (Redis is provisioned per `data-stack.md` but not required by this bolt specifically). |
| Reliability | `provider_unreachable` is a distinct, retryable error code (502) from `invalid_token` (401) per stories 002/003's edge cases, so the client can distinguish "try again" from "sign in again." Account creation + onboarding-selection attachment happen in one DB transaction (per `coding-standards.md`'s "no partial writes on failure" rule) — a failure partway through (e.g. selection validation fails) rolls back the whole `users` insert, never leaving a malformed account (per story 001's edge case). |
| Testability | Local dev/test runs against SQLite via `aiosqlite` (per `data-stack.md`), same SQLAlchemy async engine as production Postgres — repository implementations use only SQL constructs valid on both (no Postgres-only JSON operators needed by these two tables). `GoogleTokenVerifier`/`AppleTokenVerifier` are behind the domain's dependency interfaces so tests substitute fakes without hitting real provider endpoints. |
| Observability | Domain events (`UserRegistered`, `UserAuthenticated`, `SessionIssued`, `AuthenticationRejected`) are emitted as structured `info`/`warn` log entries at the application layer (per `coding-standards.md`'s log-level guidance: registration/auth success as `info`, rejected auth as `warn`), in the exact payload shape defined in Stage 1 — minus the token value, always. This keeps the event vocabulary ready for a real event bus (e.g. once `gamification-engine` needs `UserRegistered`) without building pub/sub infrastructure speculatively in this bolt. |

## Error Handling

| Error Type | Code | Response |
|------------|------|----------|
| Invalid/tampered provider token | `invalid_token` | 401, `{ "error_code": "invalid_token", "message": "..." }` |
| Expired provider token | `expired_token` | 401, `{ "error_code": "expired_token", "message": "..." }` |
| Unsupported language in pending selection | `invalid_pending_selection` | 400, `{ "error_code": "invalid_pending_selection", "message": "..." }` |
| Google/Apple verification endpoint unreachable | `provider_unreachable` | 502, `{ "error_code": "provider_unreachable", "message": "..." }` |
| Unknown/expired session token (validation) | n/a (not an error) | 200, `{ "valid": false }` |
| Missing/malformed `Authorization` header on session check | `missing_credentials` | 401, `{ "error_code": "missing_credentials", "message": "..." }` |

All domain-facing errors are custom exceptions in `app/domain/exceptions.py` (e.g. `InvalidTokenError`, `ExpiredTokenError`, `InvalidPendingSelectionError`, `ProviderUnreachableError`), caught by a single FastAPI exception handler in the presentation layer and mapped to the table above — per `coding-standards.md`'s custom-domain-exception convention.

## External Dependencies

| Service | Purpose | Integration |
|---------|---------|-------------|
| Google OAuth (`google-auth` package) | Verify Google ID tokens server-side (`sub` claim → `provider_user_id`) | REST/library call, synchronous, wrapped by `GoogleTokenVerifier` |
| Sign in with Apple (Apple JWKS: `https://appleid.apple.com/auth/keys`) | Verify Apple identity tokens (JWT signature + claims) server-side | REST (JWKS fetch, cached) + local JWT verification (`PyJWT`), wrapped by `AppleTokenVerifier` |
| `002-auth-onboarding-ui` (consumer, not a dependency of this bolt) | Frontend integration against this bolt's API contract | REST over HTTPS, per `unit-brief.md` |

## Open Items Resolved in This Stage

Resolving the four items carried over from `ddd-01-domain-model.md`'s "Open Items Carried Into Stage 2":

1. **Minutes → Daily XP Target mapping** — fixed lookup table for the four `DailyGoalPreset` values (simple, defensible, linear at 4 XP/minute; explicitly revisable by the future `gamification-engine` intent without touching this bolt's aggregate shape):

   | Preset | `minutes_per_day` | `daily_xp_target` |
   |---|---|---|
   | Casual | 5 | 20 |
   | Regular | 10 | 40 |
   | Serious | 15 | 60 |
   | Intense | 20 | 80 |

2. **Default `LanguageCode` / `DailyXPTarget` when no pending selection arrives at all** — `selected_language = "am"` (Amharic — the only Phase 1 course language, per `tech-stack.md`) and `daily_xp_target = 40` (the "Regular"/10-minute preset — a neutral middle default, not the lowest or highest tier). Applied by `OnboardingAttachmentPolicy.resolve_selection_for_new_user(None)`.

3. **Google/Apple token verification approach** — Google: the official `google-auth` Python package's `id_token.verify_oauth2_token`, validated against our OAuth client ID. Apple: `PyJWT` + `cryptography` verifying the identity token's RS256 signature against Apple's JWKS (`https://appleid.apple.com/auth/keys`), with issuer/audience/expiry checks; no Apple-specific SDK exists for Python, so this is the standard JWT-over-JWKS approach. See Security Design above.

4. **`SessionToken` storage at rest** — hashed (`SHA-256`), stored in `auth_sessions.token_hash`; the raw token is never persisted, only returned once at issuance. See Security Design above.

## New Open Questions (Not Resolved Here — Flagged for Later)

- **Google OAuth client ID / Apple Services ID + Team ID/Key ID configuration values** are deployment secrets, not a design decision — deferred to Stage 4 (Implement) environment configuration, out of scope for documentation-only Stage 2.
- **Backend hosting platform** (VM/container platform, region) remains genuinely TBD per `tech-stack.md`'s own note — this bolt's design does not depend on the choice (stateless FastAPI + Postgres/SQLite works anywhere), but it's called out here so Operations planning doesn't assume it was silently decided.
- **Apple JWKS cache invalidation on key-rotation failure** (what happens if a `kid` isn't found in the cached key set — refetch-and-retry-once vs. hard fail) is an implementation-level detail appropriate for Stage 4, not a Stage 2 architectural decision.
- **Python package manager** (`uv` vs Poetry vs pip+venv) is still marked unconfirmed in `tech-stack.md` — irrelevant to this design document but will block Stage 4 scaffolding until confirmed.
