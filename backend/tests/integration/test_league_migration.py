"""Migration test for bolt 073 (023-weekly-leagues): the league tables,
`users.first_name` and the `league_reward` Amole source arrive with no
backfill, and the downgrade removes them while keeping users. Runs Alembic
in a subprocess against a throwaway SQLite file, like
`test_settings_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from tests.integration.test_courses_migration import _EN_AM_ID, _ok

_NEW_HEAD = "d3a7f2b9c6e1"


_PREVIOUS_HEAD = "c8e1f4a7b2d5"
_INSERT_USER = (
    "INSERT INTO users (id, auth_provider, provider_user_id, selected_language, "
    "daily_xp_target, notification_enabled, created_at, active_course_id) VALUES "
    "('user-1', 'google', 'sub-1', 'am', 40, 1, '2026-01-01', ?)"
)
_INSERT_REWARD = (
    "INSERT INTO amole_transactions (id, user_id, amount, source, reference_id, created_at) "
    "VALUES ('t-1', 'user-1', 100, 'league_reward', 'group-1:user-1', '2026-10-05')"
)


def _columns(db_file: Path, table: str) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def test_upgrade_adds_leagues_with_no_backfill(tmp_path: Path) -> None:
    db_file = tmp_path / "leagues.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT_USER, (_EN_AM_ID,))

    _ok(db_file, "upgrade", _NEW_HEAD)

    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id, first_name FROM users").fetchall() == [("user-1", None)]
        assert conn.execute("SELECT COUNT(*) FROM league_groups").fetchone() == (0,)
        assert conn.execute("SELECT COUNT(*) FROM league_members").fetchone() == (0,)
        conn.execute(_INSERT_REWARD)  # The new Amole source is accepted.
    assert {"week_start", "tier", "closed_at"} <= _columns(db_file, "league_groups")
    assert {"user_id", "week_start", "final_rank", "tier_after", "result_seen_at"} <= _columns(
        db_file, "league_members"
    )


def test_one_membership_per_learner_per_week_and_known_tiers_only(tmp_path: Path) -> None:
    db_file = tmp_path / "leagues.db"
    _ok(db_file, "upgrade", _NEW_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT_USER, (_EN_AM_ID,))
        for group in ("g-1", "g-2"):
            conn.execute(
                "INSERT INTO league_groups (id, week_start, tier, created_at) "
                "VALUES (?, '2026-10-05', 'green_bean', '2026-10-05')",
                (group,),
            )
        conn.execute(
            "INSERT INTO league_members (id, group_id, user_id, week_start, joined_at) "
            "VALUES ('m-1', 'g-1', 'user-1', '2026-10-05', '2026-10-05')"
        )
        with pytest.raises(sqlite3.IntegrityError, match="UNIQUE"):
            conn.execute(
                "INSERT INTO league_members (id, group_id, user_id, week_start, joined_at) "
                "VALUES ('m-2', 'g-2', 'user-1', '2026-10-05', '2026-10-06')"
            )
        with pytest.raises(sqlite3.IntegrityError, match="CHECK"):
            conn.execute(
                "INSERT INTO league_groups (id, week_start, tier, created_at) "
                "VALUES ('g-3', '2026-10-05', 'diamond', '2026-10-05')"
            )


def test_downgrade_removes_leagues_and_keeps_users(tmp_path: Path) -> None:
    db_file = tmp_path / "leagues.db"
    _ok(db_file, "upgrade", _NEW_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT_USER, (_EN_AM_ID,))
        conn.execute("UPDATE users SET first_name = 'Abebe'")
        conn.execute(_INSERT_REWARD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert "first_name" not in _columns(db_file, "users")
    assert not {"league_groups", "league_members"} & _tables(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id FROM users").fetchall() == [("user-1",)]
        assert conn.execute("SELECT COUNT(*) FROM amole_transactions").fetchone() == (0,)
        with pytest.raises(sqlite3.IntegrityError, match="CHECK"):
            conn.execute(_INSERT_REWARD)
