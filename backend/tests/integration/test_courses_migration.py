"""Migration test for bolt `024-courses-service` (ADR-12, ADR-13): upgrading a
database that already holds users, categories, vocab and progress preserves
all of it, puts everything into the English to Amharic course, and the
downgrade restores the previous schema.

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
_PREVIOUS_HEAD = "a7d1c5e29b04"
_NEW_HEAD = "b8e3f0a4c6d2"
_EN_AM_ID = str(
    uuid.uuid5(uuid.uuid5(uuid.NAMESPACE_DNS, "buna.app/lesson-content"), "course:en-am")
)


def _alembic(db_file: Path, *args: str) -> subprocess.CompletedProcess[str]:
    env = {**os.environ, "DATABASE_URL": f"sqlite+aiosqlite:///{db_file}"}
    return subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=_BACKEND,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def _ok(db_file: Path, *args: str) -> None:
    result = _alembic(db_file, *args)
    assert result.returncode == 0, result.stderr


def _rows(db_file: Path, sql: str) -> list[tuple]:
    with sqlite3.connect(db_file) as conn:
        return conn.execute(sql).fetchall()


@pytest.fixture
def populated_db(tmp_path: Path) -> Path:
    """A database at the previous head with a user, vocab, a skill, and
    progress of every kind."""
    db_file = tmp_path / "migration.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    with sqlite3.connect(db_file) as conn:
        conn.execute(
            "INSERT INTO users (id, auth_provider, provider_user_id, selected_language, "
            "daily_xp_target, notification_enabled, created_at) VALUES "
            "('user-1', 'google', 'sub-1', 'am', 40, 1, '2026-01-01')"
        )
        conn.execute(
            "INSERT INTO vocab_items (id, word, translation, created_at) VALUES "
            "('v1', 'x', 'Hello', '2026-01-01'), ('v2', 'y', 'Bye', '2026-01-01')"
        )
        conn.execute(
            "INSERT INTO skills (id, category_id, title, order_index, created_at) "
            "SELECT 'skill-a', id, 'Greetings', 1, '2026-01-01' FROM categories LIMIT 1"
        )
        conn.execute(
            "INSERT INTO user_skill_progress "
            "(id, user_id, skill_id, unlocked, crown_level, completed_at, "
            "completed_lesson_ids_this_cycle, created_at) VALUES "
            "('p1', 'user-1', 'skill-a', 1, 2, '2026-01-02', '[]', '2026-01-01')"
        )
        conn.execute(
            "INSERT INTO user_vocab_progress "
            "(user_id, vocab_item_id, box_level, next_review_at, last_seen_at) VALUES "
            "('user-1', 'v1', 2, '2026-02-01', '2026-01-01')"
        )
    return db_file


class TestUpgradeOnPopulatedDatabase:
    def test_english_to_amharic_is_created_as_an_available_course(self, populated_db: Path) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)

        assert _rows(
            populated_db,
            "SELECT id, learning_language, from_language, title, status, order_index FROM courses",
        ) == [(_EN_AM_ID, "am", "en", "English to Amharic", "available", 1)]

    def test_existing_categories_vocab_and_users_are_backfilled_into_it(
        self, populated_db: Path
    ) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)

        assert _rows(populated_db, "SELECT DISTINCT course_id FROM categories") == [(_EN_AM_ID,)]
        assert _rows(populated_db, "SELECT id, course_id FROM vocab_items ORDER BY id") == [
            ("v1", _EN_AM_ID),
            ("v2", _EN_AM_ID),
        ]
        assert _rows(populated_db, "SELECT id, active_course_id, selected_language FROM users") == [
            ("user-1", _EN_AM_ID, "am")
        ]

    def test_existing_progress_and_content_are_untouched(self, populated_db: Path) -> None:
        skills_before = _rows(populated_db, "SELECT * FROM skills")
        skill_progress_before = _rows(populated_db, "SELECT * FROM user_skill_progress")
        vocab_progress_before = _rows(populated_db, "SELECT * FROM user_vocab_progress")

        _ok(populated_db, "upgrade", _NEW_HEAD)

        assert _rows(populated_db, "SELECT * FROM skills") == skills_before
        assert _rows(populated_db, "SELECT * FROM user_skill_progress") == skill_progress_before
        assert _rows(populated_db, "SELECT * FROM user_vocab_progress") == vocab_progress_before

    def test_two_courses_may_now_reuse_the_same_category_order_index(
        self, populated_db: Path
    ) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)

        with sqlite3.connect(populated_db) as conn:
            conn.execute(
                "INSERT INTO courses (id, learning_language, from_language, title, status, "
                "order_index, created_at) VALUES "
                "('c2', 'om', 'am', 'Amharic to Afaan Oromo', 'available', 2, '2026-01-01')"
            )
            conn.execute(
                "INSERT INTO categories (id, course_id, title, subtitle, order_index, "
                "created_at) VALUES ('cat-x', 'c2', 'Foundations', 'x', 1, '2026-01-01')"
            )

        assert _rows(populated_db, "SELECT COUNT(*) FROM categories WHERE order_index = 1") == [
            (2,)
        ]

    def test_rows_that_break_the_course_rules_are_rejected(self, populated_db: Path) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)

        with sqlite3.connect(populated_db) as conn:
            with pytest.raises(sqlite3.IntegrityError):  # same language twice
                conn.execute(
                    "INSERT INTO courses (id, learning_language, from_language, title, "
                    "status, order_index, created_at) VALUES "
                    "('bad', 'am', 'am', 'x', 'available', 5, '2026-01-01')"
                )
            with pytest.raises(sqlite3.IntegrityError):  # duplicate pair
                conn.execute(
                    "INSERT INTO courses (id, learning_language, from_language, title, "
                    "status, order_index, created_at) VALUES "
                    "('dup', 'am', 'en', 'x', 'available', 6, '2026-01-01')"
                )
            with pytest.raises(sqlite3.IntegrityError):  # unknown status
                conn.execute(
                    "INSERT INTO courses (id, learning_language, from_language, title, "
                    "status, order_index, created_at) VALUES "
                    "('st', 'om', 'am', 'x', 'later', 7, '2026-01-01')"
                )

    def test_a_category_vocab_item_or_user_without_a_course_is_rejected(
        self, populated_db: Path
    ) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)

        with sqlite3.connect(populated_db) as conn:
            with pytest.raises(sqlite3.IntegrityError):
                conn.execute(
                    "INSERT INTO categories (id, title, subtitle, order_index, created_at) "
                    "VALUES ('orphan', 'x', 'x', 9, '2026-01-01')"
                )
            with pytest.raises(sqlite3.IntegrityError):
                conn.execute(
                    "INSERT INTO vocab_items (id, word, translation, created_at) "
                    "VALUES ('orphan', 'x', 'x', '2026-01-01')"
                )
            with pytest.raises(sqlite3.IntegrityError):
                conn.execute(
                    "INSERT INTO users (id, auth_provider, provider_user_id, selected_language, "
                    "daily_xp_target, notification_enabled, created_at) VALUES "
                    "('u2', 'google', 'sub-2', 'am', 40, 1, '2026-01-01')"
                )


class TestUpgradeOnEmptyDatabase:
    def test_a_fresh_database_upgrades_to_head_with_the_default_course(
        self, tmp_path: Path
    ) -> None:
        db_file = tmp_path / "fresh.db"

        _ok(db_file, "upgrade", "head")

        assert _rows(db_file, "SELECT id FROM courses") == [(_EN_AM_ID,)]
        assert _rows(db_file, "SELECT COUNT(*) FROM users") == [(0,)]


class TestDowngrade:
    def test_round_trip_restores_the_previous_schema_and_keeps_the_data(
        self, populated_db: Path
    ) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)

        _ok(populated_db, "downgrade", _PREVIOUS_HEAD)

        tables = {
            r[0] for r in _rows(populated_db, "SELECT name FROM sqlite_master WHERE type='table'")
        }
        assert "courses" not in tables
        for table, column in (
            ("categories", "course_id"),
            ("vocab_items", "course_id"),
            ("users", "active_course_id"),
        ):
            assert column not in {r[1] for r in _rows(populated_db, f"PRAGMA table_info({table})")}
        assert _rows(populated_db, "SELECT id, selected_language FROM users") == [("user-1", "am")]
        assert _rows(populated_db, "SELECT COUNT(*) FROM vocab_items") == [(2,)]
        assert _rows(populated_db, "SELECT COUNT(*) FROM user_skill_progress") == [(1,)]

    def test_upgrade_after_a_downgrade_works_again(self, populated_db: Path) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)
        _ok(populated_db, "downgrade", _PREVIOUS_HEAD)

        _ok(populated_db, "upgrade", _NEW_HEAD)

        assert _rows(populated_db, "SELECT active_course_id FROM users") == [(_EN_AM_ID,)]

    def test_downgrade_fails_loudly_when_two_courses_share_a_category_order(
        self, populated_db: Path
    ) -> None:
        _ok(populated_db, "upgrade", _NEW_HEAD)
        with sqlite3.connect(populated_db) as conn:
            conn.execute(
                "INSERT INTO courses (id, learning_language, from_language, title, status, "
                "order_index, created_at) VALUES "
                "('c2', 'om', 'am', 'Amharic to Afaan Oromo', 'available', 2, '2026-01-01')"
            )
            conn.execute(
                "INSERT INTO categories (id, course_id, title, subtitle, order_index, "
                "created_at) VALUES ('cat-x', 'c2', 'Foundations', 'x', 1, '2026-01-01')"
            )

        result = _alembic(populated_db, "downgrade", _PREVIOUS_HEAD)

        assert result.returncode != 0
