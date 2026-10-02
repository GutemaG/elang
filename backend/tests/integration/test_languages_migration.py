"""Migration test: the `languages` table arrives holding Ethiopia's main
languages and English -- every code an existing course uses among them --
and the downgrade removes it. Runs Alembic in a subprocess against a
throwaway SQLite file, like `test_league_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _alembic, _ok

_PREVIOUS_HEAD = "d3a7f2b9c6e1"
_NEW_HEAD = "e7c4a2d9f1b3"


def test_there_is_a_single_head(tmp_path: Path) -> None:
    result = _alembic(tmp_path / "unused.db", "heads")
    assert result.returncode == 0, result.stderr
    assert result.stdout.split() == [_NEW_HEAD, "(head)"]


def test_upgrade_adds_the_languages_every_course_uses(tmp_path: Path) -> None:
    db_file = tmp_path / "languages.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)

    _ok(db_file, "upgrade", _NEW_HEAD)

    with sqlite3.connect(db_file) as conn:
        rows = dict(
            (code, (name, native))
            for code, name, native in conn.execute("SELECT code, name, native_name FROM languages")
        )
        used = {
            code
            for pair in conn.execute("SELECT learning_language, from_language FROM courses")
            for code in pair
        }
    assert len(rows) == 16
    assert rows["am"] == ("Amharic", "አማርኛ")
    assert rows["om"] == ("Afaan Oromo", "Afaan Oromoo")
    assert rows["en"] == ("English", "English")
    assert {"ti", "so", "aa", "sid", "wal"} <= rows.keys()
    assert used <= rows.keys()


def test_downgrade_removes_the_table(tmp_path: Path) -> None:
    db_file = tmp_path / "languages.db"
    _ok(db_file, "upgrade", _NEW_HEAD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    with sqlite3.connect(db_file) as conn:
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    assert "languages" not in tables
    assert "courses" in tables
