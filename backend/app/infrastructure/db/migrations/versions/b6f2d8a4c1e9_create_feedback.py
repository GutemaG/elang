"""create feedback

Revision ID: b6f2d8a4c1e9
Revises: e7c4a2d9f1b3
Create Date: 2026-10-02 14:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b6f2d8a4c1e9"
down_revision: str | Sequence[str] | None = "e7c4a2d9f1b3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # 027-learner-feedback: a new table only, so the backend already
    # running ignores it.
    op.create_table(
        "feedback",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("category", sa.String(length=16), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("course_id", sa.String(length=36), nullable=True),
        sa.Column("platform", sa.String(length=16), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "category IN ('bug', 'idea', 'content', 'other')", name="ck_feedback_category"
        ),
        sa.CheckConstraint("status IN ('open', 'resolved')", name="ck_feedback_status"),
        sa.CheckConstraint("rating IS NULL OR rating BETWEEN 1 AND 5", name="ck_feedback_rating"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_feedback_created_at", "feedback", ["created_at"])
    op.create_index("ix_feedback_user_id", "feedback", ["user_id"])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_feedback_user_id", table_name="feedback")
    op.drop_index("ix_feedback_created_at", table_name="feedback")
    op.drop_table("feedback")
