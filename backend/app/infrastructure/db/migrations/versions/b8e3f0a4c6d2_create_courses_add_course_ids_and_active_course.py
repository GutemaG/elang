"""create courses; add course_id to categories and vocab_items; users.active_course_id

Revision ID: b8e3f0a4c6d2
Revises: a7d1c5e29b04
Create Date: 2026-09-20 15:30:00.000000

"""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b8e3f0a4c6d2"
down_revision: str | Sequence[str] | None = "a7d1c5e29b04"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Same derivation `seed_lesson_content.py` uses for deterministic content ids
# (uuid5 under this namespace), re-derived inline so a migration never imports
# application code. The seed then upserts this exact row instead of creating a
# duplicate.
_CONTENT_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_DNS, "buna.app/lesson-content")
EN_AM_COURSE_ID = str(uuid.uuid5(_CONTENT_NAMESPACE, "course:en-am"))
EN_AM_TITLE = "English to Amharic"


def upgrade() -> None:
    """Upgrade schema.

    Bolt 024-courses-service (ADR-12, ADR-13): courses become the top content
    level. Order matters for a populated database: create `courses` with the
    one course every existing row belongs to (English to Amharic), then for
    each of `categories`, `vocab_items` and `users` add the reference as
    nullable, backfill it, and only then make it NOT NULL with its FK. The
    per-category order uniqueness moves from global to per course. No skill,
    lesson, exercise, progress, attempt, XP, Amole or vocab-progress row is
    touched.

    Uses `batch_alter_table` for the NOT NULL / FK / constraint work -- same
    SQLite limitation/precedent as `a7d1c5e29b04`.
    """
    courses = op.create_table(
        "courses",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("learning_language", sa.String(length=8), nullable=False),
        sa.Column("from_language", sa.String(length=8), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("order_index", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("learning_language", "from_language", name="uq_courses_language_pair"),
        sa.UniqueConstraint("order_index", name="uq_courses_order_index"),
        sa.CheckConstraint("status IN ('available', 'coming_soon')", name="ck_courses_status"),
        sa.CheckConstraint(
            "learning_language <> from_language", name="ck_courses_languages_differ"
        ),
    )
    op.bulk_insert(
        courses,
        [
            {
                "id": EN_AM_COURSE_ID,
                "learning_language": "am",
                "from_language": "en",
                "title": EN_AM_TITLE,
                "status": "available",
                "order_index": 1,
                "created_at": datetime.now(UTC),
            }
        ],
    )

    # categories: course_id, and per-course order uniqueness.
    with op.batch_alter_table("categories") as batch_op:
        batch_op.add_column(sa.Column("course_id", sa.String(length=36), nullable=True))
    op.execute(
        sa.text("UPDATE categories SET course_id = :course_id").bindparams(
            course_id=EN_AM_COURSE_ID
        )
    )
    with op.batch_alter_table("categories") as batch_op:
        batch_op.alter_column("course_id", existing_type=sa.String(length=36), nullable=False)
        batch_op.create_foreign_key("fk_categories_course_id", "courses", ["course_id"], ["id"])
        batch_op.drop_constraint("uq_categories_order_index", type_="unique")
        batch_op.create_unique_constraint(
            "uq_categories_course_order_index", ["course_id", "order_index"]
        )
        batch_op.create_index("ix_categories_course_id", ["course_id"], unique=False)

    # vocab_items: course_id.
    with op.batch_alter_table("vocab_items") as batch_op:
        batch_op.add_column(sa.Column("course_id", sa.String(length=36), nullable=True))
    op.execute(
        sa.text("UPDATE vocab_items SET course_id = :course_id").bindparams(
            course_id=EN_AM_COURSE_ID
        )
    )
    with op.batch_alter_table("vocab_items") as batch_op:
        batch_op.alter_column("course_id", existing_type=sa.String(length=36), nullable=False)
        batch_op.create_foreign_key("fk_vocab_items_course_id", "courses", ["course_id"], ["id"])
        batch_op.create_index("ix_vocab_items_course_id", ["course_id"], unique=False)

    # users: active_course_id (selected_language stays, as a mirror -- ADR-13).
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(sa.Column("active_course_id", sa.String(length=36), nullable=True))
    op.execute(
        sa.text("UPDATE users SET active_course_id = :course_id").bindparams(
            course_id=EN_AM_COURSE_ID
        )
    )
    with op.batch_alter_table("users") as batch_op:
        batch_op.alter_column(
            "active_course_id", existing_type=sa.String(length=36), nullable=False
        )
        batch_op.create_foreign_key("fk_users_active_course_id", "courses", ["active_course_id"], ["id"])


def downgrade() -> None:
    """Downgrade schema.

    Restores the global `uq_categories_order_index`; that is only possible
    while every category's `order_index` is still globally unique (true for
    the English to Amharic course alone, not once several courses each start
    at 1). Downgrade therefore fails loudly on such data rather than silently
    losing categories.
    """
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_constraint("fk_users_active_course_id", type_="foreignkey")
        batch_op.drop_column("active_course_id")

    with op.batch_alter_table("vocab_items") as batch_op:
        batch_op.drop_index("ix_vocab_items_course_id")
        batch_op.drop_constraint("fk_vocab_items_course_id", type_="foreignkey")
        batch_op.drop_column("course_id")

    with op.batch_alter_table("categories") as batch_op:
        batch_op.drop_index("ix_categories_course_id")
        batch_op.drop_constraint("uq_categories_course_order_index", type_="unique")
        batch_op.create_unique_constraint("uq_categories_order_index", ["order_index"])
        batch_op.drop_constraint("fk_categories_course_id", type_="foreignkey")
        batch_op.drop_column("course_id")

    op.drop_table("courses")
