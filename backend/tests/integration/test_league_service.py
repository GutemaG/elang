"""Integration tests (023-weekly-leagues, bolt 073, stories 002-004):
joining a week's group, ranking it and leaving it, through the real
`SqlAlchemyLeagueRepository` on a temp-file SQLite database.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.league_use_cases import (
    apply_league_visibility,
    get_current_league,
    join_league_week,
)
from app.domain.entities import User
from app.domain.league import LeagueStatus, LeagueTier, shown_name
from app.domain.value_objects import AuthProvider, DailyXPTarget, LanguageCode, ProviderIdentity
from app.infrastructure.db.league_models import LeagueGroupModel, LeagueMemberModel
from app.infrastructure.db.league_repository import SqlAlchemyLeagueRepository
from app.infrastructure.db.lesson_models import LessonAttemptModel, PracticeAttemptModel
from app.infrastructure.db.lesson_repositories import SqlAlchemyAmoleTransactionRepository
from app.infrastructure.db.repositories import SqlAlchemyUserRepository
from tests.fakes import EN_AM_COURSE_ID

# Wednesday of a league week that starts on Monday 2026-10-05.
NOW = datetime(2026, 10, 7, 12, 0, tzinfo=UTC)
WEEK = date(2026, 10, 5)
WEEK_START = datetime(2026, 10, 5, tzinfo=UTC)


async def _user(
    session: AsyncSession,
    n: int,
    first_name: str | None = None,
    settings: dict[str, Any] | None = None,
) -> User:
    user = User(
        id=f"user-{n:02d}",
        provider_identity=ProviderIdentity(AuthProvider.GOOGLE, f"sub-{n}"),
        selected_language=LanguageCode("am"),
        daily_xp_target=DailyXPTarget(40),
        notification_enabled=True,
        created_at=NOW - timedelta(days=60),
        active_course_id=EN_AM_COURSE_ID,
        settings=settings or {},
        first_name=first_name,
    )
    return await SqlAlchemyUserRepository(session).add(user)


async def _join(repo: SqlAlchemyLeagueRepository, user: User, **kw: Any) -> None:
    args: dict[str, Any] = {"xp_earned": 10, "completed_at": NOW, "now": NOW}
    args.update(kw)
    await join_league_week(user=user, league_repo=repo, amole_repo=_amole(repo), **args)


def _amole(repo: SqlAlchemyLeagueRepository) -> SqlAlchemyAmoleTransactionRepository:
    return SqlAlchemyAmoleTransactionRepository(repo._session)


async def _members(session: AsyncSession) -> int:
    return (await session.execute(select(func.count(LeagueMemberModel.id)))).scalar_one()


def _practice(user_id: str, n: int, xp: int, at: datetime) -> PracticeAttemptModel:
    return PracticeAttemptModel(
        id=f"p-{user_id}-{n}",
        user_id=user_id,
        correct_count=xp // 5,
        total_count=max(xp // 5, 1),
        xp_awarded=xp,
        amole_awarded=10,
        completed_at=at,
    )


def _lesson(user_id: str, n: int, xp: int, at: datetime) -> LessonAttemptModel:
    return LessonAttemptModel(
        id=f"l-{user_id}-{n}",
        user_id=user_id,
        lesson_id="lesson-x",
        correct_count=xp // 5,
        total_count=max(xp // 5, 1),
        xp_awarded=xp,
        completed_at=at,
        result={},
    )


class TestJoining:
    async def test_the_first_xp_of_the_week_joins_the_lowest_tier(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        user = await _user(db_session, 1)

        await _join(repo, user)

        membership = await repo.get_membership(user.id, WEEK)
        assert membership is not None
        assert membership.tier is LeagueTier.GREEN_BEAN
        assert membership.joined_at == NOW

    async def test_a_second_completion_adds_nothing(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        user = await _user(db_session, 1)

        await _join(repo, user)
        await _join(repo, user, now=NOW + timedelta(hours=1))

        assert await _members(db_session) == 1

    async def test_no_xp_an_earlier_week_or_switched_off_never_joins(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        review = await _user(db_session, 1)
        synced_late = await _user(db_session, 2)
        hidden = await _user(db_session, 3, settings={"show_in_leagues": False})

        await _join(repo, review, xp_earned=0)
        await _join(repo, synced_late, completed_at=WEEK_START - timedelta(seconds=1))
        await _join(repo, hidden)

        assert await _members(db_session) == 0

    async def test_xp_from_earlier_in_this_week_synced_now_joins(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        user = await _user(db_session, 1)

        await _join(repo, user, completed_at=WEEK_START)

        assert await repo.get_membership(user.id, WEEK) is not None

    async def test_the_31st_learner_starts_a_new_group(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        users = [await _user(db_session, n) for n in range(31)]

        for user in users:
            await _join(repo, user)

        groups = [
            (await repo.get_membership(u.id, WEEK)).group_id  # type: ignore[union-attr]
            for u in users
        ]
        assert len(set(groups[:30])) == 1
        assert groups[30] != groups[0]

    async def test_learners_join_the_tier_their_last_week_left_them_in(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        climber = await _user(db_session, 1)
        newcomer = await _user(db_session, 2)
        last_week = WEEK - timedelta(days=7)
        old_group = await repo.add_group(last_week, LeagueTier.GREEN_BEAN, NOW)
        await repo.add_member_if_new(old_group, climber.id, last_week, NOW)
        await db_session.execute(
            update(LeagueMemberModel)
            .where(LeagueMemberModel.user_id == climber.id)
            .values(tier_after=LeagueTier.LIGHT_ROAST.value)
        )

        await _join(repo, climber)
        await _join(repo, newcomer)

        mine = await repo.get_membership(climber.id, WEEK)
        theirs = await repo.get_membership(newcomer.id, WEEK)
        assert mine is not None and theirs is not None
        assert mine.tier is LeagueTier.LIGHT_ROAST
        assert theirs.tier is LeagueTier.GREEN_BEAN
        assert mine.group_id != theirs.group_id

    async def test_a_simultaneous_second_join_is_skipped_not_an_error(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        user = await _user(db_session, 1)
        first = await repo.add_group(WEEK, LeagueTier.GREEN_BEAN, NOW)
        second = await repo.add_group(WEEK, LeagueTier.GREEN_BEAN, NOW)

        assert await repo.add_member_if_new(first, user.id, WEEK, NOW) is True
        # As if another request had checked before the first one inserted.
        assert await repo.add_member_if_new(second, user.id, WEEK, NOW) is False

        assert await _members(db_session) == 1
        await db_session.commit()  # The transaction is still usable.

    async def test_closed_groups_are_never_joined(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        closed = await repo.add_group(WEEK, LeagueTier.GREEN_BEAN, NOW)
        await db_session.execute(
            update(LeagueGroupModel).where(LeagueGroupModel.id == closed).values(closed_at=NOW)
        )

        assert await repo.find_open_group(WEEK, LeagueTier.GREEN_BEAN, 30) is None


class TestWeeklyXp:
    async def test_lessons_and_practice_in_the_week_add_up(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        user = await _user(db_session, 1)
        db_session.add_all(
            [
                _lesson(user.id, 1, 20, WEEK_START + timedelta(hours=1)),
                _practice(user.id, 1, 10, WEEK_START + timedelta(days=2)),
                # A review: no XP, and not a "last XP" either.
                _lesson(user.id, 2, 0, WEEK_START + timedelta(days=3)),
                # Outside the week, on both sides.
                _lesson(user.id, 3, 50, WEEK_START - timedelta(seconds=1)),
                _practice(user.id, 2, 50, WEEK_START + timedelta(days=7)),
            ]
        )
        await db_session.flush()

        totals = await repo.weekly_xp([user.id], WEEK_START, WEEK_START + timedelta(days=7))

        assert totals[user.id].xp == 30
        assert totals[user.id].last_xp_at == WEEK_START + timedelta(days=2)

    async def test_learners_with_none_are_left_out(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        assert await repo.weekly_xp(["nobody"], WEEK_START, WEEK_START + timedelta(days=7)) == {}
        assert await repo.weekly_xp([], WEEK_START, WEEK_START + timedelta(days=7)) == {}


class TestCurrentLeague:
    async def test_not_joined_and_hidden(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        quiet = await _user(db_session, 1)
        hidden = await _user(db_session, 2, settings={"show_in_leagues": False})

        for user, status in ((quiet, LeagueStatus.NOT_JOINED), (hidden, LeagueStatus.HIDDEN)):
            league = await get_current_league(
                user=user, now=NOW, league_repo=repo, amole_repo=_amole(repo)
            )
            assert league.status is status
            assert league.tier is LeagueTier.GREEN_BEAN
            assert league.members == []
            assert league.week_ends_at == WEEK_START + timedelta(days=7)

    async def test_the_group_is_ranked_with_names_zones_and_rewards(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        me = await _user(db_session, 1, first_name="Abebe")
        users = [me] + [await _user(db_session, n) for n in range(2, 7)]
        for user in users:
            await _join(repo, user)
        xp = {users[0].id: 15, users[1].id: 40, users[2].id: 15, users[3].id: 5}
        for i, (user_id, amount) in enumerate(xp.items()):
            # users[2] reached 15 before me, so they rank above me.
            at = (
                WEEK_START + timedelta(hours=10 - i) if i != 0 else WEEK_START + timedelta(hours=20)
            )
            db_session.add(_practice(user_id, 1, amount, at))
        await db_session.flush()

        league = await get_current_league(
            user=me, now=NOW, league_repo=repo, amole_repo=_amole(repo)
        )

        assert league.status is LeagueStatus.JOINED
        assert [(m.rank, m.weekly_xp) for m in league.members] == [
            (1, 40),
            (2, 15),
            (3, 15),
            (4, 5),
            (5, 0),
            (6, 0),
        ]
        mine = [m for m in league.members if m.is_me]
        assert len(mine) == 1 and mine[0].rank == 3
        assert (mine[0].name, mine[0].initial) == ("Abebe", "A")
        assert league.members[0].name == shown_name(None, users[1].id)
        assert league.members[0].initial == "L"
        # Six in the lowest tier: two move up, nobody down.
        assert (league.promote_count, league.demote_count) == (2, 0)
        assert league.rewards == (100, 60, 40)

    async def test_members_who_switched_off_are_left_out(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        me = await _user(db_session, 1)
        other = await _user(db_session, 2)
        await _join(repo, me)
        await _join(repo, other)
        repo_users = SqlAlchemyUserRepository(db_session)
        await repo_users.set_settings(other.id, {"show_in_leagues": False})

        league = await get_current_league(
            user=me, now=NOW, league_repo=repo, amole_repo=_amole(repo)
        )

        assert [m.is_me for m in league.members] == [True]


class TestVisibility:
    async def test_switching_off_leaves_this_week_and_keeps_past_weeks(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        user = await _user(db_session, 1)
        last_week = WEEK - timedelta(days=7)
        old = await repo.add_group(last_week, LeagueTier.MEDIUM_ROAST, NOW)
        await repo.add_member_if_new(old, user.id, last_week, NOW)
        await _join(repo, user)

        await apply_league_visibility(
            user=user, settings={"show_in_leagues": False}, now=NOW, league_repo=repo
        )

        assert await repo.get_membership(user.id, WEEK) is None
        # Joining closed last week (alone, so first place moved up to Dark
        # Roast, bolt 074); leaving this week keeps that.
        assert await repo.latest_tier(user.id) is LeagueTier.DARK_ROAST

    async def test_switching_on_changes_nothing(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        user = await _user(db_session, 1)
        await _join(repo, user)

        await apply_league_visibility(
            user=user, settings={"show_in_leagues": True}, now=NOW, league_repo=repo
        )

        assert await repo.get_membership(user.id, WEEK) is not None
