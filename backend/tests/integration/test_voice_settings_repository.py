"""Integration tests: the voice settings store (intent 027, story 001)
through the real SQLAlchemy repository."""

from __future__ import annotations

from typing import Any

import pytest
from sqlalchemy import event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.voices import default_voice_settings
from app.infrastructure.db.voice_settings_repository import SqlAlchemyVoiceSettingsRepository

ADMIN = "admin@example.com"


async def test_a_language_without_a_row_uses_the_defaults(db_session: AsyncSession) -> None:
    repo = SqlAlchemyVoiceSettingsRepository(db_session)

    assert await repo.get("am") == default_voice_settings("am")
    assert await repo.get("om") == default_voice_settings("om")


async def test_the_first_save_inserts_and_get_returns_it(db_session: AsyncSession) -> None:
    repo = SqlAlchemyVoiceSettingsRepository(db_session)

    saved = await repo.save(
        "om", male_voice_id="om-bikila", female_voice_id="om-hawi", speed=40, admin=ADMIN
    )
    stored = await repo.get("om")

    assert stored == saved
    assert (stored.male_voice_id, stored.female_voice_id, stored.speed) == (
        "om-bikila",
        "om-hawi",
        40,
    )
    assert stored.updated_by == ADMIN
    assert stored.updated_at is not None


async def test_a_later_save_updates_the_same_row(db_session: AsyncSession) -> None:
    repo = SqlAlchemyVoiceSettingsRepository(db_session)
    await repo.save(
        "am", male_voice_id="am-simon", female_voice_id="am-loza", speed=50, admin=ADMIN
    )

    await repo.save(
        "am",
        male_voice_id="am-yohanes-calm",
        female_voice_id="am-dibora",
        speed=35,
        admin="other@example.com",
    )
    stored = await repo.get("am")

    assert (stored.male_voice_id, stored.female_voice_id, stored.speed) == (
        "am-yohanes-calm",
        "am-dibora",
        35,
    )
    assert stored.updated_by == "other@example.com"


async def test_saving_one_language_leaves_the_other_alone(db_session: AsyncSession) -> None:
    repo = SqlAlchemyVoiceSettingsRepository(db_session)

    await repo.save(
        "am", male_voice_id="am-simon", female_voice_id="am-meron", speed=60, admin=ADMIN
    )

    assert await repo.get("om") == default_voice_settings("om")


async def test_list_all_is_amharic_then_afaan_oromo_in_one_query(
    db_session: AsyncSession,
) -> None:
    repo = SqlAlchemyVoiceSettingsRepository(db_session)
    await repo.save("om", male_voice_id="om-leta", female_voice_id="om-obse", speed=45, admin=ADMIN)
    statements: list[str] = []

    def count(*args: Any) -> None:
        statements.append(args[2])

    engine = db_session.bind.sync_engine  # type: ignore[union-attr]
    event.listen(engine, "before_cursor_execute", count)
    try:
        listed = await repo.list_all()
    finally:
        event.remove(engine, "before_cursor_execute", count)

    assert [s.language for s in listed] == ["am", "om"]
    assert listed[0] == default_voice_settings("am")
    assert (listed[1].male_voice_id, listed[1].speed) == ("om-leta", 45)
    assert len(statements) == 1


@pytest.mark.parametrize("speed", [-1, 101])
async def test_the_table_refuses_a_speed_outside_0_to_100(
    db_session: AsyncSession, speed: int
) -> None:
    repo = SqlAlchemyVoiceSettingsRepository(db_session)

    with pytest.raises(IntegrityError):
        await repo.save(
            "am", male_voice_id="am-simon", female_voice_id="am-loza", speed=speed, admin=ADMIN
        )


@pytest.mark.parametrize("speed", [0, 100])
async def test_the_ends_of_the_range_are_allowed(db_session: AsyncSession, speed: int) -> None:
    repo = SqlAlchemyVoiceSettingsRepository(db_session)

    saved = await repo.save(
        "am", male_voice_id="am-simon", female_voice_id="am-loza", speed=speed, admin=ADMIN
    )

    assert saved.speed == speed
