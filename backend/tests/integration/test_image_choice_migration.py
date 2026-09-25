"""Migration test for bolt `050-image-choice-service`: `b5e9d2c7a4f1` widens
`ck_exercises_type` to the two picture types. Runs Alembic in a subprocess
against a throwaway SQLite file, like `test_courses_migration.py`.

The single-head check lives with the newest migration; it moved here from
`test_user_email_migration.py`.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from tests.integration.test_courses_migration import _alembic, _ok

_PREVIOUS_HEAD = "a7d3c9e1f042"
_NEW_HEAD = "b5e9d2c7a4f1"


def test_there_is_a_single_head(tmp_path: Path) -> None:
    result = _alembic(tmp_path / "unused.db", "heads")
    assert result.returncode == 0, result.stderr
    assert result.stdout.split() == [_NEW_HEAD, "(head)"]


_INSERT = (
    "INSERT INTO exercises (id, lesson_id, order_index, type, prompt, content, answer_key, "
    "created_at, updated_at) VALUES (?, 'lesson-x', ?, ?, 'P', '{}', '{}', '2026-01-01', "
    "'2026-01-01')"
)


def _insert(db_file: Path, exercise_id: str, order: int, exercise_type: str) -> None:
    # Foreign keys are off in a bare sqlite3 connection, so only the type
    # check is under test here.
    with sqlite3.connect(db_file) as conn:
        conn.execute(_INSERT, (exercise_id, order, exercise_type))


@pytest.mark.parametrize("exercise_type", ["image_choice", "audio_image_choice"])
def test_the_previous_schema_refuses_the_picture_types(tmp_path: Path, exercise_type: str) -> None:
    db_file = tmp_path / "images.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)

    with pytest.raises(sqlite3.IntegrityError, match="ck_exercises_type"):
        _insert(db_file, "e1", 1, exercise_type)


def test_upgrade_allows_both_picture_types_and_keeps_the_others(tmp_path: Path) -> None:
    db_file = tmp_path / "images.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    _insert(db_file, "e0", 0, "spell_tiles")

    _ok(db_file, "upgrade", _NEW_HEAD)

    _insert(db_file, "e1", 1, "image_choice")
    _insert(db_file, "e2", 2, "audio_image_choice")
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id, type FROM exercises ORDER BY id").fetchall() == [
            ("e0", "spell_tiles"),
            ("e1", "image_choice"),
            ("e2", "audio_image_choice"),
        ]
        with pytest.raises(sqlite3.IntegrityError, match="ck_exercises_type"):
            conn.execute(_INSERT, ("e3", 3, "picture_choice"))


def test_downgrade_narrows_the_check_again(tmp_path: Path) -> None:
    db_file = tmp_path / "images.db"
    _ok(db_file, "upgrade", _NEW_HEAD)
    _insert(db_file, "e0", 0, "gap_fill")

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    with pytest.raises(sqlite3.IntegrityError, match="ck_exercises_type"):
        _insert(db_file, "e1", 1, "image_choice")
    with sqlite3.connect(db_file) as conn:
        assert conn.execute("SELECT id FROM exercises").fetchall() == [("e0",)]
