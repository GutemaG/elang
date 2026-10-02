"""Learner feedback (027-learner-feedback): the app sends it to
`POST /api/v1/feedback`; the admin site reads it from
`GET /api/v1/admin/feedback` and marks it resolved with
`PATCH /api/v1/admin/feedback/{id}`. The admin routes are admin-only
through the router-level `require_admin`, as every admin route is (ADR-16).
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import feedback_use_cases as uc
from app.domain.entities import User
from app.infrastructure.api.dependencies import get_current_user, require_admin
from app.infrastructure.api.feedback_schemas import (
    AdminFeedbackPage,
    FeedbackRequest,
    FeedbackSentResponse,
    FeedbackStatusRequest,
)
from app.infrastructure.db.feedback_repository import SqlAlchemyFeedbackRepository
from app.infrastructure.db.session import get_db_session

router = APIRouter(prefix="/api/v1/feedback", tags=["feedback"])
admin_router = APIRouter(
    prefix="/api/v1/admin/feedback", tags=["admin"], dependencies=[Depends(require_admin)]
)


async def _repo(session: AsyncSession = Depends(get_db_session)) -> SqlAlchemyFeedbackRepository:
    return SqlAlchemyFeedbackRepository(session)


def get_now() -> datetime:
    """Overridable in tests."""
    return datetime.now(UTC)


@router.post("", status_code=201, response_model=FeedbackSentResponse)
async def send_feedback(
    body: FeedbackRequest,
    user: User = Depends(get_current_user),
    repo: SqlAlchemyFeedbackRepository = Depends(_repo),
    now: datetime = Depends(get_now),
) -> FeedbackSentResponse:
    sent = await uc.submit_feedback(
        repo,
        user=user,
        category=body.category,
        message=body.message,
        rating=body.rating,
        platform=body.platform,
        now=now,
    )
    return FeedbackSentResponse.model_validate(sent)


@admin_router.get("", response_model=AdminFeedbackPage)
async def list_feedback(
    status: str | None = Query(default=None),
    category: str | None = Query(default=None),
    user_id: str | None = Query(default=None),
    search: str = Query(default="", max_length=100),
    offset: int = Query(default=0),
    limit: int = Query(default=25),
    repo: SqlAlchemyFeedbackRepository = Depends(_repo),
) -> AdminFeedbackPage:
    page = await uc.list_feedback(
        repo,
        status=status,
        category=category,
        user_id=user_id,
        search=search,
        offset=offset,
        limit=limit,
    )
    return AdminFeedbackPage.model_validate(page)


@admin_router.patch("/{feedback_id}", status_code=204)
async def set_feedback_status(
    feedback_id: str,
    body: FeedbackStatusRequest,
    repo: SqlAlchemyFeedbackRepository = Depends(_repo),
    now: datetime = Depends(get_now),
) -> Response:
    await uc.set_feedback_status(repo, feedback_id, status=body.status, now=now)
    return Response(status_code=204)
