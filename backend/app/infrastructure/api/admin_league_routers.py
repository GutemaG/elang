"""The admin Leagues page's API (intent 030): `/api/v1/admin/leagues`.
Super admins only, through the router-level `require_super_admin`.

- `GET` returns one week's groups (the current week by default).
- `POST /members/{member_id}/remove` and `/restore` take a member out of
  this week's league and put them back.
- `PUT /members/{member_id}/xp` sets their weekly XP adjustment.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import admin_league_use_cases as uc
from app.domain.admin import AdminAccess
from app.domain.lesson.exceptions import InvalidContentError
from app.infrastructure.api.admin_league_schemas import (
    AdjustXpRequest,
    AdminLeagueMemberResponse,
    AdminLeagueWeekResponse,
    RemoveMemberRequest,
)
from app.infrastructure.api.dependencies import require_super_admin
from app.infrastructure.db.league_repository import SqlAlchemyLeagueRepository
from app.infrastructure.db.session import get_db_session

router = APIRouter(
    prefix="/api/v1/admin/leagues",
    tags=["admin"],
    dependencies=[Depends(require_super_admin)],
)


def get_now() -> datetime:
    """Overridable in tests."""
    return datetime.now(UTC)


async def _repo(session: AsyncSession = Depends(get_db_session)) -> SqlAlchemyLeagueRepository:
    return SqlAlchemyLeagueRepository(session)


def _day(value: str | None, field: str) -> date | None:
    """A `YYYY-MM-DD` query value; a bad one is `invalid_content`."""
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError as e:
        raise InvalidContentError(field, "Use a date like 2026-10-12") from e


@router.get("", response_model=AdminLeagueWeekResponse)
async def get_league_week(
    week: str | None = Query(default=None, max_length=10),
    repo: SqlAlchemyLeagueRepository = Depends(_repo),
    now: datetime = Depends(get_now),
) -> AdminLeagueWeekResponse:
    result = await uc.get_league_week(repo, week=_day(week, "week"), now=now)
    return AdminLeagueWeekResponse.model_validate(result)


@router.post("/members/{member_id}/remove", response_model=AdminLeagueMemberResponse)
async def remove_league_member(
    member_id: str,
    body: RemoveMemberRequest,
    repo: SqlAlchemyLeagueRepository = Depends(_repo),
    access: AdminAccess = Depends(require_super_admin),
    now: datetime = Depends(get_now),
) -> AdminLeagueMemberResponse:
    member = await uc.remove_member(
        repo, member_id, reason=body.reason, admin_email=access.email, now=now
    )
    return AdminLeagueMemberResponse.model_validate(member)


@router.post("/members/{member_id}/restore", response_model=AdminLeagueMemberResponse)
async def restore_league_member(
    member_id: str,
    repo: SqlAlchemyLeagueRepository = Depends(_repo),
    access: AdminAccess = Depends(require_super_admin),
    now: datetime = Depends(get_now),
) -> AdminLeagueMemberResponse:
    member = await uc.restore_member(repo, member_id, admin_email=access.email, now=now)
    return AdminLeagueMemberResponse.model_validate(member)


@router.put("/members/{member_id}/xp", response_model=AdminLeagueMemberResponse)
async def adjust_league_xp(
    member_id: str,
    body: AdjustXpRequest,
    repo: SqlAlchemyLeagueRepository = Depends(_repo),
    access: AdminAccess = Depends(require_super_admin),
    now: datetime = Depends(get_now),
) -> AdminLeagueMemberResponse:
    member = await uc.adjust_xp(
        repo,
        member_id,
        adjustment=body.adjustment,
        reason=body.reason,
        admin_email=access.email,
        now=now,
    )
    return AdminLeagueMemberResponse.model_validate(member)
