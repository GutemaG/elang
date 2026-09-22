"""Unit tests: the `ADMIN_EMAILS` rule (ADR-16, bolt 034-admin-api-foundation)."""

from __future__ import annotations

import pytest

from app.domain.admin import is_admin, parse_admin_emails


class TestParseAdminEmails:
    def test_trims_lowercases_and_drops_blanks(self) -> None:
        assert parse_admin_emails(" A@x.com, ,b@Y.com ,") == frozenset({"a@x.com", "b@y.com"})

    def test_empty_is_empty(self) -> None:
        assert parse_admin_emails("") == frozenset()


class TestIsAdmin:
    @pytest.mark.parametrize(
        ("email", "allow_list"),
        [
            ("admin@x.com", "admin@x.com"),
            ("Admin@X.com", "admin@x.com"),
            ("admin@x.com", "other@x.com, ADMIN@x.com "),
        ],
    )
    def test_listed_email_is_admin(self, email: str, allow_list: str) -> None:
        assert is_admin(email, allow_list) is True

    @pytest.mark.parametrize(
        ("email", "allow_list"),
        [
            ("admin@x.com", ""),  # fail closed: nobody is an admin
            ("admin@x.com", " , "),
            (None, "admin@x.com"),  # no verified email
            ("", "admin@x.com"),
            ("admin@x.co", "admin@x.com"),  # exact match, not a prefix
            ("someone@x.com", "admin@x.com"),
        ],
    )
    def test_anyone_else_is_not(self, email: str | None, allow_list: str) -> None:
        assert is_admin(email, allow_list) is False
