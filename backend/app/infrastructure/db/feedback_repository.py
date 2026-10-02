"""Reads and writes learner feedback (027-learner-feedback). Every method
stays inside the caller's transaction -- nothing here commits."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.feedback_models import FeedbackModel
from app.infrastructure.db.lesson_models import CourseModel
from app.infrastructure.db.models import UserModel


@dataclass(frozen=True)
class FeedbackRow:
    feedback: FeedbackModel
    user: UserModel
    course_title: str | None


@dataclass(frozen=True)
class FeedbackCounts:
    open: int
    resolved: int
    rated: int
    average_rating: float | None
    open_by_category: dict[str, int]


class SqlAlchemyFeedbackRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add(self, feedback: FeedbackModel) -> FeedbackModel:
        self._session.add(feedback)
        await self._session.flush()
        return feedback

    async def count_since(self, user_id: str, since: datetime) -> int:
        stmt = select(func.count(FeedbackModel.id)).where(
            FeedbackModel.user_id == user_id, FeedbackModel.created_at >= since
        )
        return int((await self._session.execute(stmt)).scalar_one())

    async def get(self, feedback_id: str) -> FeedbackModel | None:
        return await self._session.get(FeedbackModel, feedback_id)

    async def list(
        self,
        *,
        status: str | None,
        category: str | None,
        user_id: str | None,
        search: str,
        offset: int,
        limit: int,
    ) -> tuple[list[FeedbackRow], int]:
        """Newest first, with the sender and the course's title, and how
        many match in all."""
        conditions = []
        if status:
            conditions.append(FeedbackModel.status == status)
        if category:
            conditions.append(FeedbackModel.category == category)
        if user_id:
            conditions.append(FeedbackModel.user_id == user_id)
        if search:
            pattern = f"%{search}%"
            conditions.append(
                or_(
                    FeedbackModel.message.ilike(pattern),
                    UserModel.email.ilike(pattern),
                    UserModel.first_name.ilike(pattern),
                )
            )
        base = (
            select(FeedbackModel, UserModel, CourseModel.title)
            .join(UserModel, UserModel.id == FeedbackModel.user_id)
            .outerjoin(CourseModel, CourseModel.id == FeedbackModel.course_id)
            .where(*conditions)
        )
        total_stmt = select(func.count()).select_from(base.subquery())
        total = int((await self._session.execute(total_stmt)).scalar_one())
        stmt = (
            base.order_by(FeedbackModel.created_at.desc(), FeedbackModel.id)
            .offset(offset)
            .limit(limit)
        )
        rows = [
            FeedbackRow(feedback=f, user=u, course_title=title)
            for f, u, title in (await self._session.execute(stmt)).all()
        ]
        return rows, total

    async def counts(self) -> FeedbackCounts:
        """Across all feedback, whatever the list shows."""
        by_status = dict(
            (
                await self._session.execute(
                    select(FeedbackModel.status, func.count(FeedbackModel.id)).group_by(
                        FeedbackModel.status
                    )
                )
            )
            .tuples()
            .all()
        )
        rated, average = (
            await self._session.execute(
                select(func.count(FeedbackModel.rating), func.avg(FeedbackModel.rating))
            )
        ).one()
        open_by_category = dict(
            (
                await self._session.execute(
                    select(FeedbackModel.category, func.count(FeedbackModel.id))
                    .where(FeedbackModel.status == "open")
                    .group_by(FeedbackModel.category)
                )
            )
            .tuples()
            .all()
        )
        return FeedbackCounts(
            open=by_status.get("open", 0),
            resolved=by_status.get("resolved", 0),
            rated=int(rated),
            average_rating=None if average is None else float(average),
            open_by_category=open_by_category,
        )
