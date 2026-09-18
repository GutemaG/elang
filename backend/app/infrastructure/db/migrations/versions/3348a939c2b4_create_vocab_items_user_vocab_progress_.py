"""create vocab_items, user_vocab_progress, add exercises.vocab_item_id

Revision ID: 3348a939c2b4
Revises: f4a8b1c9d3e6
Create Date: 2026-09-17 22:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "3348a939c2b4"
down_revision: str | Sequence[str] | None = "f4a8b1c9d3e6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema.

    Bolt 019-srs-tracking-service (008-srs-and-practice): purely additive --
    two new tables plus a nullable FK column on the existing `exercises`
    table. No data migration/backfill is needed (unlike bolt 017's ledger
    cutover): every existing exercise simply starts with `vocab_item_id`
    unset until the seed script links the relevant ones.
    """
    op.create_table(
        "vocab_items",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("word", sa.String(length=255), nullable=False),
        sa.Column("translation", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "user_vocab_progress",
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("vocab_item_id", sa.String(length=36), nullable=False),
        sa.Column("box_level", sa.Integer(), nullable=False),
        sa.Column("next_review_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "box_level >= 1 AND box_level <= 5", name="ck_user_vocab_progress_box_level"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["vocab_item_id"], ["vocab_items.id"]),
        sa.PrimaryKeyConstraint("user_id", "vocab_item_id"),
    )
    op.create_index(
        "ix_user_vocab_progress_user_next_review",
        "user_vocab_progress",
        ["user_id", "next_review_at"],
        unique=False,
    )

    # SQLite cannot add a FOREIGN KEY constraint via a plain `ALTER TABLE ADD
    # COLUMN` -- batch mode recreates the table under the hood, same
    # portability need as `c726efa81972`'s CHECK-constraint widen.
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.add_column(sa.Column("vocab_item_id", sa.String(length=36), nullable=True))
        batch_op.create_foreign_key(
            "fk_exercises_vocab_item_id", "vocab_items", ["vocab_item_id"], ["id"]
        )
    op.create_index(
        "ix_exercises_vocab_item_id", "exercises", ["vocab_item_id"], unique=False
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_exercises_vocab_item_id", table_name="exercises")
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("fk_exercises_vocab_item_id", type_="foreignkey")
        batch_op.drop_column("vocab_item_id")

    op.drop_index("ix_user_vocab_progress_user_next_review", table_name="user_vocab_progress")
    op.drop_table("user_vocab_progress")
    op.drop_table("vocab_items")
