"""Integration tests: `users.email` storage (ADR-16) through the real
SQLAlchemy user repository."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities import User
from app.domain.value_objects import AuthProvider, DailyXPTarget, LanguageCode, ProviderIdentity
from app.infrastructure.db.repositories import SqlAlchemyUserRepository
from tests.fakes import EN_AM_COURSE_ID


def _user(email: str | None) -> User:
    return User(
        id="user-email-1",
        provider_identity=ProviderIdentity(AuthProvider.GOOGLE, "sub-1"),
        selected_language=LanguageCode("am"),
        daily_xp_target=DailyXPTarget(60),
        notification_enabled=True,
        created_at=datetime.now(UTC),
        active_course_id=EN_AM_COURSE_ID,
        email=email,
    )


async def test_email_round_trips(db_session: AsyncSession) -> None:
    repo = SqlAlchemyUserRepository(db_session)
    await repo.add(_user("admin@example.com"))

    stored = await repo.get_by_id("user-email-1")

    assert stored is not None
    assert stored.email == "admin@example.com"


async def test_set_email_changes_only_the_email(db_session: AsyncSession) -> None:
    repo = SqlAlchemyUserRepository(db_session)
    await repo.add(_user(None))

    updated = await repo.set_email("user-email-1", "new@example.com")
    cleared = await repo.set_email("user-email-1", None)

    assert updated.email == "new@example.com"
    assert cleared.email is None
    assert cleared.daily_xp_target.xp_per_day == 60
    assert cleared.selected_language.code == "am"
