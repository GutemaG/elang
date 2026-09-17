"""create amole_transactions ledger, drop user_beans.amole_balance

Revision ID: f4a8b1c9d3e6
Revises: e02dd0a9ae54
Create Date: 2026-09-17 18:30:00.000000

"""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f4a8b1c9d3e6"
down_revision: str | Sequence[str] | None = "e02dd0a9ae54"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_AMOLE_SOURCES = (
    "'wallet_created', 'migration_backfill', 'lesson_completion', "
    "'perfect_lesson', 'streak_milestone_7', 'streak_milestone_30', 'bean_refill'"
)


def upgrade() -> None:
    """Upgrade schema.

    Bolt 017-amole-service (007-amole-currency, ADR-8): introduces the
    append-only `amole_transactions` ledger (`SUM(amount)` is now the sole
    source of truth for Amole balance) and retires `user_beans.amole_balance`.

    Backfills exactly one `migration_backfill` row per existing `user_beans`
    row, preserving that user's current balance -- no one's balance changes
    at cutover. This is this codebase's first data-migrating (not
    schema-only) revision, so it uses plain SQLAlchemy Core against
    lightweight ad hoc table objects rather than a dialect-specific
    `INSERT ... SELECT`, for SQLite/PostgreSQL portability (`data-stack.md`).
    """
    op.create_table(
        "amole_transactions",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("reference_id", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(f"source IN ({_AMOLE_SOURCES})", name="ck_amole_transactions_source"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "source", "reference_id", name="uq_amole_transactions_source_reference"
        ),
    )
    op.create_index(
        "ix_amole_transactions_user_id", "amole_transactions", ["user_id"], unique=False
    )

    bind = op.get_bind()
    user_beans = sa.table(
        "user_beans",
        sa.column("user_id", sa.String),
        sa.column("amole_balance", sa.Integer),
    )
    amole_transactions = sa.table(
        "amole_transactions",
        sa.column("id", sa.String),
        sa.column("user_id", sa.String),
        sa.column("amount", sa.Integer),
        sa.column("source", sa.String),
        sa.column("reference_id", sa.String),
        sa.column("created_at", sa.DateTime),
    )
    existing = bind.execute(
        sa.select(user_beans.c.user_id, user_beans.c.amole_balance)
    ).fetchall()
    now = datetime.now(UTC)
    for user_id, amole_balance in existing:
        bind.execute(
            sa.insert(amole_transactions).values(
                id=str(uuid.uuid4()),
                user_id=user_id,
                amount=amole_balance,
                source="migration_backfill",
                reference_id=user_id,
                created_at=now,
            )
        )

    with op.batch_alter_table("user_beans") as batch_op:
        batch_op.drop_constraint("ck_user_beans_amole_balance_non_negative", type_="check")
        batch_op.drop_column("amole_balance")


def downgrade() -> None:
    """Downgrade schema. Restores `user_beans.amole_balance` from the
    ledger's `SUM(amount)` per user -- the exact inverse of the backfill
    above.
    """
    with op.batch_alter_table("user_beans") as batch_op:
        batch_op.add_column(sa.Column("amole_balance", sa.Integer(), nullable=True))

    bind = op.get_bind()
    amole_transactions = sa.table(
        "amole_transactions",
        sa.column("user_id", sa.String),
        sa.column("amount", sa.Integer),
    )
    user_beans = sa.table(
        "user_beans",
        sa.column("user_id", sa.String),
        sa.column("amole_balance", sa.Integer),
    )
    totals = bind.execute(
        sa.select(amole_transactions.c.user_id, sa.func.sum(amole_transactions.c.amount)).group_by(
            amole_transactions.c.user_id
        )
    ).fetchall()
    for user_id, balance in totals:
        bind.execute(
            sa.update(user_beans)
            .where(user_beans.c.user_id == user_id)
            .values(amole_balance=balance or 0)
        )

    with op.batch_alter_table("user_beans") as batch_op:
        batch_op.alter_column("amole_balance", nullable=False)
        batch_op.create_check_constraint(
            "ck_user_beans_amole_balance_non_negative", "amole_balance >= 0"
        )

    op.drop_index("ix_amole_transactions_user_id", table_name="amole_transactions")
    op.drop_table("amole_transactions")
