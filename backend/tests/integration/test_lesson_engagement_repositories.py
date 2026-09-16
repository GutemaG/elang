"""Integration tests for bolt 005's SQLAlchemy repositories, against a real
(temp-file) SQLite database: `UserSkillProgress.upsert`'s fetch-then-
insert-or-update, `UserBeans`/`UserStreak` round trips (including the SQLite
timezone-round-trip normalization other repositories already need), and
`LessonAttempt`'s idempotency-supporting `get`/`add` plus its XP-sum queries.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.domain.lesson.entities import LessonAttempt, UserBeans, UserSkillProgress, UserStreak
from app.domain.lesson.value_objects import LessonCompletionOutcome
from app.infrastructure.db.lesson_models import LessonModel, SkillModel
from app.infrastructure.db.lesson_repositories import (
    SqlAlchemyLessonAttemptRepository,
    SqlAlchemyLessonRepository,
    SqlAlchemyUserBeansRepository,
    SqlAlchemyUserSkillProgressRepository,
    SqlAlchemyUserStreakRepository,
)
from app.infrastructure.db.models import UserModel


async def _make_user(session: AsyncSession, user_id: str = "u1") -> None:
    session.add(
        UserModel(
            id=user_id,
            auth_provider="google",
            provider_user_id=f"sub-{user_id}",
            selected_language="am",
            daily_xp_target=40,
        )
    )
    await session.commit()


def _outcome(**overrides) -> LessonCompletionOutcome:
    defaults = dict(
        xp_awarded=20,
        daily_xp_total=20,
        daily_xp_target=40,
        streak_count=1,
        streak_increased_today=True,
        accuracy_percent=100,
        correct_count=4,
        total_count=4,
        time_spent_seconds=30.0,
    )
    defaults.update(overrides)
    return LessonCompletionOutcome(**defaults)


class TestSqlAlchemyUserSkillProgressRepositoryUpsert:
    async def test_upsert_inserts_a_new_row_when_none_exists(
        self, db_session: AsyncSession
    ) -> None:
        await _make_user(db_session)
        db_session.add(SkillModel(id="s1", title="Greetings & Basics", order_index=1))
        await db_session.commit()

        repo = SqlAlchemyUserSkillProgressRepository(db_session)
        await repo.upsert(
            UserSkillProgress(
                user_id="u1",
                skill_id="s1",
                unlocked=True,
                crown_level=1,
                completed_at=datetime(2026, 1, 1, tzinfo=UTC),
                completed_lesson_ids_this_cycle=frozenset(),
            )
        )
        await db_session.commit()

        stored = await repo.get("u1", "s1")
        assert stored is not None
        assert stored.crown_level == 1

    async def test_upsert_updates_the_existing_row_and_round_trips_the_cycle_set(
        self, db_session: AsyncSession
    ) -> None:
        await _make_user(db_session)
        db_session.add(SkillModel(id="s1", title="Greetings & Basics", order_index=1))
        await db_session.commit()
        repo = SqlAlchemyUserSkillProgressRepository(db_session)
        await repo.upsert(
            UserSkillProgress(
                user_id="u1",
                skill_id="s1",
                unlocked=True,
                crown_level=0,
                completed_at=None,
                completed_lesson_ids_this_cycle=frozenset({"lesson-a1"}),
            )
        )
        await db_session.commit()

        await repo.upsert(
            UserSkillProgress(
                user_id="u1",
                skill_id="s1",
                unlocked=True,
                crown_level=1,
                completed_at=datetime(2026, 1, 1, tzinfo=UTC),
                completed_lesson_ids_this_cycle=frozenset(),
            )
        )
        await db_session.commit()

        # Never two rows for the same (user_id, skill_id) -- the second
        # upsert must have updated, not inserted.
        all_rows = await repo.list_by_user("u1")
        assert len(all_rows) == 1
        assert all_rows[0].crown_level == 1
        assert all_rows[0].completed_lesson_ids_this_cycle == frozenset()

    async def test_get_returns_none_when_no_row_exists(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyUserSkillProgressRepository(db_session)
        assert await repo.get("u1", "no-such-skill") is None


class TestSqlAlchemyUserBeansRepository:
    async def test_upsert_then_get_round_trips_all_fields(self, db_session: AsyncSession) -> None:
        await _make_user(db_session)
        repo = SqlAlchemyUserBeansRepository(db_session)

        await repo.upsert(
            UserBeans(
                user_id="u1",
                current_count=3,
                last_regen_at=datetime(2026, 9, 16, 10, 0, tzinfo=UTC),
                amole_balance=250,
            )
        )
        await db_session.commit()

        # Force a real round trip through a fresh session (SQLite doesn't
        # persist tzinfo even on a `DateTime(timezone=True)` column).
        factory = async_sessionmaker(bind=db_session.bind, expire_on_commit=False, autoflush=False)
        async with factory() as fresh_session:
            stored = await SqlAlchemyUserBeansRepository(fresh_session).get("u1")

        assert stored is not None
        assert stored.current_count == 3
        assert stored.amole_balance == 250
        assert stored.last_regen_at.tzinfo is not None

    async def test_get_returns_none_when_no_row_exists(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyUserBeansRepository(db_session)
        assert await repo.get("no-such-user") is None

    async def test_second_upsert_updates_rather_than_duplicates(
        self, db_session: AsyncSession
    ) -> None:
        await _make_user(db_session)
        repo = SqlAlchemyUserBeansRepository(db_session)
        now = datetime(2026, 9, 16, 10, 0, tzinfo=UTC)

        await repo.upsert(
            UserBeans(user_id="u1", current_count=5, last_regen_at=now, amole_balance=500)
        )
        await db_session.commit()
        await repo.upsert(
            UserBeans(user_id="u1", current_count=2, last_regen_at=now, amole_balance=150)
        )
        await db_session.commit()

        stored = await repo.get("u1")
        assert stored is not None
        assert stored.current_count == 2
        assert stored.amole_balance == 150


class TestSqlAlchemyUserStreakRepository:
    async def test_upsert_then_get_round_trips_the_date(self, db_session: AsyncSession) -> None:
        await _make_user(db_session)
        repo = SqlAlchemyUserStreakRepository(db_session)

        await repo.upsert(
            UserStreak(
                user_id="u1",
                current_streak=6,
                last_completed_date=date(2026, 9, 16),
                active_freeze_count=1,
            )
        )
        await db_session.commit()

        stored = await repo.get("u1")
        assert stored is not None
        assert stored.current_streak == 6
        assert stored.last_completed_date == date(2026, 9, 16)
        assert stored.active_freeze_count == 1

    async def test_get_returns_none_when_no_row_exists(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyUserStreakRepository(db_session)
        assert await repo.get("no-such-user") is None


class TestSqlAlchemyLessonAttemptRepository:
    async def test_add_then_get_round_trips_the_full_outcome(
        self, db_session: AsyncSession
    ) -> None:
        await _make_user(db_session)
        db_session.add(SkillModel(id="s1", title="Greetings & Basics", order_index=1))
        db_session.add(LessonModel(id="l1", skill_id="s1", title="Hello", order_index=1))
        await db_session.commit()

        repo = SqlAlchemyLessonAttemptRepository(db_session)
        outcome = _outcome(skill_unlocked_title="Food & Drink", crown_level=1)
        await repo.add(
            LessonAttempt(
                id="attempt-1",
                user_id="u1",
                lesson_id="l1",
                correct_count=4,
                total_count=4,
                xp_awarded=20,
                completed_at=datetime(2026, 9, 16, 12, 0, tzinfo=UTC),
                outcome=outcome,
            )
        )
        await db_session.commit()

        stored = await repo.get("attempt-1")
        assert stored is not None
        assert stored.outcome == outcome

    async def test_get_returns_none_for_unknown_attempt_id(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLessonAttemptRepository(db_session)
        assert await repo.get("does-not-exist") is None

    async def test_sum_xp_by_user_sums_across_all_attempts(self, db_session: AsyncSession) -> None:
        await _make_user(db_session)
        db_session.add(SkillModel(id="s1", title="Greetings & Basics", order_index=1))
        db_session.add(LessonModel(id="l1", skill_id="s1", title="Hello", order_index=1))
        await db_session.commit()
        repo = SqlAlchemyLessonAttemptRepository(db_session)
        for i, (xp, day) in enumerate([(20, 15), (15, 16), (10, 16)]):
            await repo.add(
                LessonAttempt(
                    id=f"attempt-{i}",
                    user_id="u1",
                    lesson_id="l1",
                    correct_count=4,
                    total_count=4,
                    xp_awarded=xp,
                    completed_at=datetime(2026, 9, day, 12, 0, tzinfo=UTC),
                    outcome=_outcome(xp_awarded=xp),
                )
            )
        await db_session.commit()

        assert await repo.sum_xp_by_user("u1") == 45

    async def test_sum_xp_by_user_between_only_counts_the_given_day_range(
        self, db_session: AsyncSession
    ) -> None:
        await _make_user(db_session)
        db_session.add(SkillModel(id="s1", title="Greetings & Basics", order_index=1))
        db_session.add(LessonModel(id="l1", skill_id="s1", title="Hello", order_index=1))
        await db_session.commit()
        repo = SqlAlchemyLessonAttemptRepository(db_session)
        for i, (xp, day) in enumerate([(20, 15), (15, 16), (10, 17)]):
            await repo.add(
                LessonAttempt(
                    id=f"attempt-{i}",
                    user_id="u1",
                    lesson_id="l1",
                    correct_count=4,
                    total_count=4,
                    xp_awarded=xp,
                    completed_at=datetime(2026, 9, day, 12, 0, tzinfo=UTC),
                    outcome=_outcome(xp_awarded=xp),
                )
            )
        await db_session.commit()

        total = await repo.sum_xp_by_user_between("u1", date(2026, 9, 16), date(2026, 9, 17))
        assert total == 15

    async def test_sum_xp_returns_zero_when_no_attempts_exist(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLessonAttemptRepository(db_session)
        assert await repo.sum_xp_by_user("no-such-user") == 0


class TestSqlAlchemyLessonRepositoryListLessonIdsBySkill:
    async def test_returns_every_lesson_id_for_the_skill_only(
        self, db_session: AsyncSession
    ) -> None:
        db_session.add_all(
            [
                SkillModel(id="s1", title="Greetings & Basics", order_index=1),
                SkillModel(id="s2", title="Food & Drink", order_index=2),
            ]
        )
        db_session.add_all(
            [
                # Inserted out of order_index order deliberately -- proves
                # the result is ordered by order_index, not insertion order.
                LessonModel(id="l2", skill_id="s1", title="Goodbye", order_index=2),
                LessonModel(id="l1", skill_id="s1", title="Hello", order_index=1),
                LessonModel(id="l3", skill_id="s2", title="Coffee", order_index=1),
            ]
        )
        await db_session.commit()

        repo = SqlAlchemyLessonRepository(db_session)
        ids = await repo.list_lesson_ids_by_skill("s1")

        assert ids == ("l1", "l2")


class TestSqlAlchemyLessonRepositoryListLessonIdsBySkills:
    async def test_groups_lesson_ids_by_skill_in_one_query(self, db_session: AsyncSession) -> None:
        db_session.add_all(
            [
                SkillModel(id="s1", title="Greetings & Basics", order_index=1),
                SkillModel(id="s2", title="Food & Drink", order_index=2),
                SkillModel(id="s3", title="No Lessons Yet", order_index=3),
            ]
        )
        db_session.add_all(
            [
                LessonModel(id="l2", skill_id="s1", title="Goodbye", order_index=2),
                LessonModel(id="l1", skill_id="s1", title="Hello", order_index=1),
                LessonModel(id="l3", skill_id="s2", title="Coffee", order_index=1),
            ]
        )
        await db_session.commit()

        repo = SqlAlchemyLessonRepository(db_session)
        grouped = await repo.list_lesson_ids_by_skills(["s1", "s2", "s3"])

        assert grouped == {"s1": ("l1", "l2"), "s2": ("l3",)}
        assert "s3" not in grouped  # no lessons -- absent, not an empty tuple

    async def test_returns_empty_dict_for_an_empty_skill_id_list(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLessonRepository(db_session)
        assert await repo.list_lesson_ids_by_skills([]) == {}
