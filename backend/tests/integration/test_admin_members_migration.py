"""Migration test: the team tables (intent 028, bolt 101) arrive empty,
with the role check and the unique email, and the downgrade removes
them. Runs Alembic in a subprocess against a throwaway SQLite file, like
`test_voice_settings_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from tests.integration.test_courses_migration import _ok

_PREVIOUS_HEAD = "a3f7c2e9b1d4"
_NEW_HEAD = "c4e8a1f6d2b7"

_ADD = (
    "INSERT INTO admin_members (id, email, role, created_by, updated_by, created_at, updated_at)"
    " VALUES (?, ?, ?, 'owner@x.com', 'owner@x.com', '2026-10-13', '2026-10-13')"
)


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def test_upgrade_adds_empty_team_tables(tmp_path: Path) -> None:
    db_file = tmp_path / "team.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert {"admin_members", "admin_member_courses"} <= _tables(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT COUNT(*) FROM admin_members").fetchone() == (0,)
        assert conn.execute("SELECT COUNT(*) FROM admin_member_courses").fetchone() == (0,)


def test_the_migrated_table_refuses_an_unknown_role(tmp_path: Path) -> None:
    db_file = tmp_path / "team.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    with sqlite3.connect(db_file) as conn, pytest.raises(sqlite3.IntegrityError):
        conn.execute(_ADD, ("m1", "a@x.com", "editor"))


def test_the_migrated_table_refuses_a_second_row_for_an_email(tmp_path: Path) -> None:
    db_file = tmp_path / "team.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    with sqlite3.connect(db_file) as conn:
        conn.execute(_ADD, ("m1", "a@x.com", "course_admin"))
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(_ADD, ("m2", "a@x.com", "super_admin"))


def test_downgrade_removes_the_tables(tmp_path: Path) -> None:
    db_file = tmp_path / "team.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert not {"admin_members", "admin_member_courses"} & _tables(db_file)
    assert "voice_settings" in _tables(db_file)
