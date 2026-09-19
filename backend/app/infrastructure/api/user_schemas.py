"""Pydantic request/response schemas for the user-preferences endpoint
(bolt `013-user-preferences-service`).
"""

from __future__ import annotations

from pydantic import BaseModel


class UserPreferencesUpdateRequest(BaseModel):
    """All fields optional: omitted/`None` means "leave unchanged," not
    "clear it." `daily_goal_minutes` is validated as a domain value
    (`OnboardingAttachmentPolicy`'s minutes lookup table), not restricted at
    this schema layer, so an invalid value gets the same `422
    invalid_preference_value` error shape as an invalid `language`.
    """

    language: str | None = None
    daily_goal_minutes: int | None = None
    notification_enabled: bool | None = None


class UserPreferencesResponse(BaseModel):
    id: str
    selected_language: str
    daily_xp_target: int
    notification_enabled: bool
    active_course_id: str
