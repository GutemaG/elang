"""Migration test for bolt `021-categories-service` (ADR-11): upgrading a
database that already holds skills, users and progress preserves all of it,
puts the existing skills into "Foundations & Greetings", and the downgrade
restores the previous schema.

Runs Alembic in a subprocess against a throwaway SQLite file so nothing here
touches `dev.db` or the app's cached settings.
"""

from __future__ import annotations

import os
import sqlite3
import subprocess
import sys
import uuid
from pathlib import Path

import pytest

_BACKEND = Path(__file__).resolve().parents[2]
_PREVIOUS_HEAD = "c29bf2c53433"
_NEW_HEAD = "a7d1c5e29b04"
_FOUNDATIONS_ID = str(
    uuid.uuid5(
        uuid.uuid5(uuid.NAMESPACE_DNS, "buna.app/lesson-content"),
        "category:foundations-and-greetings",
    )
)


def _alembic(db_file: Path, *args: str) -> None:
    env = {**os.environ, "DATABASE_URL": f"sqlite+aiosqlite:///{db_file}"}
    result = subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=_BACKEND,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr


@pytest.fixture
def populated_db(tmp_path: Path) -> Path:
    """A database at the previous head with two skills, a user and progress."""
    db_file = tmp_path / "migration.db"
    _alembic(db_file, "upgrade", _PREVIOUS_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(
            "INSERT INTO skills (id, title, order_index, created_at) VALUES "
            "('skill-a', 'Greetings & Basics', 1, '2026-01-01'),"
            "('skill-b', 'Food & Drink', 2, '2026-01-01')"
        )
        conn.execute(
            "INSERT INTO user_skill_progress "
            "(id, user_id, skill_id, unlocked, crown_level, completed_at, "
            "completed_lesson_ids_this_cycle, created_at) VALUES "
            "('p1', 'user-1', 'skill-a', 1, 2, '2026-01-02', '[]', '2026-01-01')"
        )
    return db_file


def _rows(db_file: Path, sql: str) -> list[tuple]:
    with sqlite3.connect(db_file) as conn:
        return conn.execute(sql).fetchall()


class TestUpgradeOnPopulatedDatabase:
    def test_existing_skills_are_backfilled_into_foundations(self, populated_db: Path) -> None:
        _alembic(populated_db, "upgrade", _NEW_HEAD)

        assert _rows(populated_db, "SELECT id, title, order_index FROM categories") == [
            (_FOUNDATIONS_ID, "Foundations & Greetings", 1)
        ]
        assert _rows(
            populated_db, "SELECT id, category_id, order_index FROM skills ORDER BY id"
        ) == [
            ("skill-a", _FOUNDATIONS_ID, 1),
            ("skill-b", _FOUNDATIONS_ID, 2),
        ]

    def test_existing_progress_is_untouched(self, populated_db: Path) -> None:
        before = _rows(populated_db, "SELECT * FROM user_skill_progress")

        _alembic(populated_db, "upgrade", _NEW_HEAD)

        assert _rows(populated_db, "SELECT * FROM user_skill_progress") == before

    def test_two_categories_may_now_reuse_the_same_skill_order_index(
        self, populated_db: Path
    ) -> None:
        _alembic(populated_db, "upgrade", _NEW_HEAD)

        with sqlite3.connect(populated_db) as conn:
            conn.execute(
                "INSERT INTO categories (id, title, subtitle, order_index, created_at) "
                "VALUES ('cat-2', 'Family', 'x', 2, '2026-01-01')"
            )
            conn.execute(
                "INSERT INTO skills (id, category_id, title, order_index, created_at) "
                "VALUES ('skill-c', 'cat-2', 'Family 1', 1, '2026-01-01')"
            )

        assert _rows(populated_db, "SELECT COUNT(*) FROM skills") == [(3,)]

    def test_a_skill_without_a_category_is_rejected(self, populated_db: Path) -> None:
        _alembic(populated_db, "upgrade", _NEW_HEAD)

        with sqlite3.connect(populated_db) as conn, pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "INSERT INTO skills (id, title, order_index, created_at) "
                "VALUES ('orphan', 'Orphan', 9, '2026-01-01')"
            )


class TestUpgradeOnEmptyDatabase:
    def test_a_fresh_database_upgrades_to_head(self, tmp_path: Path) -> None:
        db_file = tmp_path / "fresh.db"

        _alembic(db_file, "upgrade", "head")

        assert _rows(db_file, "SELECT COUNT(*) FROM skills") == [(0,)]
        assert _rows(db_file, "SELECT COUNT(*) FROM categories") == [(1,)]


class TestDowngrade:
    def test_downgrade_round_trip_restores_skills_and_drops_categories(
        self, populated_db: Path
    ) -> None:
        _alembic(populated_db, "upgrade", _NEW_HEAD)

        _alembic(populated_db, "downgrade", _PREVIOUS_HEAD)

        assert _rows(populated_db, "SELECT id, title, order_index FROM skills ORDER BY id") == [
            ("skill-a", "Greetings & Basics", 1),
            ("skill-b", "Food & Drink", 2),
        ]
        tables = {
            r[0] for r in _rows(populated_db, "SELECT name FROM sqlite_master WHERE type='table'")
        }
        assert "categories" not in tables
        skill_columns = {r[1] for r in _rows(populated_db, "PRAGMA table_info(skills)")}
        assert "category_id" not in skill_columns
