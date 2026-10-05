"""mark sound letters vowel or consonant; Qubee charts as A to Z

Revision ID: c5e8a3f1d7b2
Revises: a9d4e6f2c8b1
Create Date: 2026-10-05 09:00:00.000000

"""

from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Any

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c5e8a3f1d7b2"
down_revision: str | Sequence[str] | None = "a9d4e6f2c8b1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Copied rather than imported, so later changes to the app cannot change
# what this migration did.
_OLD_KEYS = ("vowels", "long_vowels", "consonants", "pairs", "borrowed")
_INTO_ALPHABET = ("vowels", "consonants", "borrowed")
_KIND_OF_GROUP = {
    "vowels": "vowel",
    "long_vowels": "vowel",
    "consonants": "consonant",
    "pairs": "consonant",
    "borrowed": "consonant",
}
_ALPHABET = {"key": "alphabet", "names": {"en": "A–Z", "am": "A–Z", "om": "A–Z"}}
_NEW_ORDER = ("alphabet", "pairs", "long_vowels")
_BORROWED = {"p", "v", "z"}

_charts = sa.table(
    "sound_charts",
    sa.column("language", sa.String),
    sa.column("groups", sa.JSON),
    sa.column("version", sa.Integer),
    sa.column("updated_at", sa.DateTime(timezone=True)),
)
_letters = sa.table(
    "sound_letters",
    sa.column("id", sa.String),
    sa.column("language", sa.String),
    sa.column("group_key", sa.String),
    sa.column("position", sa.Integer),
    sa.column("glyph", sa.String),
    sa.column("kind", sa.String),
)


def _is_old_qubee(groups: list[dict[str, Any]]) -> bool:
    keys = {g.get("key") for g in groups}
    return {"vowels", "consonants"} <= keys and keys <= set(_OLD_KEYS)


def _letter_order(glyph: str) -> tuple[int, str]:
    """A to Z by the glyph's first letter ("B b" under b); anything else,
    such as the hudhaa ', after them in the order it had."""
    first = glyph.strip()[:1].lower()
    return (0, first) if "a" <= first <= "z" else (1, "")


def _group(key: str, groups: list[dict[str, Any]]) -> dict[str, Any]:
    found = next((g for g in groups if g.get("key") == key), None)
    if found is not None:
        return found
    return {"key": key, "names": {"en": key}, "columns": None, "column_labels": []}


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table("sound_letters") as batch:
        batch.add_column(sa.Column("kind", sa.String(length=16), nullable=True))

    # Charts started from the old Qubee template had five groups; they
    # become A to Z (vowels, consonants and the borrowed P V Z in alphabet
    # order), letter pairs and long vowels. Recordings and letter ids stay.
    conn = op.get_bind()
    now = datetime.now(UTC)
    for language, groups, version in conn.execute(
        sa.select(_charts.c.language, _charts.c.groups, _charts.c.version)
    ).all():
        if not _is_old_qubee(groups):
            continue
        rows = conn.execute(
            sa.select(_letters.c.id, _letters.c.group_key, _letters.c.position, _letters.c.glyph)
            .where(_letters.c.language == language)
            .order_by(_letters.c.group_key, _letters.c.position)
        ).all()
        rank = {key: i for i, key in enumerate(_INTO_ALPHABET)}
        alphabet = sorted(
            (r for r in rows if r.group_key in rank),
            key=lambda r: (*_letter_order(r.glyph), rank[r.group_key], r.position),
        )
        for position, r in enumerate(alphabet):
            conn.execute(
                _letters.update()
                .where(_letters.c.id == r.id)
                .values(group_key="alphabet", position=position)
            )
        for r in rows:
            kind = _KIND_OF_GROUP.get(r.group_key)
            if kind:
                conn.execute(_letters.update().where(_letters.c.id == r.id).values(kind=kind))
        new_groups = [
            {"columns": None, "column_labels": [], **_ALPHABET}
            if key == "alphabet"
            else _group(key, groups)
            for key in _NEW_ORDER
        ]
        conn.execute(
            _charts.update()
            .where(_charts.c.language == language)
            .values(groups=new_groups, version=version + 1, updated_at=now)
        )


def downgrade() -> None:
    """Downgrade schema."""
    # A to Z goes back to vowels, consonants and borrowed, by the kinds.
    conn = op.get_bind()
    now = datetime.now(UTC)
    for language, groups, version in conn.execute(
        sa.select(_charts.c.language, _charts.c.groups, _charts.c.version)
    ).all():
        keys = [g.get("key") for g in groups]
        if keys != list(_NEW_ORDER):
            continue
        rows = conn.execute(
            sa.select(_letters.c.id, _letters.c.position, _letters.c.glyph, _letters.c.kind)
            .where(_letters.c.language == language, _letters.c.group_key == "alphabet")
            .order_by(_letters.c.position)
        ).all()
        positions: dict[str, int] = {}
        for r in rows:
            first = r.glyph.strip()[:1].lower()
            if r.kind == "vowel":
                key = "vowels"
            elif first in _BORROWED:
                key = "borrowed"
            else:
                key = "consonants"
            position = positions.get(key, 0)
            positions[key] = position + 1
            conn.execute(
                _letters.update()
                .where(_letters.c.id == r.id)
                .values(group_key=key, position=position)
            )
        old_names = {
            "vowels": {"en": "Vowels", "am": "አናባቢዎች", "om": "Dubbachiiftuu"},
            "consonants": {"en": "Consonants", "am": "ተነባቢዎች", "om": "Dubbifamaa"},
            "borrowed": {"en": "In borrowed words", "am": "በውሰት ቃላት", "om": "Jechoota liqii"},
        }
        old_groups = [
            _group(key, groups)
            if key in ("long_vowels", "pairs")
            else {"key": key, "names": old_names[key], "columns": None, "column_labels": []}
            for key in _OLD_KEYS
        ]
        conn.execute(
            _charts.update()
            .where(_charts.c.language == language)
            .values(groups=old_groups, version=version + 1, updated_at=now)
        )

    with op.batch_alter_table("sound_letters") as batch:
        batch.drop_column("kind")
