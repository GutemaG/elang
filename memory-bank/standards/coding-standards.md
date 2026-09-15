# Coding Standards

## Overview
Two codebases, two toolchains: idiomatic Dart/Flutter conventions for the mobile client, idiomatic Python conventions for the FastAPI backend. Defaults below follow each ecosystem's standard tooling rather than custom config, since MVP scope and AI-generated code both benefit from well-known conventions.

## Code Formatting

**Dart/Flutter**: `dart format` (the standard formatter, no config needed)
**Python**: `black` (formatting) + `ruff format` is an acceptable Black-compatible alternative — pick one, don't run both

**Enforcement**: on save in editor + pre-commit hook; CI fails on unformatted code.

## Linting

**Dart/Flutter**: `flutter_lints` package (Flutter team's recommended rule set) as the baseline in `analysis_options.yaml`
**Python**: `ruff` for linting (fast, replaces flake8/isort/pyupgrade) + `mypy` for type checking on the backend

**Strictness**: balanced — warn on style nits, error on correctness issues (unused imports, unreachable code, missing awaits).

**Key rules**:
- No `print`/`debugPrint` left in committed code — use the logging setup below
- Type hints required on all new Python function signatures (FastAPI relies on them for validation anyway)
- No unused imports/variables in either codebase

## Naming Conventions

| Element | Dart/Flutter | Python |
|---|---|---|
| Variables/functions | `lowerCamelCase` | `snake_case` |
| Classes/Widgets | `UpperCamelCase` | `PascalCase` |
| Constants | `lowerCamelCase` (or `kConstantName` if truly global) | `UPPER_SNAKE_CASE` |
| Files | `snake_case.dart` | `snake_case.py` |
| Private members | leading `_` | leading `_` |

**Domain terms are product-specific — use them verbatim in code, not their Duolingo-analog names**: `beans` (not "hearts"), `amole` (not "gems"), `xp_transactions`/`amole_transactions` (ledger tables), `next_review_at` (SRS field). Consistency here matters because the product renamed these mechanics deliberately.

## File & Folder Organization

**Flutter client** — feature-based, matching the Phase 1 screen groups (auth/onboarding, core loop, account):

```text
lib/
  features/
    auth/            # splash, onboarding, login, language+goal selection
    lesson/           # skill tree, lesson/exercise template, lesson-complete, out-of-beans
    account/          # profile, settings
  shared/
    widgets/
    services/         # API client, auth, local cache/offline sync
    models/
  main.dart
```

**FastAPI backend** — domain-driven, aligned with the DDD construction-bolt workflow this project uses for backend units:

```text
app/
  domain/             # entities, value objects per bounded context (lesson, gamification, srs)
  application/        # use cases / services (complete_lesson, award_xp, spend_amole, srs_due_query)
  infrastructure/
    db/               # SQLAlchemy models, Alembic migrations
    api/              # FastAPI routers
  main.py
```

**Tests**: co-located `test/` per top-level app (Flutter's default `test/` dir; Python's `tests/` mirroring `app/`'s structure).

## Testing Strategy

**Flutter**: `flutter_test` for widget/unit tests; `integration_test` package for the core-loop end-to-end flow (skill tree → lesson → exercises → completion), since that flow is explicitly part of Definition of Done.
**Backend**: `pytest` + `pytest-asyncio` (matches FastAPI's async handlers).

**Coverage target**: no blanket percentage — prioritize full coverage of the gamification ledger logic (XP/Bean/Amole updates, streak calculation, SRS due-item query) since Definition of Done requires these to persist correctly server-side. UI screens get smoke/widget-level coverage, not exhaustive coverage.

**Conventions**:
- Test naming: `test('should ... when ...')` (Dart), `test_should_..._when_...` or plain descriptive names (pytest)
- Arrange-Act-Assert structure
- Mock at the network/DB boundary only — don't mock domain logic under test

## Error Handling

**Backend**: custom domain exceptions per bounded context (e.g. `OutOfBeansError`, `InsufficientAmoleError`) caught by a FastAPI exception handler and mapped to a structured error response (`{ "error_code": ..., "message": ... }`) with the correct HTTP status. Ledger-affecting endpoints (XP/Bean/Amole) must be transactional — no partial writes on failure.
**Flutter**: typed exceptions/`Result`-style wrapper at the API-client boundary; UI layer never handles raw HTTP/parse errors, only domain-level failures (e.g. "out of beans", "offline — queued for sync").

## Logging

**Backend**: Python standard `logging` module, structured (JSON) in non-local environments, human-readable in dev. Levels: `error` (failed request/job), `warn` (handled-but-unexpected, e.g. SRS query returned no due items when some were expected), `info` (lesson completed, streak updated, subscription-relevant events once Phase 2 lands), `debug` (dev only).
**Flutter**: minimal logging in release builds; never log tokens, OAuth credentials, or raw API payloads containing user data.

**Never log**: Google/Apple OAuth tokens, API keys, raw PII beyond what's needed for the log's purpose.
