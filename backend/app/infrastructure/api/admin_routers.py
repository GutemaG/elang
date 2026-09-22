"""FastAPI router for the content admin API: `/api/v1/admin/*`
(`017-content-admin-web`).

`require_admin` is a router-level dependency, so every endpoint added here
is admin-only without having to remember it (ADR-16).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.domain.entities import User
from app.infrastructure.api.admin_schemas import AdminMeResponse
from app.infrastructure.api.dependencies import require_admin

router = APIRouter(prefix="/api/v1/admin", tags=["admin"], dependencies=[Depends(require_admin)])


@router.get("/me", response_model=AdminMeResponse)
async def get_admin_me(admin: User = Depends(require_admin)) -> AdminMeResponse:
    """Story 001-admin-authorization: who the admin site is signed in as."""
    return AdminMeResponse(email=admin.email or "")
