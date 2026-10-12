"""Migration test: the `voice_settings` table (intent 027, bolt 089)
arrives empty with its speed check, and the downgrade removes it. Runs
Alembic in a subprocess against a throwaway SQLite file, like
`test_feedback_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from tests.integration.test_courses_migration import _alembic, _ok

_PREVIOUS_HEAD = "e2c7a9d4b6f3"
_NEW_HEAD = "a3f7c2e9b1d4"


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def test_there_is_a_single_head(tmp_path: Path) -> None:
    result = _alembic(tmp_path / "unused.db", "heads")
    assert result.returncode == 0, result.stderr
    assert result.stdout.split() == [_NEW_HEAD, "(head)"]


def test_upgrade_adds_an_empty_voice_settings_table(tmp_path: Path) -> None:
    db_file = tmp_path / "voices.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert "voice_settings" in _tables(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT COUNT(*) FROM voice_settings").fetchone() == (0,)


def test_the_migrated_table_refuses_a_speed_over_100(tmp_path: Path) -> None:
    db_file = tmp_path / "voices.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    with sqlite3.connect(db_file) as conn, pytest.raises(sqlite3.IntegrityError):
        conn.execute(
            "INSERT INTO voice_settings (language, male_voice_id, female_voice_id, speed)"
            " VALUES ('am', 'am-simon', 'am-loza', 101)"
        )


def test_downgrade_removes_the_table(tmp_path: Path) -> None:
    db_file = tmp_path / "voices.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert "voice_settings" not in _tables(db_file)
    assert "curriculum_exercises" in _tables(db_file)
