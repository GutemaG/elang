"""add spell_tiles to exercises type check constraint

Revision ID: f4c2a81e7b56
Revises: d1b7e4f2a903
Create Date: 2026-09-20 18:50:00.000000

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f4c2a81e7b56"
down_revision: str | Sequence[str] | None = "d1b7e4f2a903"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OLD_TYPES = "'multiple_choice', 'listening', 'sentence_construction', 'match_pairs', 'gap_fill'"
_NEW_TYPES = (
    "'multiple_choice', 'listening', 'sentence_construction', 'match_pairs', "
    "'gap_fill', 'spell_tiles'"
)


def upgrade() -> None:
    """Upgrade schema.

    Bolt 032-spell-tiles-service (016-spell-from-tiles-exercise-type):
    widens `ck_exercises_type` to allow the new `spell_tiles` exercise
    type.

    Same shape as `d1b7e4f2a903`, which added `gap_fill`, and
    `c726efa81972` before it: uses `batch_alter_table` because SQLite
    cannot `ALTER`/drop a `CHECK` constraint in place -- Alembic's batch
    mode recreates the table on SQLite and issues a plain `ALTER` on
    PostgreSQL (this project's production dialect), so it is correct on
    both.

    The same constraint is also declared on `ExerciseModel.__table_args__`
    and was widened there in the same change.
    """
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_NEW_TYPES})")


def downgrade() -> None:
    """Downgrade schema.

    Note this narrows the constraint back to five types. Any `spell_tiles`
    rows seeded in the meantime would violate it, so a downgrade on a
    database holding seeded spell-tiles content must remove those rows
    first -- the same caveat `d1b7e4f2a903` and `c726efa81972` carry.
    """
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_OLD_TYPES})")
