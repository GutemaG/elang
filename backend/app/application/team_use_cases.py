"""The Team page (intent 028): who may sign in to the admin site, and which
courses each course admin works on.

Owners come from `ADMIN_EMAILS` and are listed but never changed here.
Nobody changes their own access, so the owners always remain super
admins: the site can't lock itself out.
"""

from __future__ import annotations

import logging
import re
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime

from app.domain.admin import ADMIN_ROLES, SUPER_ADMIN, AdminAccess, AdminMember, normalise_email
from app.domain.lesson.exceptions import (
    AdminMemberExistsError,
    AdminMemberSelfError,
    ContentNotFoundError,
    InvalidContentError,
)
from app.infrastructure.db.admin_member_repository import SqlAlchemyAdminMemberRepository

logger = logging.getLogger("app.admin")

_EMAIL = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")


@dataclass(frozen=True)
class TeamMember:
    """A row of the Team page. `member` is None for an owner."""

    email: str
    role: str
    is_owner: bool
    courses: list[tuple[str, str]]  # (id, title), by title
    last_signed_in_at: datetime | None
    member: AdminMember | None = None


def _log(admin: str, action: str, member_id: str, role: str, courses: int) -> None:
    logger.info(
        "admin_write action=%s entity=admin_member id=%s role=%s courses=%d admin=%s",
        action,
        member_id,
        role,
        courses,
        admin,
    )


async def _rows(
    repo: SqlAlchemyAdminMemberRepository,
    owners: Iterable[str],
    members: list[AdminMember],
) -> list[TeamMember]:
    owners = sorted(owners)
    emails = [*owners, *(m.email for m in members)]
    signed_in = await repo.last_sign_ins(emails)
    titles = await repo.course_titles({c for m in members for c in m.course_ids})
    rows = [TeamMember(e, SUPER_ADMIN, True, [], signed_in.get(e)) for e in owners]
    for m in members:
        if m.email in owners:
            continue  # an owner's stored row is ignored (FR-1)
        courses = sorted(((c, titles[c]) for c in m.course_ids if c in titles), key=lambda x: x[1])
        rows.append(TeamMember(m.email, m.role, False, courses, signed_in.get(m.email), m))
    return rows


async def list_team(
    repo: SqlAlchemyAdminMemberRepository, owners: frozenset[str]
) -> list[TeamMember]:
    """Owners first, then members, each by email."""
    return await _rows(repo, owners, await repo.list_all())


async def _one(repo: SqlAlchemyAdminMemberRepository, member: AdminMember) -> TeamMember:
    (row,) = await _rows(repo, (), [member])
    return row


def _role(role: str) -> str:
    if role not in ADMIN_ROLES:
        raise InvalidContentError("role", "Choose super admin or course admin")
    return role


async def _courses(
    repo: SqlAlchemyAdminMemberRepository, role: str, course_ids: list[str]
) -> list[str]:
    if role == SUPER_ADMIN:
        if course_ids:
            raise InvalidContentError("course_ids", "A super admin has every course")
        return []
    wanted = set(course_ids)
    if wanted - await repo.existing_course_ids(wanted):
        raise InvalidContentError("course_ids", "A chosen course no longer exists")
    return sorted(wanted)


async def _member_or_404(
    repo: SqlAlchemyAdminMemberRepository, access: AdminAccess, member_id: str
) -> AdminMember:
    member = await repo.get(member_id)
    if member is None:
        raise ContentNotFoundError("No such admin", entity="admin_member", id=member_id)
    if member.email == access.email:
        raise AdminMemberSelfError("You can't change your own access. Ask another super admin.")
    return member


async def add_member(
    repo: SqlAlchemyAdminMemberRepository,
    access: AdminAccess,
    owners: frozenset[str],
    *,
    email: str,
    role: str,
    course_ids: list[str],
) -> TeamMember:
    address = normalise_email(email)
    if not _EMAIL.fullmatch(address):
        raise InvalidContentError("email", "Enter an email address")
    if address in owners:
        raise AdminMemberExistsError(f"{address} is an owner already", field="email")
    role = _role(role)
    courses = await _courses(repo, role, course_ids)
    member = await repo.add(address, role, courses, admin=access.email)
    _log(access.email, "add", member.id, role, len(courses))
    return await _one(repo, member)


async def update_member(
    repo: SqlAlchemyAdminMemberRepository,
    access: AdminAccess,
    member_id: str,
    *,
    role: str,
    course_ids: list[str],
) -> TeamMember:
    await _member_or_404(repo, access, member_id)
    role = _role(role)
    courses = await _courses(repo, role, course_ids)
    member = await repo.update(member_id, role, courses, admin=access.email)
    assert member is not None
    _log(access.email, "update", member_id, role, len(courses))
    return await _one(repo, member)


async def remove_member(
    repo: SqlAlchemyAdminMemberRepository, access: AdminAccess, member_id: str
) -> None:
    member = await _member_or_404(repo, access, member_id)
    await repo.remove(member_id)
    _log(access.email, "remove", member_id, member.role, len(member.course_ids))
