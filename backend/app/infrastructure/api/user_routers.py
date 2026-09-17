"""FastAPI router: `PATCH /api/v1/users/me` (bolt
`013-user-preferences-service`). Parses/validates the HTTP request (via the
shared `get_current_user` dependency, same auth as every other authenticated
endpoint) and maps the result to `ddd-02-technical-design.md`'s response
shape. No business logic lives here.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.application.use_cases import update_user_preferences
from app.domain.entities import User
from app.domain.services import UserPreferencesService
from app.infrastructure.api.dependencies import get_current_user, get_user_preferences_service
from app.infrastructure.api.user_schemas import (
    UserPreferencesResponse,
    UserPreferencesUpdateRequest,
)

router = APIRouter(prefix="/api/v1/users", tags=["users"])


@router.patch("/me", response_model=UserPreferencesResponse)
async def update_my_preferences_endpoint(
    body: UserPreferencesUpdateRequest,
    user: User = Depends(get_current_user),
    service: UserPreferencesService = Depends(get_user_preferences_service),
) -> UserPreferencesResponse:
    """Stories 001/002: the one sanctioned post-creation mutation path for
    `selected_language`/`daily_xp_target` (ADR-7), plus the notification
    toggle. All fields optional; resubmitting the current value is a no-op
    success. Invalid `language`/`daily_goal_minutes` values raise
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
    )
