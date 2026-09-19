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
    AmoleTransactionRepository,
    CategoryRepository,
    LessonAttemptRepository,
    LessonRepository,
    PracticeAttemptRepository,
    SkillRepository,
    UserBeansRepository,
    UserSkillProgressRepository,
    UserStreakRepository,
    UserVocabProgressRepository,
    VocabItemRepository,
)
from app.infrastructure.db.lesson_repositories import (
    SqlAlchemyAmoleTransactionRepository,
    SqlAlchemyCategoryRepository,
    SqlAlchemyLessonAttemptRepository,
    SqlAlchemyLessonRepository,
    SqlAlchemyPracticeAttemptRepository,
    SqlAlchemySkillRepository,
    SqlAlchemyUserBeansRepository,
    SqlAlchemyUserSkillProgressRepository,
    SqlAlchemyUserStreakRepository,
    SqlAlchemyUserVocabProgressRepository,
    SqlAlchemyVocabItemRepository,
)
from app.infrastructure.db.session import get_db_session


async def get_skill_repository(
    session: AsyncSession = Depends(get_db_session),
) -> SkillRepository:
    return SqlAlchemySkillRepository(session)


async def get_category_repository(
    session: AsyncSession = Depends(get_db_session),
) -> CategoryRepository:
    return SqlAlchemyCategoryRepository(session)


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


async def get_amole_transaction_repository(
    session: AsyncSession = Depends(get_db_session),
) -> AmoleTransactionRepository:
    return SqlAlchemyAmoleTransactionRepository(session)


async def get_vocab_item_repository(
    session: AsyncSession = Depends(get_db_session),
) -> VocabItemRepository:
    return SqlAlchemyVocabItemRepository(session)


async def get_user_vocab_progress_repository(
    session: AsyncSession = Depends(get_db_session),
) -> UserVocabProgressRepository:
    return SqlAlchemyUserVocabProgressRepository(session)


async def get_practice_attempt_repository(
    session: AsyncSession = Depends(get_db_session),
) -> PracticeAttemptRepository:
    return SqlAlchemyPracticeAttemptRepository(session)
