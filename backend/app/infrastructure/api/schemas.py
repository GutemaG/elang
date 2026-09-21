"""Pydantic request/response schemas for the auth API.

Shapes match `ddd-02-technical-design.md`'s API Design table exactly.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class PendingSelectionRequest(BaseModel):
    language: str
    daily_goal_minutes: Literal[5, 10, 15, 20]
    # Bolt 024: the language the learner speaks; absent means `en`.
    from_language: str | None = None


class GoogleAuthRequest(BaseModel):
    id_token: str
    pending_selection: PendingSelectionRequest | None = None


class AppleAuthRequest(BaseModel):
    identity_token: str
    pending_selection: PendingSelectionRequest | None = None


class AuthUserResponse(BaseModel):
    id: str
    selected_language: str
    daily_xp_target: int
    notification_enabled: bool
    is_new_user: bool
    active_course_id: str


class AuthResponse(BaseModel):
    session_token: str
    expires_at: str
    user: AuthUserResponse


class SessionUserResponse(BaseModel):
    id: str
    selected_language: str
    daily_xp_target: int
    notification_enabled: bool
    active_course_id: str


class SessionValidResponse(BaseModel):
    valid: Literal[True] = True
    user: SessionUserResponse
    # When the session now expires. Checking a session renews it (sliding
    # renewal), so this can be later than the expiry given at sign-in; the
    # app stores it so its own offline expiry check stays in step.
    expires_at: datetime


class SessionInvalidResponse(BaseModel):
    valid: Literal[False] = False


class ErrorResponse(BaseModel):
    error_code: str
    message: str
