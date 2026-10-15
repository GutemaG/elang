"""Response schemas for the admin activity log (intent 030):
`GET /api/v1/admin/activity`."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class ActivityEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    admin_email: str
    admin_role: str
    method: str
    route: str
    area: str
    action: str
    target_kind: str | None
    target_id: str | None
    target_name: str | None
    course_id: str | None
    link: str | None
    details: dict[str, Any]


class ActivityCourse(BaseModel):
    id: str
    title: str


class ActivityPageResponse(BaseModel):
    items: list[ActivityEntryResponse]
    total: int
    next_cursor: str | None
    admins: list[str]
    areas: list[str]
    courses: list[ActivityCourse]
