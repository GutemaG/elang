"""Unit tests: the `ADMIN_EMAILS` rule (ADR-16, bolt 034-admin-api-foundation)
and admin roles (intent 028, bolt 100)."""

from __future__ import annotations

import pytest

from app.domain.admin import (
    ADMIN_ROLES,
    COURSE_ADMIN,
    SUPER_ADMIN,
    AdminAccess,
    AdminMember,
    normalise_email,
    parse_admin_emails,
    resolve_access,
)


class TestParseAdminEmails:
    def test_trims_lowercases_and_drops_blanks(self) -> None:
        assert parse_admin_emails(" A@x.com, ,b@Y.com ,") == frozenset({"a@x.com", "b@y.com"})

    def test_empty_is_empty(self) -> None:
        assert parse_admin_emails("") == frozenset()


# --- intent 028 (bolt 100): owners, super admins and course admins ----------

OWNERS = parse_admin_emails("owner@x.com")


def _member(role: str, *courses: str, email: str = "helper@x.com") -> AdminMember:
    return AdminMember(id="m1", email=email, role=role, course_ids=frozenset(courses))


class TestNormaliseEmail:
    def test_trims_and_lowercases(self) -> None:
        assert normalise_email("  Helper@X.Com ") == "helper@x.com"


class TestRoles:
    def test_two_roles(self) -> None:
        assert ADMIN_ROLES == ("super_admin", "course_admin")


class TestResolveAccess:
    def test_nobody_is_an_owner_when_admin_emails_is_empty(self) -> None:
        # Fail closed: an empty or blank allow-list has no owners.
        assert resolve_access("owner@x.com", parse_admin_emails(" , "), None) is None

    def test_owner_is_super_admin_for_every_course(self) -> None:
        access = resolve_access(" Owner@X.com", OWNERS, None)
        assert access == AdminAccess(email="owner@x.com", role=SUPER_ADMIN, is_owner=True)

    def test_owner_wins_over_a_stored_row(self) -> None:
        stored = _member(COURSE_ADMIN, "c1", email="owner@x.com")
        access = resolve_access("owner@x.com", OWNERS, stored)
        assert access is not None
        assert access.is_owner and access.is_super and access.course_ids is None

    def test_stored_super_admin_has_every_course(self) -> None:
        access = resolve_access("helper@x.com", OWNERS, _member(SUPER_ADMIN))
        assert access == AdminAccess(email="helper@x.com", role=SUPER_ADMIN)

    def test_course_admin_has_their_courses(self) -> None:
        access = resolve_access("Helper@x.com", OWNERS, _member(COURSE_ADMIN, "c1", "c2"))
        assert access == AdminAccess(
            email="helper@x.com", role=COURSE_ADMIN, course_ids=frozenset({"c1", "c2"})
        )

    def test_course_admin_with_no_courses_is_still_an_admin(self) -> None:
        access = resolve_access("helper@x.com", OWNERS, _member(COURSE_ADMIN))
        assert access is not None and access.course_ids == frozenset()

    @pytest.mark.parametrize(
        "email",
        [None, "", "someone@x.com", "owner@x.co"],  # exact match, not a prefix
    )
    def test_anyone_else_is_nobody(self, email: str | None) -> None:
        assert resolve_access(email, OWNERS, None) is None

    def test_unknown_stored_role_is_nobody(self) -> None:
        assert resolve_access("helper@x.com", OWNERS, _member("editor")) is None


class TestAdminAccess:
    def test_super_admin_opens_any_course(self) -> None:
        access = AdminAccess(email="a@x.com", role=SUPER_ADMIN)
        assert access.is_super and access.can_open_course("anything")

    def test_course_admin_opens_only_theirs(self) -> None:
        access = AdminAccess(email="a@x.com", role=COURSE_ADMIN, course_ids=frozenset({"c1"}))
        assert not access.is_super
        assert access.can_open_course("c1")
        assert not access.can_open_course("c2")

    def test_course_admin_without_a_course_list_opens_nothing(self) -> None:
        # Fail closed: a course admin is never "every course".
        assert not AdminAccess(email="a@x.com", role=COURSE_ADMIN).can_open_course("c1")
