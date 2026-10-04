"""create sound_charts and sound_letters

Revision ID: a9d4e6f2c8b1
Revises: b6f2d8a4c1e9
Create Date: 2026-10-04 09:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a9d4e6f2c8b1"
down_revision: str | Sequence[str] | None = "b6f2d8a4c1e9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # The Sounds tab: new tables only, so the backend already running
    # ignores them. Both start empty; charts are made on the admin site.
    op.create_table(
        "sound_charts",
        sa.Column("language", sa.String(length=8), nullable=False),
        sa.Column("title", sa.JSON(), nullable=False),
        sa.Column("groups", sa.JSON(), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["language"], ["languages.code"]),
        sa.PrimaryKeyConstraint("language"),
    )
    op.create_table(
        "sound_letters",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("language", sa.String(length=8), nullable=False),
        sa.Column("group_key", sa.String(length=32), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("glyph", sa.String(length=16), nullable=False),
        sa.Column("romanization", sa.String(length=32), nullable=False),
        sa.Column("hint", sa.JSON(), nullable=False),
        sa.Column("audio_url", sa.String(length=1024), nullable=True),
        sa.Column("same_as_id", sa.String(length=36), nullable=True),
        sa.Column("example_word", sa.String(length=64), nullable=True),
        sa.Column("example_romanization", sa.String(length=64), nullable=True),
        sa.Column("example_meaning", sa.JSON(), nullable=False),
        sa.Column("example_audio_url", sa.String(length=1024), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("recorded_by", sa.String(length=120), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "status IN ('draft', 'needs_review', 'ready')", name="ck_sound_letters_status"
        ),
        sa.ForeignKeyConstraint(["language"], ["sound_charts.language"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["same_as_id"], ["sound_letters.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_sound_letters_language", "sound_letters", ["language", "group_key", "position"]
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_sound_letters_language", table_name="sound_letters")
    op.drop_table("sound_letters")
    op.drop_table("sound_charts")
