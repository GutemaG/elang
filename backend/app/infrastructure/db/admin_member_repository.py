"""Reads and writes the team (`admin_member_models.py`, intent 028). Hands
back domain `AdminMember`s.

No validation here: the Team use cases check roles and courses, and the
table's check constraint refuses a bad role whatever happens. The
repository flushes; the use case commits.

SQLite runs without foreign keys in development, so the cascades are
done here too: removing a member, making them a super admin, or
forgetting a course deletes the course rows itself. Course ids are read
joined to `courses`, so a row left behind can never count.
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable
from datetime import UTC, datetime

from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.admin import SUPER_ADMIN, AdminMember, normalise_email
from app.domain.lesson.exceptions import AdminMemberExistsError
from app.infrastructure.db.admin_member_models import AdminMemberCourseModel, AdminMemberModel
from app.infrastructure.db.lesson_models import CourseModel
from app.infrastructure.db.models import AuthSessionModel, UserModel


def _utc(value: datetime) -> datetime:
    """SQLite hands timestamps back without a zone; they were saved in UTC."""
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def _member(row: AdminMemberModel, course_ids: Iterable[str]) -> AdminMember:
    return AdminMember(
        id=row.id,
        email=row.email,
        role=row.role,
        course_ids=frozenset(course_ids),
        created_by=row.created_by,
        created_at=_utc(row.created_at),
        updated_by=row.updated_by,
        updated_at=_utc(row.updated_at),
    )


class SqlAlchemyAdminMemberRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def _course_ids(self, member_ids: list[str]) -> dict[str, set[str]]:
        """member id -> the ids of its courses that still exist."""
        found: dict[str, set[str]] = defaultdict(set)
        if not member_ids:
            return found
        stmt = (
            select(AdminMemberCourseModel.member_id, AdminMemberCourseModel.course_id)
            .join(CourseModel, CourseModel.id == AdminMemberCourseModel.course_id)
            .where(AdminMemberCourseModel.member_id.in_(member_ids))
        )
        for member_id, course_id in (await self._session.execute(stmt)).all():
            found[member_id].add(course_id)
        return found

    async def _one(self, row: AdminMemberModel | None) -> AdminMember | None:
        if row is None:
            return None
        return _member(row, (await self._course_ids([row.id]))[row.id])

    async def find_by_email(self, email: str) -> AdminMember | None:
        stmt = select(AdminMemberModel).where(AdminMemberModel.email == normalise_email(email))
        return await self._one((await self._session.execute(stmt)).scalar_one_or_none())

    async def get(self, member_id: str) -> AdminMember | None:
        return await self._one(await self._session.get(AdminMemberModel, member_id))

    async def list_all(self) -> list[AdminMember]:
        """Every member by email, with their courses, in two queries."""
        rows = list(
            (
                await self._session.execute(
                    select(AdminMemberModel).order_by(AdminMemberModel.email)
                )
            ).scalars()
        )
        courses = await self._course_ids([r.id for r in rows])
        return [_member(r, courses[r.id]) for r in rows]

    async def _set_courses(self, member_id: str, role: str, course_ids: Iterable[str]) -> None:
        await self._session.execute(
            delete(AdminMemberCourseModel).where(AdminMemberCourseModel.member_id == member_id)
        )
        if role == SUPER_ADMIN:
            return
        self._session.add_all(
            AdminMemberCourseModel(member_id=member_id, course_id=c) for c in set(course_ids)
        )

    async def add(
        self, email: str, role: str, course_ids: Iterable[str], *, admin: str
    ) -> AdminMember:
        """Adds a member. An email already on the team is
        `AdminMemberExistsError`."""
        email = normalise_email(email)
        if await self.find_by_email(email) is not None:
            raise AdminMemberExistsError(f"{email} is already on the team", field="email")
        now = datetime.now(UTC)
        row = AdminMemberModel(
            email=email,
            role=role,
            created_by=admin,
            updated_by=admin,
            created_at=now,
            updated_at=now,
        )
        self._session.add(row)
        try:
            await self._session.flush()
        except IntegrityError as e:  # added by someone else meanwhile
            raise AdminMemberExistsError(f"{email} is already on the team", field="email") from e
        await self._set_courses(row.id, role, course_ids)
        await self._session.flush()
        member = await self.get(row.id)
        assert member is not None
        return member

    async def update(
        self, member_id: str, role: str, course_ids: Iterable[str], *, admin: str
    ) -> AdminMember | None:
        """Replaces a member's role and courses. None for an unknown id."""
        row = await self._session.get(AdminMemberModel, member_id)
        if row is None:
            return None
        row.role = role
        row.updated_by = admin
        row.updated_at = datetime.now(UTC)
        await self._set_courses(member_id, role, course_ids)
        await self._session.flush()
        return await self.get(member_id)

    async def remove(self, member_id: str) -> bool:
        """Removes a member and their courses. False for an unknown id."""
        row = await self._session.get(AdminMemberModel, member_id)
        if row is None:
            return False
        await self._session.execute(
            delete(AdminMemberCourseModel).where(AdminMemberCourseModel.member_id == member_id)
        )
        await self._session.delete(row)
        await self._session.flush()
        return True

    async def forget_course(self, course_id: str) -> None:
        """Takes a course off every member: called before it is deleted."""
        await self._session.execute(
            delete(AdminMemberCourseModel).where(AdminMemberCourseModel.course_id == course_id)
        )

    async def last_sign_ins(self, emails: Iterable[str]) -> dict[str, datetime]:
        """email -> the newest session issued to any account with it."""
        wanted = {normalise_email(e) for e in emails}
        if not wanted:
            return {}
        email = func.lower(UserModel.email)
        stmt = (
            select(email, func.max(AuthSessionModel.issued_at))
            .join(AuthSessionModel, AuthSessionModel.user_id == UserModel.id)
            .where(email.in_(wanted))
            .group_by(email)
        )
        return {e: _utc(at) for e, at in (await self._session.execute(stmt)).all() if at}

    async def course_titles(self, course_ids: Iterable[str]) -> dict[str, str]:
        ids = set(course_ids)
        if not ids:
            return {}
        stmt = select(CourseModel.id, CourseModel.title).where(CourseModel.id.in_(ids))
        return {i: title for i, title in (await self._session.execute(stmt)).all()}

    async def existing_course_ids(self, course_ids: Iterable[str]) -> set[str]:
        return set(await self.course_titles(course_ids))
