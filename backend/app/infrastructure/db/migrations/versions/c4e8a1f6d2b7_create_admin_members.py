"""admin members and their courses

Revision ID: c4e8a1f6d2b7
Revises: a3f7c2e9b1d4
Create Date: 2026-10-13 10:20:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c4e8a1f6d2b7"
down_revision: str | Sequence[str] | None = "a3f7c2e9b1d4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Intent 028, bolt 101. New tables only, empty: owners come from
    # `ADMIN_EMAILS`, and everyone else is added on the Team page.
    op.create_table(
        "admin_members",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("created_by", sa.String(length=320), nullable=False),
        sa.Column("updated_by", sa.String(length=320), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("role IN ('super_admin', 'course_admin')", name="ck_admin_members_role"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email", name="uq_admin_members_email"),
    )
    op.create_table(
        "admin_member_courses",
        sa.Column("member_id", sa.String(length=36), nullable=False),
        sa.Column("course_id", sa.String(length=36), nullable=False),
        sa.ForeignKeyConstraint(["member_id"], ["admin_members.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("member_id", "course_id"),
    )
    op.create_index("ix_admin_member_courses_course_id", "admin_member_courses", ["course_id"])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_admin_member_courses_course_id", table_name="admin_member_courses")
    op.drop_table("admin_member_courses")
    op.drop_table("admin_members")
