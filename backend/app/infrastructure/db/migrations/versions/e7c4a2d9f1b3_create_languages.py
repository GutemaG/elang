"""create languages

Revision ID: e7c4a2d9f1b3
Revises: d3a7f2b9c6e1
Create Date: 2026-10-02 09:00:00.000000

"""

from collections.abc import Sequence
from datetime import UTC, datetime

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e7c4a2d9f1b3"
down_revision: str | Sequence[str] | None = "d3a7f2b9c6e1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Ethiopia's main languages and English, as (code, English name, own name).
# Names are editable in the admin site afterwards, and more can be added
# there; a course's two language codes name rows of this table.
LANGUAGES: list[tuple[str, str, str]] = [
    ("am", "Amharic", "አማርኛ"),
    ("om", "Afaan Oromo", "Afaan Oromoo"),
    ("ti", "Tigrinya", "ትግርኛ"),
    ("so", "Somali", "Soomaali"),
    ("aa", "Afar", "Qafaraf"),
    ("sid", "Sidama", "Sidaamu Afoo"),
    ("wal", "Wolaytta", "Wolayttatto"),
    ("sgw", "Gurage", "ጉራጊኛ"),
    ("hdy", "Hadiyya", "Hadiyyisa"),
    ("gmv", "Gamo", "Gamo"),
    ("drs", "Gedeo", "Gede'uffa"),
    ("kbr", "Kafa", "Kafi noonoo"),
    ("stv", "Silt'e", "ስልጥኛ"),
    ("har", "Harari", "ሀረሪ"),
    ("gez", "Ge'ez", "ግዕዝ"),
    ("en", "English", "English"),
]


def upgrade() -> None:
    """Upgrade schema.

    Languages become data instead of a hard-coded set, so the admin site can
    add one and then create courses for it. Only adds a table: the backend
    already running ignores it.
    """
    languages = op.create_table(
        "languages",
        sa.Column("code", sa.String(length=8), nullable=False),
        sa.Column("name", sa.String(length=64), nullable=False),
        sa.Column("native_name", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("code"),
    )
    now = datetime.now(UTC)
    op.bulk_insert(
        languages,
        [
            {"code": code, "name": name, "native_name": native, "created_at": now}
            for code, name, native in LANGUAGES
        ],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("languages")
