"""Migration test: draft exercises and where published lessons went
(bolt 085), added to the curriculum tables and taken away again, keeping
their rows. Runs Alembic in a subprocess against a throwaway SQLite file.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _alembic, _ok

_PREVIOUS_HEAD = "d8b3f6a2c4e1"
_NEW_HEAD = "e2c7a9d4b6f3"


def _columns(db_file: Path, table: str) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}


def test_there_is_a_single_head(tmp_path: Path) -> None:
    result = _alembic(tmp_path / "unused.db", "heads")
    assert result.returncode == 0, result.stderr
    assert result.stdout.split() == [_NEW_HEAD, "(head)"]


def test_upgrade_and_downgrade_keep_the_curriculum(tmp_path: Path) -> None:
    db_file = tmp_path / "curriculum.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    with sqlite3.connect(db_file) as conn:
        (course_id,) = conn.execute("SELECT id FROM courses LIMIT 1").fetchone()
        conn.execute(
            "INSERT INTO curriculum_entries (id, course_id, ref, kind, position, title,"
            " created_at, updated_at) VALUES ('e1', ?, 'S1', 'section', 1, 'One', 'now', 'now')",
            (course_id,),
        )

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert {"published_id", "published_exercise_ids", "published_at"} <= _columns(
        db_file, "curriculum_entries"
    )
    assert "vocab_item_id" in _columns(db_file, "curriculum_rows")
    assert "generated" in _columns(db_file, "curriculum_exercises")
    with sqlite3.connect(db_file) as conn:
        assert conn.execute(
            "SELECT ref, published_exercise_ids FROM curriculum_entries"
        ).fetchall() == [("S1", "[]")]

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert "published_id" not in _columns(db_file, "curriculum_entries")
    assert _columns(db_file, "curriculum_exercises") == set()
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT ref FROM curriculum_entries").fetchall() == [("S1",)]
