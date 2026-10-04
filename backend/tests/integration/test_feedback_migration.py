"""Migration test: the `feedback` table (027-learner-feedback) arrives empty
and the downgrade removes it. Runs Alembic in a subprocess against a
throwaway SQLite file, like `test_languages_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _ok

_PREVIOUS_HEAD = "e7c4a2d9f1b3"
_NEW_HEAD = "b6f2d8a4c1e9"


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def test_upgrade_adds_an_empty_feedback_table(tmp_path: Path) -> None:
    db_file = tmp_path / "feedback.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert "feedback" in _tables(db_file)
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT COUNT(*) FROM feedback").fetchone() == (0,)


def test_downgrade_removes_the_table(tmp_path: Path) -> None:
    db_file = tmp_path / "feedback.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert "feedback" not in _tables(db_file)
    assert "languages" in _tables(db_file)
