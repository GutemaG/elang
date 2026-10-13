"""Request and response bodies for the Team API (intent 028)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class TeamCourse(BaseModel):
    id: str
    title: str


class TeamMemberResponse(BaseModel):
    # None for an owner, who is set in `ADMIN_EMAILS`, not here.
    id: str | None
    email: str
    role: str
    is_owner: bool
    courses: list[TeamCourse]
    last_signed_in_at: datetime | None
    created_by: str | None
    created_at: datetime | None
    updated_by: str | None
    updated_at: datetime | None


class TeamResponse(BaseModel):
    members: list[TeamMemberResponse]


class AddMemberRequest(BaseModel):
    email: str
    # Plain strings, so a wrong value gets the Team page's own message.
    role: str
    course_ids: list[str] = []


class UpdateMemberRequest(BaseModel):
    role: str
    course_ids: list[str] = []
