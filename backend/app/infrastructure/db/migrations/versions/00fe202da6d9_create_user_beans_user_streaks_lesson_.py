"""create user_beans user_streaks lesson_attempts tables, add
completed_lesson_ids_this_cycle to user_skill_progress

Revision ID: 00fe202da6d9
Revises: 772d3af2a112
Create Date: 2026-09-16 12:45:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "00fe202da6d9"
down_revision: str | Sequence[str] | None = "772d3af2a112"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "user_skill_progress",
        sa.Column(
            "completed_lesson_ids_this_cycle",
            sa.JSON(),
            nullable=False,
            server_default="[]",
        ),
    )
    op.create_table(
        "user_beans",
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("current_count", sa.Integer(), nullable=False),
        sa.Column("last_regen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("amole_balance", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "current_count >= 0", name="ck_user_beans_current_count_non_negative"
        ),
        sa.CheckConstraint(
            "amole_balance >= 0", name="ck_user_beans_amole_balance_non_negative"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("user_id"),
    )
    op.create_table(
        "user_streaks",
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("current_streak", sa.Integer(), nullable=False),
        sa.Column("last_completed_date", sa.Date(), nullable=True),
        sa.Column("active_freeze_count", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "current_streak >= 0", name="ck_user_streaks_current_streak_non_negative"
        ),
        sa.CheckConstraint(
            "active_freeze_count >= 0",
            name="ck_user_streaks_active_freeze_count_non_negative",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("user_id"),
    )
    op.create_table(
        "lesson_attempts",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("lesson_id", sa.String(length=36), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("total_count", sa.Integer(), nullable=False),
        sa.Column("xp_awarded", sa.Integer(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("result", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "correct_count >= 0 AND correct_count <= total_count",
            name="ck_lesson_attempts_correct_le_total",
        ),
        sa.ForeignKeyConstraint(["lesson_id"], ["lessons.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_lesson_attempts_user_completed",
        "lesson_attempts",
        ["user_id", "completed_at"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_lesson_attempts_user_completed", table_name="lesson_attempts")
    op.drop_table("lesson_attempts")
    op.drop_table("user_streaks")
    op.drop_table("user_beans")
    op.drop_column("user_skill_progress", "completed_lesson_ids_this_cycle")
