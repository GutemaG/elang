"""create practice_attempts, add practice_session to amole check constraint

Revision ID: c29bf2c53433
Revises: 3348a939c2b4
Create Date: 2026-09-18 09:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c29bf2c53433"
down_revision: str | Sequence[str] | None = "3348a939c2b4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OLD_SOURCES = (
    "'wallet_created', 'migration_backfill', 'lesson_completion', "
    "'perfect_lesson', 'streak_milestone_7', 'streak_milestone_30', 'bean_refill'"
)
_NEW_SOURCES = f"{_OLD_SOURCES}, 'practice_session'"


def upgrade() -> None:
    """Upgrade schema.

    Bolt 020-practice-ui (008-srs-and-practice): a completed Practice
    session's own idempotency-supporting record (mirrors `LessonAttempt`'s
    shape, but no `lesson_id`/`skill_id` -- a session spans arbitrary
    lessons/skills) plus the new `practice_session` Amole source.

    Uses `batch_alter_table` for the `CHECK` widen -- same SQLite
    limitation/precedent as `c726efa81972`.
    """
    op.create_table(
        "practice_attempts",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("total_count", sa.Integer(), nullable=False),
        sa.Column("xp_awarded", sa.Integer(), nullable=False),
        sa.Column("amole_awarded", sa.Integer(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "correct_count >= 0 AND correct_count <= total_count",
            name="ck_practice_attempts_correct_le_total",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_practice_attempts_user_completed",
        "practice_attempts",
        ["user_id", "completed_at"],
        unique=False,
    )

    with op.batch_alter_table("amole_transactions") as batch_op:
        batch_op.drop_constraint("ck_amole_transactions_source", type_="check")
        batch_op.create_check_constraint(
            "ck_amole_transactions_source", f"source IN ({_NEW_SOURCES})"
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("amole_transactions") as batch_op:
        batch_op.drop_constraint("ck_amole_transactions_source", type_="check")
        batch_op.create_check_constraint(
            "ck_amole_transactions_source", f"source IN ({_OLD_SOURCES})"
        )

    op.drop_index("ix_practice_attempts_user_completed", table_name="practice_attempts")
    op.drop_table("practice_attempts")
