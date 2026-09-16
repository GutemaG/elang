"""add match_pairs to exercises type check constraint

Revision ID: c726efa81972
Revises: e3cea3ee5c84
Create Date: 2026-09-16 23:14:54.638846

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c726efa81972"
down_revision: str | Sequence[str] | None = "e3cea3ee5c84"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OLD_TYPES = "'multiple_choice', 'listening', 'sentence_construction'"
_NEW_TYPES = "'multiple_choice', 'listening', 'sentence_construction', 'match_pairs'"


def upgrade() -> None:
    """Upgrade schema.

    Bolt 011-match-pairs-service (004-match-pairs-exercise-type): widens
    `ck_exercises_type` to allow the new `match_pairs` exercise type.

    Uses `batch_alter_table` because SQLite cannot `ALTER`/drop a `CHECK`
    constraint in place -- Alembic's batch mode recreates the table under
    the hood on SQLite, and simply issues a normal `ALTER` on PostgreSQL
    (this project's production dialect), so this is safe/correct on both.
    """
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_NEW_TYPES})")


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_OLD_TYPES})")
