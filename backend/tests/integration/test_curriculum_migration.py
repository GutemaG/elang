"""Migration test: the draft curriculum tables are added empty and removed
again, leaving everything else alone. Runs Alembic in a subprocess against
a throwaway SQLite file, like `test_sound_kinds_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _ok

_PREVIOUS_HEAD = "c5e8a3f1d7b2"
_NEW_HEAD = "d8b3f6a2c4e1"


def _tables(db_file: Path) -> set[str]:
    with sqlite3.connect(db_file) as conn:
        return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def test_upgrade_adds_the_tables_and_downgrade_removes_them(tmp_path: Path) -> None:
    db_file = tmp_path / "curriculum.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    before = _tables(db_file)

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert _tables(db_file) - before == {"curriculum_entries", "curriculum_rows"}
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT COUNT(*) FROM curriculum_rows").fetchone() == (0,)
        columns = {r[1] for r in conn.execute("PRAGMA table_info(curriculum_rows)")}
    assert {"ref", "lesson_ref", "text", "blank", "status", "audio_url", "version"} <= columns

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert _tables(db_file) == before


def test_an_unknown_kind_is_refused(tmp_path: Path) -> None:
    db_file = tmp_path / "curriculum.db"
    _ok(db_file, "upgrade", _NEW_HEAD)
    with sqlite3.connect(db_file) as conn:
        (course_id,) = conn.execute("SELECT id FROM courses LIMIT 1").fetchone()
        conn.execute(
            "INSERT INTO curriculum_entries (id, course_id, ref, kind, position, title,"
            " created_at, updated_at) VALUES ('e1', ?, 'S1', 'section', 1, 'One', 'now', 'now')",
            (course_id,),
        )
        bad = None
        try:
            conn.execute(
                "INSERT INTO curriculum_entries (id, course_id, ref, kind, position, title,"
                " created_at, updated_at) VALUES ('e2', ?, 'S2', 'unit', 1, 'Two', 'now', 'now')",
                (course_id,),
            )
        except sqlite3.IntegrityError as error:
            bad = error
    assert bad is not None
