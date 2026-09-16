---
stage: implement
bolt: 004-lesson-content-service
created: 2026-09-16T10:15:00Z
---

# Implementation Notes: Lesson Content Service (Stage 4)

## Summary

Implemented both stories (`001-serve-skill-tree-and-lesson-content`,
`005-seed-curriculum-content`) directly in the existing `backend/` app,
alongside `001-auth-service`'s code, per `ddd-02-technical-design.md`'s
Architecture Pattern (new `app/domain/lesson/` bounded-context subpackage +
new lesson-prefixed files in the existing shared `db/`/`api/` folders).
Two new endpoints: `GET /api/v1/skill-tree`, `GET /api/v1/lessons/{lesson_id}`,
both authenticated via the reused `SessionValidationService` from
`001-auth-service` through a new shared `get_current_user` dependency. A new
Alembic migration adds `skills`, `lessons`, `exercises`, `user_skill_progress`.
An idempotent seed script populates 2 skills / 4 lessons / 16 exercises of
real, hand-authored English→Amharic content.

## Structure Overview

```text
backend/app/
├── domain/
│   ├── exceptions.py           # + InvalidSessionError (auth, reused)
│   └── lesson/                  # NEW bounded-context subpackage
│       ├── entities.py            # Skill, Lesson, Exercise, UserSkillProgress
│       ├── value_objects.py       # ExerciseType, SkillState, Choice, *Content, *AnswerKey, CrownLevel
│       ├── services.py            # SkillTreeProgressionPolicy, LessonAccessPolicy
│       ├── repositories.py        # SkillRepository/LessonRepository/UserSkillProgressRepository Protocols
│       └── exceptions.py          # LessonDomainError, LessonNotFoundError, SkillLockedError
├── application/
│   └── lesson_use_cases.py      # NEW: get_skill_tree, get_lesson_content
└── infrastructure/
    ├── db/
    │   ├── lesson_models.py        # NEW: SkillModel, LessonModel, ExerciseModel, UserSkillProgressModel
    │   ├── lesson_repositories.py  # NEW: SqlAlchemy* implementations
    │   ├── seed_lesson_content.py  # NEW: idempotent curriculum seed
    │   └── migrations/
    │       ├── env.py                # + import lesson_models (metadata registration)
    │       └── versions/772d3af2a112_*.py  # NEW migration
    └── api/
        ├── dependencies.py       # + get_current_user (shared, reused by future authenticated endpoints)
        ├── lesson_dependencies.py# NEW: per-request lesson repository DI
        ├── lesson_schemas.py     # NEW: Pydantic response schemas (no answer_key field, ADR-4)
        ├── lesson_routers.py     # NEW: the 2 endpoints
        └── error_handlers.py     # + second exception_handler for LessonDomainError
main.py                            # + include_router(lesson_router)
```

## Completed Work

- `backend/app/domain/lesson/*.py` -- pure-Python domain layer per Stage 1's model: `Skill`/`Lesson`/`Exercise`/`UserSkillProgress` entities; `ExerciseType`/`SkillState`/`Choice`/`MultipleChoiceContent`/`ListeningContent`/`SentenceConstructionContent`/`ChoiceAnswerKey`/`SequenceAnswerKey`/`CrownLevel` value objects; `SkillTreeProgressionPolicy` (new-user bootstrap + per-user state computation) and `LessonAccessPolicy` (locked-skill enforcement) domain services; `SkillRepository`/`LessonRepository`/`UserSkillProgressRepository` Protocols; `LessonDomainError`/`LessonNotFoundError`/`SkillLockedError` exceptions.
- `backend/app/domain/exceptions.py` -- added `InvalidSessionError` (401) to the existing auth exception module, since "session token doesn't resolve to a user" is fundamentally an auth-layer outcome reusable by any future authenticated endpoint, not lesson-specific.
- `backend/app/application/lesson_use_cases.py` -- `get_skill_tree`, `get_lesson_content` (the latter enforcing `LessonAccessPolicy` before returning, so a locked skill's lesson is unreachable even by direct ID regardless of caller).
- `backend/app/infrastructure/db/lesson_models.py` -- `SkillModel`, `LessonModel`, `ExerciseModel` (single polymorphic table, JSON `content`/`answer_key` columns, ADR-3), `UserSkillProgressModel`; all sharing the existing `Base` from `db/models.py`.
- `backend/app/infrastructure/db/lesson_repositories.py` -- `SqlAlchemySkillRepository`, `SqlAlchemyLessonRepository` (single `selectinload` query for a lesson + all its exercises -- no per-exercise round trip), `SqlAlchemyUserSkillProgressRepository` (read-only; reconstructs the correct `ExerciseContent`/`AnswerKey` value object from each row's `type` discriminator).
- `backend/app/infrastructure/db/seed_lesson_content.py` -- idempotent seed (deterministic `uuid5`-derived ids, fetch-then-insert-or-update per row); 2 skills, 4 lessons, 16 exercises of real Amharic content (see below); documented placeholder audio-URL scheme (`https://r2-placeholder.buna.dev/audio/<slug>.mp3`) since no real Cloudflare R2 credentials exist in this environment.
- `backend/app/infrastructure/db/migrations/env.py` -- added an import of `lesson_models` for its side effect of registering the new tables on `Base.metadata` (autogenerate initially produced an empty diff without this).
- `backend/app/infrastructure/db/migrations/versions/772d3af2a112_*.py` -- generated via `alembic revision --autogenerate`, reviewed, reformatted to match the project's existing migration style; creates `skills`, `lessons`, `exercises`, `user_skill_progress` with all constraints/indexes from the models above; verified via `alembic upgrade head` against the existing dev SQLite DB (already at the `001-auth-service` migration head).
- `backend/app/infrastructure/api/lesson_schemas.py` -- Pydantic response schemas; a discriminated union (`type` field) over the 3 exercise response shapes; deliberately has no field for `answer_key` anywhere (ADR-4 enforced by the schema's shape, not just router discipline).
- `backend/app/infrastructure/api/lesson_dependencies.py` -- per-request DI for the 3 lesson repositories.
- `backend/app/infrastructure/api/dependencies.py` -- added `get_current_user`, reusing the existing `SessionValidationService`/`validate_session` (no new auth mechanism); distinguishes `MissingCredentialsError` (bad header) from the new `InvalidSessionError` (well-formed header, dead token).
- `backend/app/infrastructure/api/error_handlers.py` -- added a second `@app.exception_handler(LessonDomainError)` registration alongside the existing `AuthDomainError` one (both in the same file, centralized per `coding-standards.md`); added `InvalidSessionError` to the auth status map.
- `backend/app/infrastructure/api/lesson_routers.py` -- `GET /api/v1/skill-tree`, `GET /api/v1/lessons/{lesson_id}`; router-level mapping only (no business logic), including the `_to_exercise_response` mapper that reads only `exercise.content`, never `exercise.answer_key`.
- `backend/app/main.py` -- registered the new `lesson_router`.
- `database-schema.md` -- appended `skills`/`lessons`/`exercises`/`user_skill_progress` table definitions alongside the existing `users`/`auth_sessions` (not replacing them), per the file's own stated growth model.

## Key Decisions

- **Bounded-context subpackaging** (`app/domain/lesson/`, `app/application/lesson_use_cases.py`) rather than appending to `001-auth-service`'s flat domain files -- documented in Technical Design as a construction-time judgment call following `coding-standards.md`'s own stated (but until now unused) "per bounded context" layout.
- **`answer_key` never leaves the server** (ADR-4) -- enforced structurally: the Pydantic response schemas have no field for it, and `_to_exercise_response` in `lesson_routers.py` never reads `exercise.answer_key`, so there's no code path that could accidentally leak it, not just a convention to remember.
- **Deterministic content IDs** (`uuid5(CONTENT_NAMESPACE, slug)`) for seeded rows, distinct from the `uuid4()` used for runtime-created rows (`users`, `auth_sessions`) -- makes the seed script's idempotency a property of the ID scheme itself rather than a separate existence-check-by-natural-key.
- **`SkillTreeProgressionPolicy.state_for_skill`** recomputes the *entire* tree and picks out one entry, rather than a shortcut single-skill computation, specifically so the lesson-access check can never disagree with what the skill-tree endpoint would show for the same skill (both paths share one function, one source of truth).

## Deviations from Plan

- Alembic `--autogenerate` initially produced an empty migration because `env.py` only imported the auth `models.py` module, so the new lesson tables were never registered onto the shared `Base.metadata` before the diff was computed. Fixed by adding a side-effect import of `lesson_models` in `env.py` (an anticipated integration detail, not a design change -- documented here since it wasn't explicitly called out in Technical Design).
- Two small dead-code helpers (`_content_to_json`, `_answer_key_to_json`) were drafted for symmetry with their `_from_json` counterparts during implementation, then removed -- nothing in this read-only bolt ever serializes a domain value object back to JSON (the seed script writes raw dicts directly), so they had no caller.

## Dependencies Added

None. No new third-party packages were required (`sqlalchemy.JSON` and the existing `stdlib uuid` module cover everything this bolt needs).

## Verification Performed (Stage 4)

- `uv run ruff check app` -- 0 errors after 2 rounds of auto-fix (forward-reference quoting under `from __future__ import annotations`, import ordering in `env.py`).
- `uv run ruff format app --check` -- all files formatted.
- `uv run mypy app` -- "Success: no issues found in 39 source files".
- `uv run alembic upgrade head` against the existing dev SQLite DB (already at `001-auth-service`'s migration head) -- applied cleanly, no errors.
- `uv run python -m app.infrastructure.db.seed_lesson_content`, run twice in a row -- second run produced identical row counts (2 skills / 4 lessons / 16 exercises), confirming idempotency; spot-checked a `listening` exercise row's `content`/`answer_key` JSON by direct SQLite query -- correct UTF-8 Amharic, correct shape.
- Manual `TestClient` smoke check (not a committed test -- Stage 5 is the separate, real test-writing step) -- confirmed all 2 new routes register (`/openapi.json` lists `/api/v1/skill-tree` and `/api/v1/lessons/{lesson_id}` alongside the 3 existing auth routes) and that an unauthenticated request to `/api/v1/skill-tree` correctly returns `401 missing_credentials`.
