"""Test helper (intent 028): puts admins on the team directly in a test
database, as the Team page will, so a test can sign in as one."""

from __future__ import annotations

import uuid
from collections.abc import Iterable
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import create_engine, delete, insert

from app.domain.admin import normalise_email
from app.infrastructure.db.admin_member_models import AdminMemberCourseModel, AdminMemberModel


def add_member(db_path: Path, email: str, role: str, course_ids: Iterable[str] = ()) -> str:
    """Adds a member and their courses; returns the member's id."""
    member_id = str(uuid.uuid4())
    now = datetime.now(UTC)
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        conn.execute(
            insert(AdminMemberModel).values(
                id=member_id,
                email=normalise_email(email),
                role=role,
                created_by="owner@example.com",
                updated_by="owner@example.com",
                created_at=now,
                updated_at=now,
            )
        )
        for course_id in course_ids:
            conn.execute(
                insert(AdminMemberCourseModel).values(member_id=member_id, course_id=course_id)
            )
    engine.dispose()
    return member_id


def remove_member(db_path: Path, member_id: str) -> None:
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        conn.execute(
            delete(AdminMemberCourseModel).where(AdminMemberCourseModel.member_id == member_id)
        )
        conn.execute(delete(AdminMemberModel).where(AdminMemberModel.id == member_id))
    engine.dispose()
