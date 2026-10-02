"""Request and response schemas for learner feedback (027-learner-feedback):
the app's `POST /api/v1/feedback` and the admin site's
`/api/v1/admin/feedback*`."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class FeedbackRequest(BaseModel):
    # `bug`, `idea`, `content` or `other`; checked by the use case so a
    # wrong one gets the feedback error, not a validation dump.
    category: str
    message: str
    rating: int | None = None
    platform: str | None = None


class FeedbackSentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime


class AdminFeedbackItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    category: str
    rating: int | None
    message: str
    status: Literal["open", "resolved"]
    platform: str | None
    created_at: datetime
    resolved_at: datetime | None
    learner_id: str
    learner_name: str
    learner_email: str | None
    course_id: str | None
    course_title: str | None


class AdminFeedbackPage(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    items: list[AdminFeedbackItem]
    total: int
    open: int
    resolved: int
    rated: int
    average_rating: float | None
    open_by_category: dict[str, int]


class FeedbackStatusRequest(BaseModel):
    status: Literal["open", "resolved"]
