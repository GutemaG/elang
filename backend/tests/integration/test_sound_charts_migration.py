"""Migration test: the Sounds tables arrive empty and the downgrade removes
them. Runs Alembic in a subprocess against a throwaway SQLite file, like
`test_feedback_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _alembic, _ok

_PREVIOUS_HEAD = "b6f2d8a4c1e9"
_NEW_HEAD = "a9d4e6f2c8b1"


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def test_there_is_a_single_head(tmp_path: Path) -> None:
    result = _alembic(tmp_path / "unused.db", "heads")
    assert result.returncode == 0, result.stderr
    assert result.stdout.split() == [_NEW_HEAD, "(head)"]


def test_upgrade_adds_empty_sound_tables(tmp_path: Path) -> None:
    db_file = tmp_path / "sounds.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert {"sound_charts", "sound_letters"} <= _tables(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT COUNT(*) FROM sound_charts").fetchone() == (0,)
        assert conn.execute("SELECT COUNT(*) FROM sound_letters").fetchone() == (0,)


def test_downgrade_removes_them(tmp_path: Path) -> None:
    db_file = tmp_path / "sounds.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert not {"sound_charts", "sound_letters"} & _tables(db_file)
    assert "feedback" in _tables(db_file)
