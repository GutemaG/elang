---
stage: implement
bolt: 013-user-preferences-service
created: '2026-09-17T10:40:00Z'
---

## Implementation Walkthrough: user-preferences-service

### Files Changed

**Domain**
- `app/domain/entities.py`: `User` gains `notification_enabled: bool`; docstring rewritten per ADR-7 (write-once-then-sanctioned-update).
- `app/domain/exceptions.py`: new `InvalidPreferenceValueError` (422) — see Technical Design's Stage-4 correction #2.
- `app/domain/services.py`: `_authenticate` now sets `notification_enabled=True` on every newly-created `User`. New `UserPreferencesService.update_preferences` (loose optional params, not a bundled value object — see Domain Model's Stage-4 correction).
- `app/domain/repositories.py`: `UserRepository` Protocol gains `async def update(self, user: User) -> User`.

**Infrastructure**
- `app/infrastructure/db/models.py`: `UserModel.notification_enabled: Mapped[bool]`, `nullable=False, default=True`.
- `app/infrastructure/db/repositories.py`: `_user_model_to_domain`/`_user_domain_to_model` map the new field; `SqlAlchemyUserRepository.update` added (load by id, mutate the three mutable columns, flush).
- `app/infrastructure/db/migrations/versions/e02dd0a9ae54_add_notification_enabled_to_users.py`: `ADD COLUMN notification_enabled BOOLEAN NOT NULL server_default=true` (constant default, same SQLite gotcha pattern as `e3cea3ee5c84`). Verified: `alembic upgrade head` → `downgrade -1` → `upgrade head` round-trips cleanly.
- `database-schema.md`: `users` table rows updated — `selected_language`/`daily_xp_target` now note the ADR-7 exception; new `notification_enabled` row.

**Application**
- `app/application/use_cases.py`: new `update_user_preferences` use case — calls the domain service, logs `user_preferences_updated` (no domain event exists to emit, per Domain Model's decision).

**Presentation**
- `app/infrastructure/api/user_schemas.py` (new): `UserPreferencesUpdateRequest`, `UserPreferencesResponse`.
- `app/infrastructure/api/user_routers.py` (new): `PATCH /api/v1/users/me`, prefix `/api/v1/users`.
- `app/infrastructure/api/dependencies.py`: new `get_user_preferences_service`.
- `app/infrastructure/api/error_handlers.py`: `InvalidPreferenceValueError → 422` added to `_AUTH_STATUS_BY_EXCEPTION`.
- `app/infrastructure/api/schemas.py`: `AuthUserResponse`/`SessionUserResponse` gain `notification_enabled: bool` (Stage-4 correction #1 — lets `002-profile-and-settings-ui` read current settings via the existing sign-in/`/auth/session` responses, no new GET endpoint).
- `app/infrastructure/api/routers.py`: both response-construction sites updated to populate the new field.
- `app/main.py`: registers the new `user_router`.

**Tests (pre-existing, patched for the new required field only — no new test coverage yet, that's Stage 5)**
- `tests/security/test_security.py`, `tests/unit/test_authentication_service.py`, `tests/unit/test_get_current_user.py`, `tests/unit/test_session_validation_service.py`, `tests/integration/test_repositories.py`: each had one helper directly constructing `User(...)`; added `notification_enabled=True` to keep them passing (`User` is a plain dataclass with no defaults — adding a required field breaks every direct construction site).

### Verification Performed

- `uv run pytest -q`: **251/251 passing** — zero regression to the existing suite (satisfies the bolt's stated NFR).
- `uv run ruff check app tests`: clean.
- `uv run alembic upgrade head` / `downgrade -1` / `upgrade head`: round-trips cleanly.
- `uv run python -c "from app.main import app"`: app still imports/builds cleanly with the new router registered.

### Not Yet Done (Stage 5)

- No new tests written yet for `UserPreferencesService`, the new endpoint's happy path / no-op / 422 path, the repository's `update` method, or the migration's backfill behavior. That's Stage 5's job next.
