"""add image_choice and audio_image_choice to exercises type check constraint

Revision ID: b5e9d2c7a4f1
Revises: a7d3c9e1f042
Create Date: 2026-09-25 08:00:00.000000

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b5e9d2c7a4f1"
down_revision: str | Sequence[str] | None = "a7d3c9e1f042"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OLD_TYPES = (
    "'multiple_choice', 'listening', 'sentence_construction', 'match_pairs', "
    "'gap_fill', 'spell_tiles'"
)
_NEW_TYPES = f"{_OLD_TYPES}, 'image_choice', 'audio_image_choice'"


def upgrade() -> None:
    """Upgrade schema.

    Bolt 050-image-choice-service (019-image-choice-exercise-types): widens
    `ck_exercises_type` to allow the two picture types.

    Same shape as `f4c2a81e7b56` (`spell_tiles`) and the two before it:
    `batch_alter_table`, because SQLite cannot `ALTER`/drop a `CHECK`
    constraint in place. Batch mode recreates the table on SQLite and issues
    a plain `ALTER` on PostgreSQL.

    The same constraint is declared on `ExerciseModel.__table_args__` and
    was widened there in the same change.
    """
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_NEW_TYPES})")


def downgrade() -> None:
    """Downgrade schema.

    Narrows the constraint back to six types. Any `image_choice` or
    `audio_image_choice` rows would violate it, so remove them before
    downgrading a database that holds them -- the same caveat the earlier
    widenings carry.
    """
    with op.batch_alter_table("exercises") as batch_op:
        batch_op.drop_constraint("ck_exercises_type", type_="check")
        batch_op.create_check_constraint("ck_exercises_type", f"type IN ({_OLD_TYPES})")
