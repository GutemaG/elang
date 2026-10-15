"""Integration tests (intent 030, FR-1 to FR-5): the admin Leagues page's
week view, taking a member out of a week, and adjusting weekly XP, through
the real repositories on a temp-file SQLite database; and their effect on
the app's league and on closing.
"""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import admin_league_use_cases as uc
from app.application.league_use_cases import close_ended_weeks, get_current_league
from app.domain.entities import User
from app.domain.league import LeagueStatus, LeagueTier, Movement
from app.domain.lesson.exceptions import (
    InvalidContentError,
    LeagueMemberNotFoundError,
    LeagueWeekClosedError,
)
from app.infrastructure.db.league_models import LeagueMemberModel
from app.infrastructure.db.league_repository import SqlAlchemyLeagueRepository
from app.infrastructure.db.repositories import SqlAlchemyUserRepository
from tests.integration.test_league_closing import _rewards
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
ADMIN = "owner@example.com"


async def _week_of(
    session: AsyncSession, xps: list[int]
) -> tuple[SqlAlchemyLeagueRepository, list[User]]:
    repo = SqlAlchemyLeagueRepository(session)
    users = [await _user(session, n, first_name=f"L{n}") for n in range(len(xps))]
    for n, (user, xp) in enumerate(zip(users, xps, strict=True)):
        await _join(repo, user)
        session.add(_practice(user.id, 1, xp, WEEK_START + timedelta(hours=n)))
    await session.flush()
    return repo, users


async def _member_id(session: AsyncSession, user: User) -> str:
    stmt = select(LeagueMemberModel.id).where(LeagueMemberModel.user_id == user.id)
    return (await session.execute(stmt)).scalars().first() or ""


async def _app_view(repo: SqlAlchemyLeagueRepository, user: User, now=NOW):  # type: ignore[no-untyped-def]
    return await get_current_league(user=user, now=now, league_repo=repo, amole_repo=_amole(repo))


class TestWeek:
    async def test_the_week_ranks_as_the_app_does(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [10, 50, 30])

        week = await uc.get_league_week(repo, week=None, now=NOW)

        assert week.week_start == WEEK and week.is_current
        assert week.weeks == [WEEK]
        (group,) = week.groups
        assert group.tier is LeagueTier.GREEN_BEAN and group.status == "open"
        assert [(m.first_name, m.rank, m.xp) for m in group.members] == [
            ("L1", 1, 50),
            ("L2", 2, 30),
            ("L0", 3, 10),
        ]
        app = await _app_view(repo, users[0])
        assert [r.weekly_xp for r in app.members] == [50, 30, 10]
        assert (group.promote_count, group.demote_count) == (app.promote_count, 0)
        assert week.totals.members == 3 and week.totals.xp == 90
        assert group.members[0].email is None

    async def test_hidden_members_are_listed_last_without_a_place(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [50, 10])
        await SqlAlchemyUserRepository(db_session).set_settings(
            users[0].id, {"show_in_leagues": False}
        )

        (group,) = (await uc.get_league_week(repo, week=None, now=NOW)).groups

        assert [(m.first_name, m.rank, m.hidden) for m in group.members] == [
            ("L1", 1, False),
            ("L0", None, True),
        ]

    async def test_a_future_week_is_refused(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        with pytest.raises(InvalidContentError) as e:
            await uc.get_league_week(repo, week=WEEK + timedelta(days=7), now=NOW)
        assert e.value.field == "week"

    async def test_any_day_picks_its_week(self, db_session: AsyncSession) -> None:
        repo, _ = await _week_of(db_session, [10])

        week = await uc.get_league_week(repo, week=date(2026, 10, 8), now=NOW)

        assert week.week_start == WEEK and len(week.groups) == 1

    async def test_a_past_week_shows_what_closing_stored(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [10, 50])
        await close_ended_weeks(
            user_id=users[0].id, now=NEXT_WEEK, league_repo=repo, amole_repo=_amole(repo)
        )

        week = await uc.get_league_week(repo, week=WEEK, now=NEXT_WEEK)

        assert not week.is_current
        (group,) = week.groups
        assert group.status == "closed"
        assert [
            (m.first_name, m.rank, m.xp, m.movement, m.reward_amole) for m in group.members
        ] == [
            ("L1", 1, 50, Movement.UP, 100),
            ("L0", 2, 10, Movement.STAYED, 60),
        ]

    async def test_an_ended_week_not_closed_yet_is_ranked_live(
        self, db_session: AsyncSession
    ) -> None:
        repo, _ = await _week_of(db_session, [10, 50])

        (group,) = (await uc.get_league_week(repo, week=WEEK, now=NEXT_WEEK)).groups

        assert group.status == "ended"
        assert [m.rank for m in group.members] == [1, 2]


class TestRemove:
    async def test_a_removed_member_leaves_the_others_view(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [50, 30, 10])
        cheat = await _member_id(db_session, users[0])

        member = await uc.remove_member(
            repo, cheat, reason="Bot-like XP", admin_email=ADMIN, now=NOW
        )

        assert member.removed and member.rank is None and member.removed_reason == "Bot-like XP"
        other = await _app_view(repo, users[1])
        assert [(r.name, r.rank) for r in other.members] == [("L1", 1), ("L2", 2)]

    async def test_the_removed_learner_sees_not_joined_and_xp_doesnt_rejoin(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [50, 30])
        await uc.remove_member(
            repo,
            await _member_id(db_session, users[0]),
            reason="Cheating",
            admin_email=ADMIN,
            now=NOW,
        )

        await _join(repo, users[0])

        assert (await _app_view(repo, users[0])).status is LeagueStatus.NOT_JOINED
        rows = (await db_session.execute(select(LeagueMemberModel))).scalars().all()
        assert len(rows) == 2

    async def test_restore_puts_them_back(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [50, 30])
        member_id = await _member_id(db_session, users[0])
        await uc.remove_member(repo, member_id, reason="Cheating", admin_email=ADMIN, now=NOW)

        member = await uc.restore_member(repo, member_id, admin_email=ADMIN, now=NOW)

        assert not member.removed and member.rank == 1
        assert (await _app_view(repo, users[0])).status is LeagueStatus.JOINED

    async def test_closing_gives_a_removed_member_nothing(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [50, 30, 10])
        await uc.remove_member(
            repo,
            await _member_id(db_session, users[0]),
            reason="Cheating",
            admin_email=ADMIN,
            now=NOW,
        )

        await close_ended_weeks(
            user_id=users[1].id, now=NEXT_WEEK, league_repo=repo, amole_repo=_amole(repo)
        )

        assert await _rewards(db_session) == {users[1].id: 100, users[2].id: 60}
        assert await repo.latest_tier(users[0].id) is LeagueTier.GREEN_BEAN
        assert await repo.last_unseen_result(users[0].id) is None
        assert (await repo.last_unseen_result(users[1].id)).rank == 1  # type: ignore[union-attr]

    @pytest.mark.parametrize("reason", [None, "", "  ", "ab", "x" * 201])
    async def test_a_reason_is_required(self, db_session: AsyncSession, reason: str | None) -> None:
        repo, users = await _week_of(db_session, [10])
        with pytest.raises(InvalidContentError) as e:
            await uc.remove_member(
                repo,
                await _member_id(db_session, users[0]),
                reason=reason,
                admin_email=ADMIN,
                now=NOW,
            )
        assert e.value.field == "reason"

    async def test_unknown_members_are_not_found(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLeagueRepository(db_session)
        with pytest.raises(LeagueMemberNotFoundError):
            await uc.remove_member(repo, "missing", reason="Cheating", admin_email=ADMIN, now=NOW)

    async def test_a_past_week_cant_be_changed(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [10])
        member_id = await _member_id(db_session, users[0])
        with pytest.raises(LeagueWeekClosedError):
            await uc.remove_member(
                repo, member_id, reason="Cheating", admin_email=ADMIN, now=NEXT_WEEK
            )
        with pytest.raises(LeagueWeekClosedError):
            await uc.adjust_xp(
                repo, member_id, adjustment=5, reason="Fix", admin_email=ADMIN, now=NEXT_WEEK
            )


class TestAdjustXp:
    async def test_an_adjustment_reranks_the_app_and_the_page(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [50, 30])

        member = await uc.adjust_xp(
            repo,
            await _member_id(db_session, users[1]),
            adjustment=40,
            reason="Lost offline lessons",
            admin_email=ADMIN,
            now=NOW,
        )

        assert (member.rank, member.xp, member.earned_xp, member.xp_adjustment) == (1, 70, 30, 40)
        app = await _app_view(repo, users[0])
        assert [(r.name, r.weekly_xp) for r in app.members] == [("L1", 70), ("L0", 50)]

    async def test_league_xp_never_goes_below_zero(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [50, 30])

        member = await uc.adjust_xp(
            repo,
            await _member_id(db_session, users[0]),
            adjustment=-500,
            reason="Farmed XP",
            admin_email=ADMIN,
            now=NOW,
        )

        assert (member.rank, member.xp) == (2, 0)

    async def test_an_adjustment_replaces_the_last_and_zero_clears_it(
        self, db_session: AsyncSession
    ) -> None:
        repo, users = await _week_of(db_session, [50])
        member_id = await _member_id(db_session, users[0])
        await uc.adjust_xp(repo, member_id, adjustment=10, reason="One", admin_email=ADMIN, now=NOW)
        assert (
            await uc.adjust_xp(
                repo, member_id, adjustment=20, reason="Two", admin_email=ADMIN, now=NOW
            )
        ).xp == 70

        member = await uc.adjust_xp(
            repo, member_id, adjustment=0, reason=None, admin_email=ADMIN, now=NOW
        )

        assert (member.xp, member.xp_adjustment, member.xp_adjustment_reason) == (50, 0, None)

    async def test_closing_uses_the_adjusted_xp(self, db_session: AsyncSession) -> None:
        repo, users = await _week_of(db_session, [50, 30])
        await uc.adjust_xp(
            repo,
            await _member_id(db_session, users[1]),
            adjustment=40,
            reason="Lost offline lessons",
            admin_email=ADMIN,
            now=NOW,
        )

        await close_ended_weeks(
            user_id=users[0].id, now=NEXT_WEEK, league_repo=repo, amole_repo=_amole(repo)
        )

        assert await _rewards(db_session) == {users[1].id: 100, users[0].id: 60}
        result = await repo.last_unseen_result(users[1].id)
        assert result is not None and (result.rank, result.weekly_xp) == (1, 70)

    @pytest.mark.parametrize(
        ("adjustment", "reason", "field"),
        [(10, None, "reason"), (10, "ab", "reason"), (100_001, "Too much", "adjustment")],
    )
    async def test_bad_input_is_refused(
        self, db_session: AsyncSession, adjustment: int, reason: str | None, field: str
    ) -> None:
        repo, users = await _week_of(db_session, [10])
        with pytest.raises(InvalidContentError) as e:
            await uc.adjust_xp(
                repo,
                await _member_id(db_session, users[0]),
                adjustment=adjustment,
                reason=reason,
                admin_email=ADMIN,
                now=NOW,
            )
        assert e.value.field == field
