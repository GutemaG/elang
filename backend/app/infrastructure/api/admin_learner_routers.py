"""The admin site's learner pages and reports: `/api/v1/admin/learners*`
and `/api/v1/admin/reports` (`026-learner-reports`).

Admin-only through the router-level `require_admin`, as every admin route
is (ADR-16). Read-only: nothing here writes.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import admin_learner_use_cases as uc
from app.infrastructure.api.admin_learner_schemas import (
    AdminLearnerDetail,
    AdminLearnerPage,
    AdminReport,
)
from app.infrastructure.api.dependencies import require_admin
from app.infrastructure.db.admin_learner_repository import SqlAlchemyAdminLearnerRepository
from app.infrastructure.db.session import get_db_session

router = APIRouter(prefix="/api/v1/admin", tags=["admin"], dependencies=[Depends(require_admin)])


async def _repo(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyAdminLearnerRepository:
    return SqlAlchemyAdminLearnerRepository(session)


def get_now() -> datetime:
    """Overridable in tests, so "today" is a fixed day."""
    return datetime.now(UTC)


@router.get("/learners", response_model=AdminLearnerPage)
async def list_learners(
    search: str = Query(default="", max_length=100),
    course_id: str | None = Query(default=None),
    sort: str = Query(default="last_active"),
    order: str = Query(default="desc", pattern="^(asc|desc)$"),
    offset: int = Query(default=0),
    limit: int = Query(default=25),
    repo: SqlAlchemyAdminLearnerRepository = Depends(_repo),
    now: datetime = Depends(get_now),
) -> AdminLearnerPage:
    page = await uc.list_learners(
        repo,
        search=search,
        course_id=course_id,
        sort=sort,
        descending=order == "desc",
        offset=offset,
        limit=limit,
        now=now,
    )
    return AdminLearnerPage.model_validate(page)


@router.get("/learners/{user_id}", response_model=AdminLearnerDetail)
async def get_learner(
    user_id: str,
    repo: SqlAlchemyAdminLearnerRepository = Depends(_repo),
    now: datetime = Depends(get_now),
) -> AdminLearnerDetail:
    return AdminLearnerDetail.model_validate(await uc.get_learner(repo, user_id, now=now))


@router.get("/reports", response_model=AdminReport)
async def get_report(
    period: str = Query(default="week"),
    count: int | None = Query(default=None),
    end: date | None = Query(default=None),
    course_id: str | None = Query(default=None),
    repo: SqlAlchemyAdminLearnerRepository = Depends(_repo),
    now: datetime = Depends(get_now),
) -> AdminReport:
    report = await uc.get_report(
        repo, period=period, count=count, end=end, course_id=course_id, now=now
    )
    return AdminReport.model_validate(report)
