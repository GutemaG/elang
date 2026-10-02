"""Learner feedback (027-learner-feedback): a learner sends it from the
app; the admin site lists it and marks it resolved.

The course is the learner's current course when they send it, read from
their account rather than from the app.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from app.domain.entities import User
from app.domain.lesson.exceptions import (
    ContentNotFoundError,
    InvalidFeedbackError,
    InvalidRangeError,
    TooMuchFeedbackError,
)
from app.infrastructure.db.feedback_models import FeedbackModel
from app.infrastructure.db.feedback_repository import FeedbackRow, SqlAlchemyFeedbackRepository

CATEGORIES = ("bug", "idea", "content", "other")
STATUSES = ("open", "resolved")
MAX_MESSAGE = 2000
# More than this from one learner in 24 hours is refused.
DAILY_LIMIT = 20
MAX_PAGE = 100
_PLATFORM = re.compile(r"^[a-z]{1,16}$")


def _as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


@dataclass(frozen=True)
class SentFeedback:
    id: str
    created_at: datetime


async def submit_feedback(
    repo: SqlAlchemyFeedbackRepository,
    *,
    user: User,
    category: str,
    message: str,
    rating: int | None,
    platform: str | None,
    now: datetime,
) -> SentFeedback:
    text = message.strip()
    if category not in CATEGORIES:
        raise InvalidFeedbackError(f"Category must be one of {', '.join(CATEGORIES)}")
    if not text:
        raise InvalidFeedbackError("Write a message")
    if len(text) > MAX_MESSAGE:
        raise InvalidFeedbackError(f"A message is at most {MAX_MESSAGE} characters")
    if rating is not None and not 1 <= rating <= 5:
        raise InvalidFeedbackError("A rating is 1 to 5")
    if await repo.count_since(user.id, now - timedelta(days=1)) >= DAILY_LIMIT:
        raise TooMuchFeedbackError("Thanks! That is plenty of feedback for today")
    clean_platform = (platform or "").strip().lower()
    saved = await repo.add(
        FeedbackModel(
            user_id=user.id,
            category=category,
            rating=rating,
            message=text,
            course_id=user.active_course_id,
            platform=clean_platform if _PLATFORM.match(clean_platform) else None,
            status="open",
            created_at=now,
        )
    )
    return SentFeedback(id=saved.id, created_at=_as_utc(saved.created_at))


@dataclass(frozen=True)
class FeedbackItem:
    id: str
    category: str
    rating: int | None
    message: str
    status: str
    platform: str | None
    created_at: datetime
    resolved_at: datetime | None
    learner_id: str
    learner_name: str
    learner_email: str | None
    course_id: str | None
    course_title: str | None


@dataclass(frozen=True)
class FeedbackPage:
    items: list[FeedbackItem]
    # How many match the filters.
    total: int
    # The rest are across all feedback.
    open: int
    resolved: int
    rated: int
    average_rating: float | None
    open_by_category: dict[str, int]


def _item(row: FeedbackRow) -> FeedbackItem:
    f, u = row.feedback, row.user
    return FeedbackItem(
        id=f.id,
        category=f.category,
        rating=f.rating,
        message=f.message,
        status=f.status,
        platform=f.platform,
        created_at=_as_utc(f.created_at),
        resolved_at=None if f.resolved_at is None else _as_utc(f.resolved_at),
        learner_id=u.id,
        learner_name=u.first_name or (u.email or "").split("@")[0] or "Learner",
        learner_email=u.email,
        course_id=f.course_id,
        course_title=row.course_title,
    )


async def list_feedback(
    repo: SqlAlchemyFeedbackRepository,
    *,
    status: str | None,
    category: str | None,
    user_id: str | None,
    search: str,
    offset: int,
    limit: int,
) -> FeedbackPage:
    if status is not None and status not in STATUSES:
        raise InvalidRangeError(f"Status must be one of {', '.join(STATUSES)}")
    if category is not None and category not in CATEGORIES:
        raise InvalidRangeError(f"Category must be one of {', '.join(CATEGORIES)}")
    if offset < 0 or not 1 <= limit <= MAX_PAGE:
        raise InvalidRangeError(f"Pages start at 0 and hold 1 to {MAX_PAGE}")
    rows, total = await repo.list(
        status=status,
        category=category,
        user_id=user_id,
        search=search.strip(),
        offset=offset,
        limit=limit,
    )
    counts = await repo.counts()
    return FeedbackPage(
        items=[_item(r) for r in rows],
        total=total,
        open=counts.open,
        resolved=counts.resolved,
        rated=counts.rated,
        average_rating=counts.average_rating,
        open_by_category={c: counts.open_by_category.get(c, 0) for c in CATEGORIES},
    )


async def set_feedback_status(
    repo: SqlAlchemyFeedbackRepository, feedback_id: str, *, status: str, now: datetime
) -> None:
    if status not in STATUSES:
        raise InvalidRangeError(f"Status must be one of {', '.join(STATUSES)}")
    feedback = await repo.get(feedback_id)
    if feedback is None:
        raise ContentNotFoundError(f"No feedback has id '{feedback_id}'")
    if feedback.status != status:
        feedback.status = status
        feedback.resolved_at = now if status == "resolved" else None
