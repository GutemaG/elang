"""Who may use the content admin API (ADR-16, bolt `034-admin-api-foundation`).

Intent 028 (bolt 100) adds roles. An **owner** is an email in
`ADMIN_EMAILS`: always a super admin, whatever the database says. Every
other admin is a stored `AdminMember`: a super admin, who reaches every
course, or a course admin, who reaches only the courses given to them.

Pure Python, no framework imports.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

SUPER_ADMIN = "super_admin"
COURSE_ADMIN = "course_admin"
ADMIN_ROLES = (SUPER_ADMIN, COURSE_ADMIN)


def normalise_email(email: str) -> str:
    """How every admin email is compared and stored: trimmed, lower-case."""
    return email.strip().lower()


def parse_admin_emails(allow_list: str) -> frozenset[str]:
    """`ADMIN_EMAILS` is comma-separated; entries are trimmed and compared
    case-insensitively. Blank entries are ignored."""
    return frozenset(normalise_email(e) for e in allow_list.split(",") if e.strip())


@dataclass(frozen=True)
class AdminMember:
    """An admin added on the Team page. A super admin's `course_ids` is
    empty: they reach every course without being given any."""

    id: str
    email: str
    role: str
    course_ids: frozenset[str] = frozenset()
    created_by: str | None = None
    created_at: datetime | None = None
    updated_by: str | None = None
    updated_at: datetime | None = None


@dataclass(frozen=True)
class AdminAccess:
    """What the signed-in admin may reach. `course_ids` is None for every
    course (owners and super admins)."""

    email: str
    role: str
    is_owner: bool = False
    course_ids: frozenset[str] | None = None

    @property
    def is_super(self) -> bool:
        return self.role == SUPER_ADMIN

    def can_open_course(self, course_id: str) -> bool:
        if self.is_super:
            return True
        return self.course_ids is not None and course_id in self.course_ids


def resolve_access(
    email: str | None, owners: frozenset[str], member: AdminMember | None
) -> AdminAccess | None:
    """The access of a signed-in `email`, given the owners (from
    `parse_admin_emails`) and the stored member found by that email, if
    any. An owner wins over a stored row. Anyone else is None."""
    if not email:
        return None
    email = normalise_email(email)
    if email in owners:
        return AdminAccess(email=email, role=SUPER_ADMIN, is_owner=True)
    if member is None:
        return None
    if member.role == SUPER_ADMIN:
        return AdminAccess(email=email, role=SUPER_ADMIN)
    if member.role == COURSE_ADMIN:
        return AdminAccess(email=email, role=COURSE_ADMIN, course_ids=member.course_ids)
    return None
