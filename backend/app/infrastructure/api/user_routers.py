"""FastAPI router: `PATCH /api/v1/users/me` (bolt
`013-user-preferences-service`). Parses/validates the HTTP request (via the
shared `get_current_user` dependency, same auth as every other authenticated
endpoint) and maps the result to `ddd-02-technical-design.md`'s response
shape. No business logic lives here.
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Body, Depends

from app.application.use_cases import (
    read_app_config,
    update_account_settings,
    update_user_preferences,
)
from app.domain.entities import User
from app.domain.services import UserPreferencesService
from app.infrastructure.api.dependencies import (
    get_app_config_repository,
    get_current_user,
    get_user_preferences_service,
    get_user_repository,
)
from app.infrastructure.api.user_schemas import (
    AccountSettingsResponse,
    AppConfigResponse,
    UserPreferencesResponse,
    UserPreferencesUpdateRequest,
)
from app.infrastructure.db.repositories import (
    SqlAlchemyAppConfigRepository,
    SqlAlchemyUserRepository,
)

router = APIRouter(prefix="/api/v1/users", tags=["users"])
config_router = APIRouter(prefix="/api/v1", tags=["config"])


@router.patch("/me", response_model=UserPreferencesResponse)
async def update_my_preferences_endpoint(
    body: UserPreferencesUpdateRequest,
    user: User = Depends(get_current_user),
    service: UserPreferencesService = Depends(get_user_preferences_service),
) -> UserPreferencesResponse:
    """Stories 001/002: the sanctioned post-creation mutation path for
    `daily_xp_target` (ADR-7), plus the notification toggle. A `language`
    change is translated into activating the matching course (ADR-13). All
    fields optional; resubmitting the current value is a no-op success.
    Invalid `language`/`daily_goal_minutes` values raise
    `InvalidPreferenceValueError` (422).
    """
    updated = await update_user_preferences(
        service,
        user,
        body.language,
        body.daily_goal_minutes,
        body.notification_enabled,
    )
    return UserPreferencesResponse(
        id=updated.id,
        selected_language=updated.selected_language.code,
        daily_xp_target=updated.daily_xp_target.xp_per_day,
        notification_enabled=updated.notification_enabled,
        active_course_id=updated.active_course_id,
    )


@router.patch("/me/settings", response_model=AccountSettingsResponse)
async def update_my_settings_endpoint(
    changes: dict[str, Any] = Body(...),
    user: User = Depends(get_current_user),
    user_repo: SqlAlchemyUserRepository = Depends(get_user_repository),
) -> AccountSettingsResponse:
    """Bolt 071 (FR-8): merges a partial map of account settings and returns
    them all. An unknown key or a wrong type is `422 invalid_setting`, and
    nothing is saved.
    """
    settings = await update_account_settings(user_repo, user, changes)
    return AccountSettingsResponse(settings=settings)


@config_router.get("/config", response_model=AppConfigResponse)
async def get_app_config_endpoint(
    repo: SqlAlchemyAppConfigRepository = Depends(get_app_config_repository),
) -> AppConfigResponse:
    """Bolt 071 (FR-9): every known app-wide value. No sign-in: nothing
    secret is ever stored there (`app/domain/settings.py`).
    """
    return AppConfigResponse(config=await read_app_config(repo))
