"""add weekly leagues

Revision ID: d3a7f2b9c6e1
Revises: c8e1f4a7b2d5
Create Date: 2026-10-01 07:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d3a7f2b9c6e1"
down_revision: str | Sequence[str] | None = "c8e1f4a7b2d5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TIERS = "'green_bean', 'light_roast', 'medium_roast', 'dark_roast', 'golden_cup'"
_OLD_SOURCES = (
    "'wallet_created', 'migration_backfill', 'lesson_completion', 'perfect_lesson', "
    "'streak_milestone_7', 'streak_milestone_30', 'bean_refill', 'practice_session'"
)
_NEW_SOURCES = f"{_OLD_SOURCES}, 'league_reward'"


def upgrade() -> None:
    """Upgrade schema."""
    # 023-weekly-leagues (bolt 073): the intent's one migration, including
    # the columns bolt 074 writes when a week closes. Weekly XP is never
    # stored while a week is open (it is summed from the attempt tables),
    # and existing accounts need no backfill: with no membership they are
    # in the lowest tier, and with no first name they are shown as
    # "Learner" and four digits. Everything here only adds, so the backend
    # already running ignores it.
    op.create_table(
        "league_groups",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("tier", sa.String(length=16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(f"tier IN ({_TIERS})", name="ck_league_groups_tier"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_league_groups_week_tier", "league_groups", ["week_start", "tier"])
    op.create_table(
        "league_members",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("group_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("final_xp", sa.Integer(), nullable=True),
        sa.Column("final_rank", sa.Integer(), nullable=True),
        sa.Column("tier_after", sa.String(length=16), nullable=True),
        sa.Column("reward_amole", sa.Integer(), nullable=True),
        sa.Column("result_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            f"tier_after IS NULL OR tier_after IN ({_TIERS})",
            name="ck_league_members_tier_after",
        ),
        sa.ForeignKeyConstraint(["group_id"], ["league_groups.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "week_start", name="uq_league_members_user_week"),
    )
    op.create_index("ix_league_members_group_id", "league_members", ["group_id"])
    op.add_column("users", sa.Column("first_name", sa.String(length=100), nullable=True))

    with op.batch_alter_table("amole_transactions") as batch_op:
        batch_op.drop_constraint("ck_amole_transactions_source", type_="check")
        batch_op.create_check_constraint(
            "ck_amole_transactions_source", f"source IN ({_NEW_SOURCES})"
        )


def downgrade() -> None:
    """Downgrade schema."""
    # A `league_reward` row would break the old check, and the rewards
    # belong to leagues, so they go with them.
    op.execute("DELETE FROM amole_transactions WHERE source = 'league_reward'")
    with op.batch_alter_table("amole_transactions") as batch_op:
        batch_op.drop_constraint("ck_amole_transactions_source", type_="check")
        batch_op.create_check_constraint(
            "ck_amole_transactions_source", f"source IN ({_OLD_SOURCES})"
        )

    op.drop_index("ix_league_members_group_id", table_name="league_members")
    op.drop_table("league_members")
    op.drop_index("ix_league_groups_week_tier", table_name="league_groups")
    op.drop_table("league_groups")
    # Batch mode, so SQLite rebuilds the table where it can't drop a column.
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("first_name")
