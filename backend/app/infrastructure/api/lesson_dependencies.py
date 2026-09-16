"""FastAPI dependency wiring for the lesson-content bounded context: builds
per-request repository implementations bound to the request's
`AsyncSession`. Authentication is handled by the shared `get_current_user`
dependency in `app/infrastructure/api/dependencies.py` (reused, not
duplicated).
"""

from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.lesson.repositories import (
    LessonAttemptRepository,
    LessonRepository,
    SkillRepository,
    UserBeansRepository,
    UserSkillProgressRepository,
    UserStreakRepository,
)
from app.infrastructure.db.lesson_repositories import (
    SqlAlchemyLessonAttemptRepository,
    SqlAlchemyLessonRepository,
    SqlAlchemySkillRepository,
    SqlAlchemyUserBeansRepository,
    SqlAlchemyUserSkillProgressRepository,
    SqlAlchemyUserStreakRepository,
)
from app.infrastructure.db.session import get_db_session


async def get_skill_repository(
    session: AsyncSession = Depends(get_db_session),
) -> SkillRepository:
    return SqlAlchemySkillRepository(session)


async def get_lesson_repository(
    session: AsyncSession = Depends(get_db_session),
) -> LessonRepository:
    return SqlAlchemyLessonRepository(session)


async def get_user_skill_progress_repository(
    session: AsyncSession = Depends(get_db_session),
) -> UserSkillProgressRepository:
    return SqlAlchemyUserSkillProgressRepository(session)


async def get_user_beans_repository(
    session: AsyncSession = Depends(get_db_session),
) -> UserBeansRepository:
    return SqlAlchemyUserBeansRepository(session)


async def get_user_streak_repository(
    session: AsyncSession = Depends(get_db_session),
) -> UserStreakRepository:
    return SqlAlchemyUserStreakRepository(session)


async def get_lesson_attempt_repository(
    session: AsyncSession = Depends(get_db_session),
) -> LessonAttemptRepository:
    return SqlAlchemyLessonAttemptRepository(session)
