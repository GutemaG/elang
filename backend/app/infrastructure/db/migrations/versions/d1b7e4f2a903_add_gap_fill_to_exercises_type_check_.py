"""add gap_fill to exercises type check constraint

Revision ID: d1b7e4f2a903
Revises: b8e3f0a4c6d2
Create Date: 2026-09-20 13:40:00.000000

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d1b7e4f2a903"
down_revision: str | Sequence[str] | None = "b8e3f0a4c6d2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OLD_TYPES = "'multiple_choice', 'listening', 'sentence_construction', 'match_pairs'"
_NEW_TYPES = "'multiple_choice', 'listening', 'sentence_construction', 'match_pairs', 'gap_fill'"


def upgrade() -> None:
    """Upgrade schema.

    Bolt 030-gap-fill-service (015-gap-fill-exercise-type): widens
    `ck_exercises_type` to allow the new `gap_fill` exercise type.

    Same shape as `c726efa81972`, which added `match_pairs`: uses
    `batch_alter_table` because SQLite cannot `ALTER`/drop a `CHECK`
    constraint in place -- Alembic's batch mode recreates the table on
    SQLite and issues a plain `ALTER` on PostgreSQL (this project's
    production dialect), so it is correct on both.

    The same constraint is also declared on `ExerciseModel.__table_args__`
    and was widened there in the same change.
    """
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_NEW_TYPES})")


def downgrade() -> None:
    """Downgrade schema.

    Note this narrows the constraint back to four types. Any `gap_fill`
    rows seeded in the meantime would violate it, so a downgrade on a
    database holding seeded gap-fill content must remove those rows first
    -- the same caveat `c726efa81972` carries for `match_pairs`.
    """
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_OLD_TYPES})")
