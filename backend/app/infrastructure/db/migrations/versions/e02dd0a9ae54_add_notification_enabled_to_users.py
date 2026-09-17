"""add notification_enabled to users

Revision ID: e02dd0a9ae54
Revises: c726efa81972
Create Date: 2026-09-17 10:26:25.170376

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e02dd0a9ae54"
down_revision: str | Sequence[str] | None = "c726efa81972"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Bolt 013 (005-profile-and-settings): FR-4's notification toggle. A
    # fixed constant default, not a Python-side one: SQLite's `ALTER TABLE
    # ADD COLUMN` rejects `NOT NULL` combined with a non-constant default
    # (same gotcha documented in migration `e3cea3ee5c84`). `true` backfills
    # every existing row to opt-out-by-default (story 002's "sensible
    # backfill, not null" acceptance criterion) -- new rows also get `true`
    # from `UserModel`'s Python-side `default=True`, not from this column
    # default.
    op.add_column(
        "users",
        sa.Column(
            "notification_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("users", "notification_enabled")
