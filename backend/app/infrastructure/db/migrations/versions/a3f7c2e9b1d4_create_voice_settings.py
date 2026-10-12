"""voice settings for generated audio

Revision ID: a3f7c2e9b1d4
Revises: e2c7a9d4b6f3
Create Date: 2026-10-12 10:10:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a3f7c2e9b1d4"
down_revision: str | Sequence[str] | None = "e2c7a9d4b6f3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Intent 027, bolt 089. A new table only, empty: a language without a
    # row uses the default voices in `app/domain/voices.py`.
    op.create_table(
        "voice_settings",
        sa.Column("language", sa.String(length=8), nullable=False),
        sa.Column("male_voice_id", sa.String(length=80), nullable=False),
        sa.Column("female_voice_id", sa.String(length=80), nullable=False),
        sa.Column("speed", sa.Integer(), nullable=False),
        sa.Column("updated_by", sa.String(length=320), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("speed BETWEEN 0 AND 100", name="ck_voice_settings_speed"),
        sa.PrimaryKeyConstraint("language"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("voice_settings")
