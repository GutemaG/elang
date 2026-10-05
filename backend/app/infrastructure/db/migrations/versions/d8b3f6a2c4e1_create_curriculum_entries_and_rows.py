"""create curriculum_entries and curriculum_rows

Revision ID: d8b3f6a2c4e1
Revises: c5e8a3f1d7b2
Create Date: 2026-10-05 12:10:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d8b3f6a2c4e1"
down_revision: str | Sequence[str] | None = "c5e8a3f1d7b2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # A course's draft curriculum (intent 025): new tables only, so the
    # backend already running ignores them. Both start empty; the admin
    # site imports the curriculum workbook into them.
    op.create_table(
        "curriculum_entries",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("course_id", sa.String(length=36), nullable=False),
        sa.Column("ref", sa.String(length=32), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column("parent_ref", sa.String(length=32), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("goal", sa.Text(), nullable=True),
        sa.Column("grammar", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "kind IN ('section', 'skill', 'lesson')", name="ck_curriculum_entries_kind"
        ),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("course_id", "ref", name="uq_curriculum_entries_course_ref"),
    )
    op.create_table(
        "curriculum_rows",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("course_id", sa.String(length=36), nullable=False),
        sa.Column("ref", sa.String(length=32), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column("lesson_ref", sa.String(length=32), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("english", sa.Text(), nullable=False),
        sa.Column("text", sa.Text(), nullable=True),
        sa.Column("romanization", sa.Text(), nullable=True),
        sa.Column("blank", sa.Text(), nullable=True),
        sa.Column("accepted", sa.JSON(), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("confidence", sa.String(length=16), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("audio_url", sa.String(length=1024), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("updated_by", sa.String(length=320), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("kind IN ('word', 'sentence')", name="ck_curriculum_rows_kind"),
        sa.CheckConstraint(
            "status IN ('to_do', 'draft', 'needs_change', 'reviewed')",
            name="ck_curriculum_rows_status",
        ),
        sa.CheckConstraint(
            "confidence IS NULL OR confidence IN ('high', 'medium', 'low')",
            name="ck_curriculum_rows_confidence",
        ),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("course_id", "ref", name="uq_curriculum_rows_course_ref"),
    )
    op.create_index(
        "ix_curriculum_rows_lesson", "curriculum_rows", ["course_id", "lesson_ref", "position"]
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_curriculum_rows_lesson", table_name="curriculum_rows")
    op.drop_table("curriculum_rows")
    op.drop_table("curriculum_entries")
