"""Migration test for bolt `034-admin-api-foundation` (ADR-16): `users.email`
is added as a nullable column that existing rows start without, and the
downgrade removes it again. Runs Alembic in a subprocess against a throwaway
SQLite file, like `test_courses_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _EN_AM_ID, _ok

_PREVIOUS_HEAD = "f4c2a81e7b56"
_NEW_HEAD = "a7d3c9e1f042"
_INSERT_USER = (
    "INSERT INTO users (id, auth_provider, provider_user_id, selected_language, "
    "daily_xp_target, notification_enabled, created_at, active_course_id) VALUES "
    "('user-1', 'google', 'sub-1', 'am', 40, 1, '2026-01-01', ?)"
)


def _user_columns(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {row[1] for row in conn.execute("PRAGMA table_info(users)")}


def test_upgrade_adds_a_null_email_and_keeps_users(tmp_path: Path) -> None:
    db_file = tmp_path / "email.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT_USER, (_EN_AM_ID,))

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert "email" in _user_columns(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id, email FROM users").fetchall() == [("user-1", None)]


def test_downgrade_removes_email_and_keeps_users(tmp_path: Path) -> None:
    db_file = tmp_path / "email.db"
    _ok(db_file, "upgrade", _NEW_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT_USER, (_EN_AM_ID,))
        conn.execute("UPDATE users SET email = 'a@example.com'")

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert "email" not in _user_columns(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id FROM users").fetchall() == [("user-1",)]
