"""add email to users

Revision ID: a7d3c9e1f042
Revises: f4c2a81e7b56
Create Date: 2026-09-23 09:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a7d3c9e1f042"
down_revision: str | Sequence[str] | None = "f4c2a81e7b56"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema.

    Bolt 034-admin-api-foundation (017-content-admin-web, ADR-16): a
    nullable `users.email`, holding the provider-verified email from the
    latest sign-in, for the `ADMIN_EMAILS` check. Existing rows stay `NULL`
    until that user next signs in with Google. Not unique and not indexed:
    the account key remains (`auth_provider`, `provider_user_id`).

    `batch_alter_table` for SQLite parity with the other `users` migrations;
    on PostgreSQL it is a plain `ALTER TABLE ... ADD COLUMN`.
    """
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(sa.Column("email", sa.String(length=320), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("email")
