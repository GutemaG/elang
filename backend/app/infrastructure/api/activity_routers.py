"""The admin activity log's API (intent 030): `GET /api/v1/admin/activity`.
Super admins only, through the router-level `require_super_admin`.
Entries are written by `require_admin` itself, for every admin write route.
"""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import activity_use_cases as uc
from app.domain.lesson.exceptions import InvalidContentError
from app.infrastructure.api.activity_schemas import (
    ActivityCourse,
    ActivityEntryResponse,
    ActivityPageResponse,
)
from app.infrastructure.api.dependencies import require_super_admin
from app.infrastructure.db.activity_repository import SqlAlchemyActivityRepository
from app.infrastructure.db.session import get_db_session

router = APIRouter(
    prefix="/api/v1/admin/activity",
    tags=["admin"],
    dependencies=[Depends(require_super_admin)],
)


async def _repo(session: AsyncSession = Depends(get_db_session)) -> SqlAlchemyActivityRepository:
    return SqlAlchemyActivityRepository(session)


def _day(value: str | None, field: str) -> date | None:
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError as e:
        raise InvalidContentError(field, "Use a date like 2026-10-12") from e


@router.get("", response_model=ActivityPageResponse)
async def list_activity(
    admin: str | None = Query(default=None, max_length=320),
    area: str | None = Query(default=None, max_length=32),
    course_id: str | None = Query(default=None, max_length=36),
    since: str | None = Query(default=None, max_length=10),
    until: str | None = Query(default=None, max_length=10),
    search: str = Query(default="", max_length=100),
    cursor: str | None = Query(default=None, max_length=100),
    repo: SqlAlchemyActivityRepository = Depends(_repo),
) -> ActivityPageResponse:
    page = await uc.list_activity(
        repo,
        admin_email=admin,
        area=area or None,
        course_id=course_id,
        since=_day(since, "since"),
        until=_day(until, "until"),
        search=search,
        cursor=cursor,
    )
    return ActivityPageResponse(
        items=[ActivityEntryResponse.model_validate(e) for e in page.items],
        total=page.total,
        next_cursor=page.next_cursor,
        admins=page.admins,
        areas=page.areas,
        courses=[ActivityCourse(id=i, title=t) for i, t in page.courses],
    )
