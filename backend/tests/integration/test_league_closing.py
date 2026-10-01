"""Integration tests (023-weekly-leagues, bolt 074, story 005): closing an
ended league week through the real repositories on a temp-file SQLite
database, and the last-week result through HTTP.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import timedelta

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.league_use_cases import (
    close_ended_weeks,
    get_current_league,
    mark_last_result_seen,
)
from app.domain.entities import User
from app.domain.league import LeagueStatus, LeagueTier, Movement
from app.infrastructure.db.league_models import LeagueGroupModel, LeagueMemberModel
from app.infrastructure.db.league_repository import SqlAlchemyLeagueRepository
from app.infrastructure.db.lesson_models import AmoleTransactionModel
from app.infrastructure.db.lesson_repositories import SqlAlchemyAmoleTransactionRepository
from app.infrastructure.db.repositories import SqlAlchemyUserRepository
from tests.fakes import FakeTokenVerifier
from tests.integration.test_league_service import (
    NOW,
    WEEK,
    WEEK_START,
    _amole,
    _join,
    _practice,
    _user,
)

NEXT_WEEK = NOW + timedelta(days=7)


async def _week_of(
    session: AsyncSession, xps: list[int]
) -> tuple[SqlAlchemyLeagueRepository, list[User]]:
    """Learners 0, 1, ... who joined this week and earned these XP, learner
    0 first, so ties keep this order."""
    repo = SqlAlchemyLeagueRepository(session)
    users = [await _user(session, n, first_name=f"L{n}") for n in range(len(xps))]
    for n, (user, xp) in enumerate(zip(users, xps, strict=True)):
        await _join(repo, user)
        session.add(_practice(user.id, 1, xp, WEEK_START + timedelta(hours=n)))
    await session.flush()
    return repo, users


async def _read(repo: SqlAlchemyLeagueRepository, user: User, now=NEXT_WEEK):  # type: ignore[no-untyped-def]
    return await get_current_league(user=user, now=now, league_repo=repo, amole_repo=_amole(repo))


async def _rewards(session: AsyncSession) -> dict[str, int]:
    rows = await session.execute(
        select(AmoleTransactionModel.user_id, func.sum(AmoleTransactionModel.amount))
        .where(AmoleTransactionModel.source == "league_reward")
        .group_by(AmoleTransactionModel.user_id)
    )
    return {user_id: int(total) for user_id, total in rows.all()}


class TestClosing:
    async def test_reading_the_league_after_the_week_closes_it(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [10, 30, 20, 5, 40, 15])

        league = await _read(repo, users[3])

        result = league.last_result
        assert result is not None
        assert (result.week_start, result.tier) == (WEEK, LeagueTier.GREEN_BEAN)
        assert (result.rank, result.group_size, result.weekly_xp) == (6, 6, 5)
        assert (result.tier_after, result.movement) == (LeagueTier.GREEN_BEAN, Movement.STAYED)
        assert league.status is LeagueStatus.NOT_JOINED
        # Six in the lowest tier: the top two move up, nobody moves down.
        tiers = [await repo.latest_tier(u.id) for u in users]
        assert tiers == [
            LeagueTier.GREEN_BEAN,
            LeagueTier.LIGHT_ROAST,
            LeagueTier.GREEN_BEAN,
            LeagueTier.GREEN_BEAN,
            LeagueTier.LIGHT_ROAST,
            LeagueTier.GREEN_BEAN,
        ]
        assert await _rewards(db_session) == {users[4].id: 100, users[1].id: 60, users[2].id: 40}

    async def test_an_open_week_is_never_closed(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [10, 20])

        league = await _read(repo, users[0], now=NOW + timedelta(days=4))

        assert league.last_result is None
        assert league.status is LeagueStatus.JOINED
        assert await _rewards(db_session) == {}

    async def test_the_first_xp_of_the_next_week_closes_it_and_joins_the_new_tier(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [10, 30])

        await _join(repo, users[1], completed_at=NEXT_WEEK, now=NEXT_WEEK)

        membership = await repo.get_membership(users[1].id, WEEK + timedelta(days=7))
        assert membership is not None
        assert membership.tier is LeagueTier.LIGHT_ROAST
        assert await _rewards(db_session) == {users[1].id: 100, users[0].id: 60}

    async def test_closing_twice_changes_nothing_and_pays_once(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [10, 30])
        for user in users:
            await close_ended_weeks(
                user_id=user.id, now=NEXT_WEEK, league_repo=repo, amole_repo=_amole(repo)
            )
        group = (await repo.get_membership(users[0].id, WEEK)).group_id  # type: ignore[union-attr]

        # A second request that arrives late finds it already claimed.
        assert await repo.claim_group(group, NEXT_WEEK) is False
        rows = await db_session.execute(
            select(func.count(AmoleTransactionModel.id)).where(
                AmoleTransactionModel.source == "league_reward"
            )
        )
        assert rows.scalar_one() == 2

    async def test_only_the_learners_own_groups_are_closed(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [10])
        other = await _user(db_session, 50)
        other_group = await repo.add_group(WEEK, LeagueTier.DARK_ROAST, NOW)
        await repo.add_member_if_new(other_group, other.id, WEEK, NOW)

        await _read(repo, users[0])

        closed = await db_session.execute(
            select(LeagueGroupModel.id).where(LeagueGroupModel.closed_at.is_not(None))
        )
        assert other_group not in closed.scalars().all()

    async def test_xp_synced_after_closing_does_not_change_the_result(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [10, 30])
        await _read(repo, users[0])

        # An offline lesson from that week arrives after it closed.
        db_session.add(_practice(users[0].id, 2, 100, WEEK_START + timedelta(days=6)))
        await db_session.flush()
        league = await _read(repo, users[0])

        assert league.last_result is not None
        assert (league.last_result.rank, league.last_result.weekly_xp) == (2, 10)

    async def test_a_learner_away_for_weeks_returns_in_their_last_tier(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [30])
        later = NOW + timedelta(days=28)

        await _join(repo, users[0], completed_at=later, now=later)

        membership = await repo.get_membership(users[0].id, WEEK + timedelta(days=28))
        assert membership is not None
        assert membership.tier is LeagueTier.LIGHT_ROAST

    async def test_a_learner_who_switched_off_after_the_week_gets_no_place(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [50, 10])
        await SqlAlchemyUserRepository(db_session).set_settings(
            users[0].id, {"show_in_leagues": False}
        )

        league = await _read(repo, users[1])

        assert league.last_result is not None
        assert (league.last_result.rank, league.last_result.group_size) == (1, 1)
        assert league.last_result.movement is Movement.UP
        assert await _rewards(db_session) == {users[1].id: 100}
        assert await repo.latest_tier(users[0].id) is LeagueTier.GREEN_BEAN

    async def test_the_result_is_shown_until_seen(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [10])

        assert (await _read(repo, users[0])).last_result is not None
        assert (await _read(repo, users[0])).last_result is not None
        await mark_last_result_seen(user_id=users[0].id, now=NEXT_WEEK, league_repo=repo)
        await mark_last_result_seen(user_id=users[0].id, now=NEXT_WEEK, league_repo=repo)

        assert (await _read(repo, users[0])).last_result is None
        seen = await db_session.execute(
            select(LeagueMemberModel.result_seen_at).where(LeagueMemberModel.user_id == users[0].id)
        )
        assert seen.scalar_one() is not None

    async def test_rewards_show_in_the_amole_history(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [10])
        await _read(repo, users[0])

        amole = SqlAlchemyAmoleTransactionRepository(db_session)
        history = await amole.list_recent(users[0].id, 10)
        assert [(t.source, t.amount) for t in history] == [("league_reward", 100)]
        assert history[0].created_at == WEEK_START + timedelta(days=7)
        assert await amole.sum_by_user(users[0].id) == 100


ClientFactory = Callable[[object, object], TestClient]


class TestLastResultEndpoint:
    def test_sign_in_is_required(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())
        assert client.post("/api/v1/leagues/last-result/seen").status_code == 401

    def test_marking_seen_is_204_and_safe_to_repeat(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())
        token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
        headers = {"Authorization": f"Bearer {token}"}

        for _ in range(2):
            response = client.post("/api/v1/leagues/last-result/seen", headers=headers)
            assert response.status_code == 204
        body = client.get("/api/v1/leagues/current", headers=headers).json()
        assert body["last_result"] is None
