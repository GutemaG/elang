"""Migration test: the activity log table and the league corrections
(intent 030) arrive empty, existing memberships get no adjustment, and the
downgrade removes them. Runs Alembic in a subprocess against a throwaway
SQLite file, like `test_admin_members_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _alembic, _ok

_PREVIOUS_HEAD = "c4e8a1f6d2b7"
_NEW_HEAD = "d7b3e9a2c5f1"


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def _columns(db_file: Path, table: str) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}


def test_there_is_a_single_head(tmp_path: Path) -> None:
    result = _alembic(tmp_path / "unused.db", "heads")
    assert result.returncode == 0, result.stderr
    assert result.stdout.split() == [_NEW_HEAD, "(head)"]


def test_upgrade_adds_the_log_and_keeps_memberships_unadjusted(tmp_path: Path) -> None:
    db_file = tmp_path / "activity.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(
            "INSERT INTO users (id, auth_provider, provider_user_id, selected_language,"
            " daily_xp_target, notification_enabled, created_at, active_course_id)"
            " SELECT 'u1', 'google', 's1', 'am', 40, 1, '2026-10-12', id FROM courses LIMIT 1"
        )
        conn.execute(
            "INSERT INTO league_groups (id, week_start, tier, created_at)"
            " VALUES ('g1', '2026-10-12', 'green_bean', '2026-10-12')"
        )
        conn.execute(
            "INSERT INTO league_members (id, group_id, user_id, week_start, joined_at)"
            " VALUES ('m1', 'g1', 'u1', '2026-10-12', '2026-10-12')"
        )

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert "admin_activity" in _tables(db_file)
    assert {"removed_at", "removed_reason", "xp_adjustment", "xp_adjustment_reason"} <= _columns(
        db_file, "league_members"
    )
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT COUNT(*) FROM admin_activity").fetchone() == (0,)
        assert conn.execute(
            "SELECT xp_adjustment, removed_at FROM league_members WHERE id = 'm1'"
        ).fetchone() == (0, None)


def test_downgrade_removes_them(tmp_path: Path) -> None:
    db_file = tmp_path / "activity.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert "admin_activity" not in _tables(db_file)
    assert "xp_adjustment" not in _columns(db_file, "league_members")
    assert "admin_members" in _tables(db_file)
