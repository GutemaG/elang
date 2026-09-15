"""Pydantic request/response schemas for the auth API.

Shapes match `ddd-02-technical-design.md`'s API Design table exactly.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel


class PendingSelectionRequest(BaseModel):
    language: str
    daily_goal_minutes: Literal[5, 10, 15, 20]


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
    is_new_user: bool


class AuthResponse(BaseModel):
    session_token: str
    expires_at: str
    user: AuthUserResponse


class SessionUserResponse(BaseModel):
    id: str
    selected_language: str
    daily_xp_target: int


class SessionValidResponse(BaseModel):
    valid: Literal[True] = True
    user: SessionUserResponse


class SessionInvalidResponse(BaseModel):
    valid: Literal[False] = False


class ErrorResponse(BaseModel):
    error_code: str
    message: str
