"""add updated_at to lessons and exercises

Revision ID: e3cea3ee5c84
Revises: 00fe202da6d9
Create Date: 2026-09-16 22:15:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e3cea3ee5c84"
down_revision: str | Sequence[str] | None = "00fe202da6d9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Bolt 008 (003-offline-caching-and-sync): drives each lesson's/skill's
    # `content_version` signal (FR-1's offline-pack staleness check).
    #
    # The default is a fixed constant, not `now()`: SQLite's `ALTER TABLE
    # ADD COLUMN` rejects a non-constant default (e.g. `CURRENT_TIMESTAMP`)
    # combined with `NOT NULL` outright ("Cannot add a column with
    # non-constant default"). A fixed epoch backfills existing seeded rows
    # with a valid, stable timestamp -- matching the same
    # `_NO_CONTENT_VERSION` epoch fallback `lesson_use_cases.py` already
    # uses for a skill with zero lessons. New rows get a real timestamp from
    # `LessonModel`/`ExerciseModel`'s Python-side `_utcnow` default/onupdate,
    # not from this column default.
    op.add_column(
        "lessons",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("'1970-01-01 00:00:00'"),
        ),
    )
    op.add_column(
        "exercises",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("'1970-01-01 00:00:00'"),
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("exercises", "updated_at")
    op.drop_column("lessons", "updated_at")
