"""add settings to users and app_config

Revision ID: c8e1f4a7b2d5
Revises: b5e9d2c7a4f1
Create Date: 2026-09-30 20:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c8e1f4a7b2d5"
down_revision: str | Sequence[str] | None = "b5e9d2c7a4f1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Bolt 071 (022-light-and-dark-themes, FR-8/FR-9): the last migration a
    # setting should ever need. Account settings live in one JSON map and
    # app-wide values in `app_config`; both are read through registries in
    # `app/domain/settings.py` that give every key its default, so nothing
    # is seeded or backfilled. The constant server default fills existing
    # rows with `{}` (SQLite's `ADD COLUMN` needs a constant for `NOT NULL`).
    # Both changes only add, so the backend already running ignores them.
    op.add_column(
        "users",
        sa.Column("settings", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
    )
    op.create_table(
        "app_config",
        sa.Column("key", sa.String(length=100), nullable=False),
        sa.Column("value", sa.JSON(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("key"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("app_config")
    # Batch mode, so SQLite rebuilds the table where it can't drop a column.
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("settings")
