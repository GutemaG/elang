"""Integration tests: real SQLAlchemy models/repositories against a real
temp-file SQLite database (per `data-stack.md`'s local dev/test setup)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.domain.entities import AuthSession, User
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
    SessionToken,
)
from app.infrastructure.db.models import UserModel
from app.infrastructure.db.repositories import (
    SqlAlchemyAuthSessionRepository,
    SqlAlchemyUserRepository,
)
from tests.fakes import EN_AM_COURSE_ID


def _make_user(provider_user_id: str) -> User:
    return User(
        id=str(uuid.uuid4()),
        provider_identity=ProviderIdentity(
            auth_provider=AuthProvider.GOOGLE, provider_user_id=provider_user_id
        ),
        selected_language=LanguageCode(code="am"),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        notification_enabled=True,
        created_at=datetime.now(UTC),
        active_course_id=EN_AM_COURSE_ID,
    )


class TestUserRepository:
    async def test_add_and_find_by_provider_identity_round_trips(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyUserRepository(db_session)
        user = _make_user("google-sub-round-trip")

        await repo.add(user)
        await db_session.commit()

        found = await repo.find_by_provider_identity(AuthProvider.GOOGLE, "google-sub-round-trip")
        assert found is not None
        assert found.id == user.id
        assert found.selected_language.code == "am"
        assert found.daily_xp_target.xp_per_day == 40

    async def test_find_by_provider_identity_returns_none_when_absent(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyUserRepository(db_session)
        found = await repo.find_by_provider_identity(AuthProvider.GOOGLE, "does-not-exist")
        assert found is None

    async def test_get_by_id_round_trips(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyUserRepository(db_session)
        user = _make_user("google-sub-get-by-id")
        await repo.add(user)
        await db_session.commit()

        found = await repo.get_by_id(user.id)
        assert found is not None
        assert found.id == user.id

    async def test_update_persists_language_goal_and_notification(
        self, db_session: AsyncSession
    ) -> None:
        """Bolt 013: `update()` is the one sanctioned post-creation mutation
        path for `selected_language`/`daily_xp_target` (ADR-7), plus the
        freely-mutable `notification_enabled`.
        """
        repo = SqlAlchemyUserRepository(db_session)
        user = _make_user("google-sub-update")
        await repo.add(user)
        await db_session.commit()

        changed = User(
            id=user.id,
            provider_identity=user.provider_identity,
            selected_language=LanguageCode(code="am"),
            daily_xp_target=DailyXPTarget(xp_per_day=80),
            notification_enabled=False,
            created_at=user.created_at,
            active_course_id=EN_AM_COURSE_ID,
        )
        updated = await repo.update(changed)
        await db_session.commit()

        assert updated.daily_xp_target.xp_per_day == 80
        assert updated.notification_enabled is False

        found = await repo.get_by_id(user.id)
        assert found is not None
        assert found.daily_xp_target.xp_per_day == 80
        assert found.notification_enabled is False


class TestAuthSessionRepositoryTimezoneRoundTrip:
    """Bug #2 regression (`implementation-notes.md`, "Deviations from
    Plan"): SQLite does not round-trip timezone-aware datetimes even
    through a `DateTime(timezone=True)` column -- values read back naive,
    which broke `SessionToken.is_expired`'s comparison against
    `datetime.now(timezone.utc)` with a `TypeError`. The fix is
    `_ensure_utc()` in `app/infrastructure/db/repositories.py`. Each test
    here writes through one session/commit, then reads back through a
    brand-new session (forcing a real trip through SQLite storage, not an
    in-memory identity-map hit) to exercise the exact failure path.
    """

    async def test_future_expiry_reads_back_as_aware_and_not_expired(
        self, async_engine: AsyncEngine
    ) -> None:
        factory = async_sessionmaker(bind=async_engine, expire_on_commit=False, autoflush=False)
        user = _make_user("google-sub-tz-1")
        future_expiry = datetime.now(UTC) + timedelta(days=1)

        async with factory() as write_session:
            await SqlAlchemyUserRepository(write_session).add(user)
            await SqlAlchemyAuthSessionRepository(write_session).add(
                AuthSession(
                    id=str(uuid.uuid4()),
                    user_id=user.id,
                    token=SessionToken(
                        value="raw-token-future",
                        issued_at=datetime.now(UTC),
                        expires_at=future_expiry,
                    ),
                )
            )
            await write_session.commit()

        async with factory() as read_session:
            found = await SqlAlchemyAuthSessionRepository(read_session).find_by_token(
                "raw-token-future"
            )

        assert found is not None
        assert found.token.expires_at.tzinfo is not None
        # This comparison is exactly what raised a TypeError before the
        # _ensure_utc() fix (naive vs. aware datetime comparison).
        assert found.token.is_expired(datetime.now(UTC)) is False

    async def test_past_expiry_reads_back_as_expired(self, async_engine: AsyncEngine) -> None:
        factory = async_sessionmaker(bind=async_engine, expire_on_commit=False, autoflush=False)
        user = _make_user("google-sub-tz-2")
        past_expiry = datetime.now(UTC) - timedelta(days=1)

        async with factory() as write_session:
            await SqlAlchemyUserRepository(write_session).add(user)
            await SqlAlchemyAuthSessionRepository(write_session).add(
                AuthSession(
                    id=str(uuid.uuid4()),
                    user_id=user.id,
                    token=SessionToken(
                        value="raw-token-past",
                        issued_at=past_expiry - timedelta(days=1),
                        expires_at=past_expiry,
                    ),
                )
            )
            await write_session.commit()

        async with factory() as read_session:
            found = await SqlAlchemyAuthSessionRepository(read_session).find_by_token(
                "raw-token-past"
            )

        assert found is not None
        assert found.token.expires_at.tzinfo is not None
        assert found.token.is_expired(datetime.now(UTC)) is True

    async def test_find_by_token_returns_none_for_unknown_token(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyAuthSessionRepository(db_session)
        found = await repo.find_by_token("never-issued")
        assert found is None

    async def test_get_by_id_returns_none_for_unknown_session_id(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyAuthSessionRepository(db_session)
        found = await repo.get_by_id(str(uuid.uuid4()))
        assert found is None


class TestModelColumnDefaults:
    """`UserModel.id`/`created_at` have Python-side default factories as a
    safety net, even though every write path in this bolt (via
    `SqlAlchemyUserRepository.add`) always supplies both explicitly from the
    domain layer. Exercised here directly against the ORM model so that
    safety net itself isn't silently broken."""

    async def test_id_and_created_at_defaults_are_applied_when_omitted(
        self, db_session: AsyncSession
    ) -> None:
        model = UserModel(
            auth_provider="google",
            provider_user_id="sub-defaults-1",
            selected_language="am",
            daily_xp_target=40,
            active_course_id=EN_AM_COURSE_ID,
        )
        db_session.add(model)
        await db_session.flush()

        assert model.id
        assert model.created_at is not None
