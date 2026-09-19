"""create categories, add skills.category_id, per-category skill order

Revision ID: a7d1c5e29b04
Revises: c29bf2c53433
Create Date: 2026-09-19 21:00:00.000000

"""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a7d1c5e29b04"
down_revision: str | Sequence[str] | None = "c29bf2c53433"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Same derivation `seed_lesson_content.py` uses for deterministic content
# ids (uuid5 under this namespace), re-derived inline so a migration never
# imports application code. The seed then upserts this exact row instead of
# creating a duplicate.
_CONTENT_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_DNS, "buna.app/lesson-content")
FOUNDATIONS_ID = str(uuid.uuid5(_CONTENT_NAMESPACE, "category:foundations-and-greetings"))
FOUNDATIONS_TITLE = "Foundations & Greetings"
FOUNDATIONS_SUBTITLE = "ሰላምታ እና ፊደል መግቢያ"


def upgrade() -> None:
    """Upgrade schema.

    Bolt 021-categories-service (ADR-11): categories become a first-class
    level. Order matters for a populated database: create the table, insert
    the first category, add `skills.category_id` as nullable, backfill every
    existing skill into that category, and only then make it NOT NULL and
    swap the globally-unique skill order for a per-category one. Existing
    users, progress, attempts, XP, Amole and vocab rows are not touched.

    Uses `batch_alter_table` for the NOT NULL / FK / constraint swap -- same
    SQLite limitation/precedent as `c726efa81972` and `c29bf2c53433`.
    """
    categories = op.create_table(
        "categories",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("subtitle", sa.String(length=255), nullable=False),
        sa.Column("order_index", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("order_index", name="uq_categories_order_index"),
    )
    op.bulk_insert(
        categories,
        [
            {
                "id": FOUNDATIONS_ID,
                "title": FOUNDATIONS_TITLE,
                "subtitle": FOUNDATIONS_SUBTITLE,
                "order_index": 1,
                "created_at": datetime.now(UTC),
            }
        ],
    )

    with op.batch_alter_table("skills") as batch_op:
        batch_op.add_column(sa.Column("category_id", sa.String(length=36), nullable=True))

    op.execute(
        sa.text("UPDATE skills SET category_id = :category_id").bindparams(
            category_id=FOUNDATIONS_ID
        )
    )

    with op.batch_alter_table("skills") as batch_op:
        batch_op.alter_column("category_id", existing_type=sa.String(length=36), nullable=False)
        batch_op.create_foreign_key("fk_skills_category_id", "categories", ["category_id"], ["id"])
        batch_op.drop_constraint("uq_skills_order_index", type_="unique")
        batch_op.create_unique_constraint(
            "uq_skills_category_order_index", ["category_id", "order_index"]
        )
        batch_op.create_index("ix_skills_category_id", ["category_id"], unique=False)


def downgrade() -> None:
    """Downgrade schema.

    Restores the global `uq_skills_order_index`; that is only possible while
    every skill's `order_index` is still globally unique (true for the
    original two-skill curriculum, not once several categories each start at
    1). Downgrade therefore fails loudly on such data rather than silently
    losing skills.
    """
    with op.batch_alter_table("skills") as batch_op:
        batch_op.drop_index("ix_skills_category_id")
        batch_op.drop_constraint("uq_skills_category_order_index", type_="unique")
        batch_op.create_unique_constraint("uq_skills_order_index", ["order_index"])
        batch_op.drop_constraint("fk_skills_category_id", type_="foreignkey")
        batch_op.drop_column("category_id")

    op.drop_table("categories")
