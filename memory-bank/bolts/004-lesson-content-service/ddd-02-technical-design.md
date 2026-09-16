---
unit: 001-lesson-service
bolt: 004-lesson-content-service
stage: design
status: complete
created: 2026-09-16T09:20:00Z
---

# Technical Design - Lesson Content Service

## Architecture Pattern

**Layered/Clean Architecture (domain-driven), same single FastAPI service as `001-auth-service`** — per `coding-standards.md`'s prescribed backend layout and to avoid inventing a second pattern in the same codebase. New code lives alongside the existing auth modules under `backend/app/`, not in a separate service.

**Module organization decision (construction-time judgment call, documented since no human reviewed it live)**: this is the app's *second* bounded context. `001-auth-service`'s flat files (`app/domain/entities.py`, `value_objects.py`, `services.py`, `repositories.py`, `exceptions.py`) work for one bounded context but would force auth and lesson-content concepts into the same files if reused as-is — `coding-standards.md` itself anticipates this, describing `domain/` as "entities, value objects **per bounded context** (lesson, gamification, srs)". This bolt therefore introduces a `app/domain/lesson/` subpackage (`entities.py`, `value_objects.py`, `services.py`, `repositories.py`, `exceptions.py` — same file names, same responsibilities, just namespaced) rather than appending to the existing flat auth files. The application layer gets one new file, `app/application/lesson_use_cases.py` (mirrors `use_cases.py`'s per-bounded-context-file pattern once there's more than one context). Infrastructure keeps `db/` and `api/` as shared top-level folders (per `coding-standards.md`'s layout, these aren't bounded-context-specific) with new lesson-prefixed files added alongside the existing auth ones: `db/lesson_models.py`, `db/lesson_repositories.py`, `db/seed_lesson_content.py`, `api/lesson_schemas.py`, `api/lesson_routers.py`. Two existing shared files gain small additive changes (see below) rather than new lesson-specific copies, because the thing they provide — session validation, domain-exception-to-HTTP mapping — is explicitly meant to be reused, not duplicated.

No CQRS, event sourcing, or service split — same rationale as `001-auth-service`: small scope (2 stories, 3 content aggregates, read-only), a single FastAPI service is sufficient.

## Layer Structure

```text
┌──────────────────────────────────────────────────────────────┐
│  Presentation (app/infrastructure/api)                        │
│    lesson_routers.py: GET /api/v1/skill-tree,                 │
│                        GET /api/v1/lessons/{lesson_id}         │
│    (+ dependencies.py gains get_current_user; error_handlers.py│
│     gains a second exception_handler for lesson exceptions)    │
├──────────────────────────────────────────────────────────────┤
│  Application (app/application/lesson_use_cases.py)             │
│    get_skill_tree, get_lesson_content                          │
├──────────────────────────────────────────────────────────────┤
│  Domain (app/domain/lesson/)                                   │
│    Skill, Lesson, Exercise, UserSkillProgress entities;         │
│    SkillTreeProgressionPolicy, LessonAccessPolicy;              │
│    repository interfaces (Protocols)                            │
├──────────────────────────────────────────────────────────────┤
│  Infrastructure (app/infrastructure/db)                         │
│    lesson_models.py (SQLAlchemy), lesson_repositories.py,        │
│    seed_lesson_content.py (idempotent seed script),              │
│    Alembic migration                                             │
└──────────────────────────────────────────────────────────────┘
```

- **Presentation**: parses the `Authorization` header via the (extended) shared `get_current_user` dependency, calls the relevant use case, maps domain results/exceptions to the HTTP shapes below. No business logic.
- **Application**: one function per operation (`get_skill_tree`, `get_lesson_content`), orchestrating the domain services + repositories inside the request's DB session. No SQLAlchemy/HTTP imports.
- **Domain**: pure Python, zero framework imports, exactly as modeled in Stage 1.
- **Infrastructure**: SQLAlchemy models/repositories implementing the domain Protocols; the seed script; the Alembic migration.

## API Design

Base path: `/api/v1`. Both endpoints require a valid session token — reusing the **existing** `SessionValidationService` from `001-auth-service` via a new shared `get_current_user` FastAPI dependency (added to `app/infrastructure/api/dependencies.py`, not a new auth mechanism):

```python
async def get_current_user(
    authorization: str | None = Header(default=None),
    service: SessionValidationService = Depends(get_session_validation_service),
) -> User:
    # Same header-parsing rule as the existing /auth/session endpoint:
    # missing/malformed header -> MissingCredentialsError (401);
    # well-formed but unknown/expired token -> InvalidSessionError (401, new)
    # -- distinct from /auth/session's `{"valid": false}` because here an
    # invalid session IS a request-failure, not an expected polling outcome.
    ...
```

| Endpoint | Method | Request | Response | Status |
|----------|--------|---------|----------|--------|
| `/api/v1/skill-tree` | GET | Header: `Authorization: Bearer {session_token}` | `{ "skills": [ { "id": string, "title": string, "order_index": int, "state": "locked"\|"active"\|"completed", "crown_level": int } ] }` | 200, 401 |
| `/api/v1/lessons/{lesson_id}` | GET | Header: `Authorization: Bearer {session_token}` | `{ "lesson": { "id": string, "skill_id": string, "title": string, "order_index": int }, "exercises": [ {exercise} ] }` — see Exercise Payload Shapes below | 200, 401, 403, 404 |

**Exercise Payload Shapes** (discriminated by `"type"`, correct answer **never included** — see Decision 1 below):

```jsonc
// type: "multiple_choice"
{ "id": "...", "order_index": 1, "type": "multiple_choice", "prompt": "How do you say 'Hello'?",
  "choices": [ { "id": "a", "text": "ሰላም" }, { "id": "b", "text": "ደህና ሁን" }, ... ] }

// type: "listening"
{ "id": "...", "order_index": 3, "type": "listening", "prompt": "What does this word mean?",
  "audio_url": "https://r2-placeholder.buna.dev/audio/greetings-hello.mp3",
  "choices": [ { "id": "a", "text": "Hello" }, { "id": "b", "text": "Goodbye" }, ... ] }

// type: "sentence_construction"
{ "id": "...", "order_index": 4, "type": "sentence_construction", "prompt": "Translate: 'I am fine'",
  "word_bank": [ { "id": "w1", "text": "ደህና" }, { "id": "w2", "text": "ነኝ" }, { "id": "w3", "text": "ጥሩ" }, ... ] }
```

### Decision 1: Lesson-content payload never includes correct answers (server-side-only grading)

Stage 1's domain model deliberately kept `content` (renderable) and `answer_key` (correct-answer) as separate value objects on `Exercise` so this decision could be made explicitly, since it's a real contract bolt `005` depends on. **Decision: `answer_key` is never serialized into the `GET /lessons/{lesson_id}` response.** The Pydantic response schemas for each exercise type only expose fields sourced from `content` (`choices`, `word_bank`, `audio_url`), never `correct_choice_id`/`correct_sequence`. Bolt `005`'s `SubmitExerciseAnswer` (story 002) receives `exercise_id` + `submitted_answer` and must look up the correct answer server-side, via its own read of the `exercises` table (the same `answer_key` JSON column this bolt writes but does not expose over HTTP) — not by trusting anything the client already has. Rationale: grading server-side is required regardless for Beans deduction (a client can't be trusted to decide when it "loses a heart"), and a payload that already contains the answer is trivially inspectable over the network, defeating the exercise. This mirrors the design's whole gamification premise (mistakes cost something real) rather than being pure paranoia. **Promoted to ADR** (see Stage 3) given how directly bolt `005` depends on this.

### Error Codes

| `error_code` | HTTP Status | Meaning |
|---|---|---|
| `missing_credentials` | 401 | Missing/malformed `Authorization` header (reused from `001-auth-service`, unchanged) |
| `invalid_session` | 401 | Well-formed header, but the token is unknown/expired (new — see Security Design) |
| `skill_locked` | 403 | The lesson's owning skill is `locked` for this user — direct-ID access denied per story 001's edge case |
| `lesson_not_found` | 404 | No lesson exists with the given id |

Error body shape unchanged: `{ "error_code": "...", "message": "..." }`.

## Data Model

Four new tables, added to `database-schema.md` alongside the existing `users`/`auth_sessions` (not replacing them). Summarized from Stage 1's aggregates; full column definitions live in `database-schema.md`.

| Table | Columns (summary) | Relationships |
|-------|---------|---------------|
| `skills` | `id`, `title`, `order_index` (unique), `created_at` | Referenced by `lessons.skill_id`, `user_skill_progress.skill_id`. |
| `lessons` | `id`, `skill_id`, `title`, `order_index` (unique within `skill_id`), `created_at` | FK to `skills`. Referenced by `exercises.lesson_id`. |
| `exercises` | `id`, `lesson_id`, `order_index` (unique within `lesson_id`), `type`, `prompt`, `content` (JSON), `answer_key` (JSON), `created_at` | FK to `lessons`. |
| `user_skill_progress` | `id`, `user_id`, `skill_id`, `unlocked`, `crown_level`, `completed_at`, `created_at` | FK to `users` (existing table) and `skills`. Unique `(user_id, skill_id)`. |

### Decision 2: Single polymorphic `exercises` table with JSON `content`/`answer_key` columns, not per-type tables

**Promoted to ADR** (see Stage 3): with exactly 3 fixed, well-understood exercise types (per `requirements.md` FR-2, closed for this intent's scope), one `exercises` table with a `type` discriminator column plus two JSON columns (`content`, `answer_key`) avoids 3 near-duplicate tables (`multiple_choice_exercises`, `listening_exercises`, `sentence_construction_exercises`) or a wide table with mostly-null type-specific columns, while keeping `ORDER BY lesson_id, order_index` — the only query pattern this bolt actually needs — trivial and index-friendly. `sqlalchemy.JSON` (not Postgres-specific `JSONB`) is used deliberately: it stores as `TEXT` on SQLite and as native `JSON`/`JSONB` on PostgreSQL through the same column type, and this bolt never needs to query *inside* the JSON (no `WHERE content->>'audio_url' = ...`), sidestepping `data-stack.md`'s documented SQLite/Postgres JSON-operator gap entirely.

### Decision 3: Deterministic, slug-derived IDs for seeded content (not random `uuid4`)

`users`/`auth_sessions` use server-generated `uuid4` because those rows are created at runtime by user action. `skills`/`lessons`/`exercises` rows are instead created once by the idempotent seed script (story 005's hard requirement: "safe to re-run against a dev database... no duplicate rows"). IDs are generated as `uuid5(NAMESPACE_BUNA_CONTENT, "<content-slug>")` (e.g. `uuid5(ns, "skill:greetings-and-basics")`), giving stable, UUID-shaped (`String(36)`, consistent with every other `id` column in the schema) identifiers that are identical on every seed run. The seed script does a fetch-then-insert-or-update per row keyed by this deterministic id (see Seed Design below), rather than relying on a separate natural-key uniqueness check.

## Security Design

| Concern | Approach |
|---------|----------|
| Authentication | Every endpoint requires `Authorization: Bearer {session_token}`, validated via the **existing** `SessionValidationService` (no new verification logic) through the new shared `get_current_user` dependency. |
| Authorization | Skill-lock enforcement (`LessonAccessPolicy.ensure_accessible`) is authorization, not authentication — a *valid* session can still be denied a *locked* lesson. Enforced in the application layer (`get_lesson_content`), not just optimistically in the router, so it can't be bypassed by a future caller of the use case that forgets to re-check. |
| New exception, `InvalidSessionError` | Added to the existing `app/domain/exceptions.py` (auth's exception module — this is fundamentally an auth-layer outcome, "your session token doesn't resolve to a user," reused by any future authenticated endpoint, not lesson-specific) and registered in the existing `_STATUS_BY_EXCEPTION` map in `error_handlers.py` → 401. Distinct from `/auth/session`'s `{"valid": false}` 200 response: that endpoint's whole job is polling "is my session still good," so an invalid answer is an expected outcome; every *other* authenticated endpoint (including both of this bolt's) treats an invalid session as a request failure, matching how a real client behaves (redirect to sign-in), so it gets the request's actual error-handling path (401 + `error_code`) instead of a 200 the caller would have to special-case. |
| Data exposure | `answer_key` never leaves the server (Decision 1). No PII in the new tables (`user_skill_progress.user_id` is a plain FK reference, same pattern as `auth_sessions.user_id`). |

## NFR Implementation

| Requirement | Design Approach |
|-------------|-----------------|
| Performance (single request per lesson) | `LessonRepository.get_by_id` loads the `Lesson` row and all its `Exercise` rows in one query (`selectinload`/join on `exercises` ordered by `order_index`) — the API layer does zero additional per-exercise queries, satisfying `system-context.md`'s "no per-exercise round trip" NFR at both the DB and HTTP layer. |
| Performance (skill tree) | `get_skill_tree` issues exactly 2 queries regardless of skill count: `SkillRepository.list_all()` and `UserSkillProgressRepository.list_by_user(user_id)` — `SkillTreeProgressionPolicy` then computes every skill's state in memory, avoiding an N+1 per-skill progress lookup. |
| Reliability | Read-only endpoints — no transactional-write concern in this bolt. The seed script (write path) is idempotent by construction (Decision 3), so a crashed/retried seed run never leaves duplicate or half-written content. |
| Testability | Same SQLite-via-`aiosqlite` local/test setup as `001-auth-service` (`data-stack.md`) — `sqlalchemy.JSON` round-trips identically on SQLite and Postgres for this bolt's read-only, non-JSON-querying usage, so no Postgres-only test path is required. |
| Observability | No new domain events (per Stage 1); standard request logging only — nothing gamification-relevant happens yet in this bolt (no XP/streak/Beans writes), so there's nothing event-worthy to log beyond normal HTTP access logging. |

## Error Handling

| Error Type | Code | Response |
|------------|------|----------|
| Missing/malformed `Authorization` header | `missing_credentials` | 401 |
| Unknown/expired session token | `invalid_session` | 401 |
| Lesson id doesn't exist | `lesson_not_found` | 404 |
| Lesson's skill is locked for this user | `skill_locked` | 403 |

`LessonDomainError` (base, new, in `app/domain/lesson/exceptions.py`) → `LessonNotFoundError` (404), `SkillLockedError` (403). Both are caught by a **second** `@app.exception_handler` registered in the existing `error_handlers.py` (additive — the existing `AuthDomainError` handler is untouched), keeping all exception-to-HTTP mapping centralized in one file per `coding-standards.md`'s custom-domain-exception convention, without forcing lesson exceptions to pretend to be auth exceptions.

## External Dependencies

| Service | Purpose | Integration |
|---------|---------|-------------|
| Cloudflare R2 (per `tech-stack.md`) | Real deployment target for listening-exercise audio | Not available in this environment (no real credentials) — see Seed Design below for the documented placeholder used instead. The backend only ever stores/serves a URL string; it has no R2 SDK dependency itself. |
| `005-lesson-engagement-service` (consumer, not a dependency of this bolt) | Reads `exercises.answer_key` for grading; reads/writes `user_skill_progress` | Same DB, same app — no network integration, just a shared schema this bolt establishes. |

## Seed Design (Story 005)

A dedicated, idempotent script — `app/infrastructure/db/seed_lesson_content.py` — not an Alembic data migration, so it can be re-run freely against a dev DB without needing a new migration revision each time content is edited (Alembic migrations are for schema, not for iterating on curriculum copy). Run via `uv run python -m app.infrastructure.db.seed_lesson_content`.

- **Content**: 2 skills ("Greetings & Basics", "Food & Drink"), 2 lessons each, 4 exercises per lesson (2 `multiple_choice`, 1 `listening`, 1 `sentence_construction` — a mix of all 3 types per lesson, per the acceptance criteria), real hand-authored English→Amharic vocabulary (Fidel script, UTF-8) — full content listed in `implementation-notes.md`.
- **Idempotency**: every `Skill`/`Lesson`/`Exercise` gets a deterministic `uuid5`-derived id (Decision 3). The seed function, per row, does `SELECT ... WHERE id = :id`; if absent, `INSERT`; if present, `UPDATE` the content columns to match the current seed source (so editing seed copy and re-running converges instead of erroring or duplicating). No rows are ever deleted by the script.
- **Audio placeholder (documented, non-blocking limitation)**: no real Cloudflare R2 bucket/credentials exist in this environment. `audio_url` values use a clearly-marked, non-functional stub scheme: `https://r2-placeholder.buna.dev/audio/<slug>.mp3`. This mirrors how `001-auth-service` treated missing real Google/Apple OAuth credentials as a documented, non-blocking placeholder rather than a blocker — flagged again in this bolt's `ddd-03-test-report.md` Issues Found, not silently glossed over. Swapping in real R2 URLs later is a pure data update (re-run the idempotent seed with real URLs), not a schema or contract change.

## New Open Questions (Not Resolved Here — Flagged for Later)

- **Real Cloudflare R2 bucket provisioning and upload of actual human-recorded audio** — genuinely blocked on infrastructure/credentials not available in Construction; the placeholder URL scheme is a deliberate, swappable stand-in, not a design gap.
- **Branching skill trees** (multiple skills unlockable in parallel, prerequisite graphs beyond a single linear order) are out of scope — `Skill.order_index` models a single path only, matching the current design system and FR-1's "serpentine path" description; revisit if product ever wants non-linear unlocking.
- **Full Phase 1 curriculum authoring** (dozens of skills) is explicitly out of scope per `requirements.md`'s Business Constraints — this bolt's 2-skill/4-lesson seed is a proof-of-loop set only.
