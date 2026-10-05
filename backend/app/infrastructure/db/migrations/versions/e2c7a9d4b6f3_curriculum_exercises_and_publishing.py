"""curriculum draft exercises, and where published lessons went

Revision ID: e2c7a9d4b6f3
Revises: d8b3f6a2c4e1
Create Date: 2026-10-05 12:50:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e2c7a9d4b6f3"
down_revision: str | Sequence[str] | None = "d8b3f6a2c4e1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Intent 025, bolt 085. Nullable columns and a new table only, so the
    # backend already running keeps working. Batch mode, as SQLite cannot
    # add a column with a default in place.
    with op.batch_alter_table("curriculum_entries") as batch:
        batch.add_column(sa.Column("published_id", sa.String(length=36), nullable=True))
        batch.add_column(
            sa.Column(
                "published_exercise_ids", sa.JSON(), nullable=False, server_default=sa.text("'[]'")
            )
        )
        batch.add_column(sa.Column("published_at", sa.DateTime(timezone=True), nullable=True))
    with op.batch_alter_table("curriculum_rows") as batch:
        batch.add_column(sa.Column("vocab_item_id", sa.String(length=36), nullable=True))
    op.create_table(
        "curriculum_exercises",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("course_id", sa.String(length=36), nullable=False),
        sa.Column("lesson_ref", sa.String(length=32), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("type", sa.String(length=32), nullable=False),
        sa.Column("prompt", sa.Text(), nullable=False),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("answer_key", sa.JSON(), nullable=False),
        sa.Column("vocab_ref", sa.String(length=32), nullable=True),
        sa.Column("generated", sa.JSON(), nullable=True),
        sa.Column("edited", sa.Boolean(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_curriculum_exercises_lesson",
        "curriculum_exercises",
        ["course_id", "lesson_ref", "position"],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_curriculum_exercises_lesson", table_name="curriculum_exercises")
    op.drop_table("curriculum_exercises")
    with op.batch_alter_table("curriculum_rows") as batch:
        batch.drop_column("vocab_item_id")
    with op.batch_alter_table("curriculum_entries") as batch:
        batch.drop_column("published_at")
        batch.drop_column("published_exercise_ids")
        batch.drop_column("published_id")
