"""Migration test: letters gain a kind, and a chart started from the old
Qubee template (vowels, long vowels, consonants, letter pairs, borrowed)
becomes A to Z, letter pairs and long vowels, keeping its letters and
recordings. Runs Alembic in a subprocess against a throwaway SQLite file,
like `test_sound_charts_migration.py`.
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from tests.integration.test_courses_migration import _ok

_PREVIOUS_HEAD = "a9d4e6f2c8b1"
_NEW_HEAD = "c5e8a3f1d7b2"

_OLD_GROUPS = [
    {"key": "vowels", "names": {"en": "Vowels"}, "columns": None, "column_labels": []},
    {"key": "long_vowels", "names": {"en": "Long"}, "columns": None, "column_labels": []},
    {"key": "consonants", "names": {"en": "Consonants"}, "columns": None, "column_labels": []},
    {"key": "pairs", "names": {"en": "Pairs"}, "columns": None, "column_labels": []},
    {"key": "borrowed", "names": {"en": "Borrowed"}, "columns": None, "column_labels": []},
]
# (group, position, glyph, audio)
_OLD_LETTERS = [
    ("vowels", 0, "A a", "https://x/a.mp3"),
    ("vowels", 1, "E e", None),
    ("long_vowels", 0, "aa", None),
    ("consonants", 0, "B b", None),
    ("consonants", 1, "Q q", None),
    ("consonants", 2, "'", None),
    ("pairs", 0, "Ch ch", None),
    ("borrowed", 0, "P p", None),
    ("borrowed", 1, "Z z", None),
]


def _old_qubee(db_file: Path) -> None:
    """An om chart in the old shape, and an am chart left alone."""
    with sqlite3.connect(db_file) as conn:
        now = "2026-10-01 00:00:00"
        for language, groups in (
            ("om", _OLD_GROUPS),
            ("am", [{"key": "fidel", "names": {"en": "Fidel"}, "columns": 7, "column_labels": []}]),
        ):
            conn.execute(
                "INSERT INTO sound_charts VALUES (?, '{}', ?, 1, 4, ?, ?)",
                (language, json.dumps(groups), now, now),
            )
        for i, (group, position, glyph, audio) in enumerate(_OLD_LETTERS):
            conn.execute(
                "INSERT INTO sound_letters (id, language, group_key, position, glyph,"
                " romanization, hint, audio_url, example_meaning, status, created_at,"
                " updated_at) VALUES (?, 'om', ?, ?, ?, 'r', '{}', ?, '{}', 'ready', ?, ?)",
                (f"id-{i}", group, position, glyph, audio, now, now),
            )
        conn.execute(
            "INSERT INTO sound_letters (id, language, group_key, position, glyph,"
            " romanization, hint, example_meaning, status, created_at, updated_at)"
            " VALUES ('ha', 'am', 'fidel', 0, 'ሀ', 'he', '{}', '{}', 'draft', ?, ?)",
            (now, now),
        )


def _letters(db_file: Path, language: str) -> list[tuple]:
    with sqlite3.connect(db_file) as conn:
        return conn.execute(
            "SELECT group_key, position, glyph, kind, audio_url FROM sound_letters"
            " WHERE language = ? ORDER BY group_key, position",
            (language,),
        ).fetchall()


def _chart(db_file: Path, language: str) -> tuple[list[str], int]:
    with sqlite3.connect(db_file) as conn:
        groups, version = conn.execute(
            "SELECT groups, version FROM sound_charts WHERE language = ?", (language,)
        ).fetchone()
    return [g["key"] for g in json.loads(groups)], version


def test_upgrade_makes_an_old_qubee_chart_a_to_z(tmp_path: Path) -> None:
    db_file = tmp_path / "sounds.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    _old_qubee(db_file)

    _ok(db_file, "upgrade", _NEW_HEAD)

    assert _chart(db_file, "om") == (["alphabet", "pairs", "long_vowels"], 5)
    assert _letters(db_file, "om") == [
        ("alphabet", 0, "A a", "vowel", "https://x/a.mp3"),
        ("alphabet", 1, "B b", "consonant", None),
        ("alphabet", 2, "E e", "vowel", None),
        ("alphabet", 3, "P p", "consonant", None),
        ("alphabet", 4, "Q q", "consonant", None),
        ("alphabet", 5, "Z z", "consonant", None),
        ("alphabet", 6, "'", "consonant", None),
        ("long_vowels", 0, "aa", "vowel", None),
        ("pairs", 0, "Ch ch", "consonant", None),
    ]
    with sqlite3.connect(db_file) as conn:
        (groups,) = conn.execute("SELECT groups FROM sound_charts WHERE language='om'").fetchone()
    names = {g["key"]: g["names"] for g in json.loads(groups)}
    assert names["alphabet"]["en"] == "A–Z"
    # A name the admin gave is kept.
    assert names["pairs"] == {"en": "Pairs"}
    # Other charts are untouched.
    assert _chart(db_file, "am") == (["fidel"], 4)
    assert _letters(db_file, "am") == [("fidel", 0, "ሀ", None, None)]


def test_downgrade_puts_it_back(tmp_path: Path) -> None:
    db_file = tmp_path / "sounds.db"
    _ok(db_file, "upgrade", _PREVIOUS_HEAD)
    _old_qubee(db_file)
    _ok(db_file, "upgrade", _NEW_HEAD)

    _ok(db_file, "downgrade", _PREVIOUS_HEAD)

    assert _chart(db_file, "om")[0] == [g["key"] for g in _OLD_GROUPS]
    with sqlite3.connect(db_file) as conn:
        rows = conn.execute(
            "SELECT group_key, position, glyph FROM sound_letters WHERE language = 'om'"
            " ORDER BY group_key, position"
        ).fetchall()
        columns = {r[1] for r in conn.execute("PRAGMA table_info(sound_letters)")}
    assert "kind" not in columns
    assert sorted(rows) == sorted((g, p, glyph) for g, p, glyph, _ in _OLD_LETTERS)
