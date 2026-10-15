"""admin activity log, league removals and XP adjustments

Revision ID: d7b3e9a2c5f1
Revises: c4e8a1f6d2b7
Create Date: 2026-10-15 10:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d7b3e9a2c5f1"
down_revision: str | Sequence[str] | None = "c4e8a1f6d2b7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Intent 030. A new, empty table, and four nullable or defaulted
    # columns: existing memberships rank exactly as before.
    op.create_table(
        "admin_activity",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("admin_email", sa.String(length=320), nullable=False),
        sa.Column("admin_role", sa.String(length=20), nullable=False),
        sa.Column("method", sa.String(length=8), nullable=False),
        sa.Column("route", sa.String(length=255), nullable=False),
        sa.Column("area", sa.String(length=32), nullable=False),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column("target_kind", sa.String(length=32), nullable=True),
        sa.Column("target_id", sa.String(length=255), nullable=True),
        sa.Column("target_name", sa.String(length=255), nullable=True),
        sa.Column("course_id", sa.String(length=36), nullable=True),
        sa.Column("link", sa.String(length=512), nullable=True),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_activity_created_at", "admin_activity", ["created_at"])
    op.create_index("ix_admin_activity_admin_email", "admin_activity", ["admin_email"])

    with op.batch_alter_table("league_members") as batch:
        batch.add_column(sa.Column("removed_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("removed_reason", sa.String(length=200), nullable=True))
        batch.add_column(
            sa.Column("xp_adjustment", sa.Integer(), nullable=False, server_default="0")
        )
        batch.add_column(
            sa.Column("xp_adjustment_reason", sa.String(length=200), nullable=True)
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("league_members") as batch:
        batch.drop_column("xp_adjustment_reason")
        batch.drop_column("xp_adjustment")
        batch.drop_column("removed_reason")
        batch.drop_column("removed_at")
    op.drop_index("ix_admin_activity_admin_email", table_name="admin_activity")
    op.drop_index("ix_admin_activity_created_at", table_name="admin_activity")
    op.drop_table("admin_activity")
