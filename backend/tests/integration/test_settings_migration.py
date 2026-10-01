"""Migration test for bolt 071 (022-light-and-dark-themes, FR-8/FR-9):
`users.settings` arrives as `{}` for existing rows with no backfill,
`app_config` arrives empty, and the downgrade removes both while keeping
users. Runs Alembic in a subprocess against a throwaway SQLite file, like
`test_courses_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _EN_AM_ID, _ok

_PREVIOUS_HEAD = "b5e9d2c7a4f1"
_NEW_HEAD = "c8e1f4a7b2d5"
_INSERT_USER = (
    "INSERT INTO users (id, auth_provider, provider_user_id, selected_language, "
    "daily_xp_target, notification_enabled, created_at, active_course_id) VALUES "
    "('user-1', 'google', 'sub-1', 'am', 40, 1, '2026-01-01', ?)"
)


def _columns(db_file: Path, table: str) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def test_upgrade_gives_existing_users_empty_settings_and_an_empty_app_config(
    tmp_path: Path,
) -> None:
    db_file = tmp_path / "settings.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT_USER, (_EN_AM_ID,))

    _ok(db_file, "upgrade", _NEW_HEAD)

    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id, settings FROM users").fetchall() == [("user-1", "{}")]
        assert conn.execute("SELECT COUNT(*) FROM app_config").fetchone() == (0,)
    assert _columns(db_file, "app_config") == {"key", "value", "updated_at"}


def test_downgrade_removes_both_and_keeps_users(tmp_path: Path) -> None:
    db_file = tmp_path / "settings.db"
    _ok(db_file, "upgrade", _NEW_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT_USER, (_EN_AM_ID,))
        conn.execute("UPDATE users SET settings = ?", ('{"theme": "dark"}',))

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert "settings" not in _columns(db_file, "users")
    assert "app_config" not in _tables(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id FROM users").fetchall() == [("user-1",)]
