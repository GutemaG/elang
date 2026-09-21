"""The local-only Audio Lab section: real recordings, never production."""

from __future__ import annotations

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db import seed_lesson_content, seed_local_audio
from app.infrastructure.db.lesson_models import CategoryModel, ExerciseModel
from app.infrastructure.db.seed_lesson_content import _content_id
from app.main import MEDIA_DIR

# The clips are git-ignored, so a fresh clone has none to check.
pytestmark = pytest.mark.skipif(
    not (MEDIA_DIR / "audio").is_dir(), reason="no local recordings in backend/media"
)


async def _seed_both(db_session: AsyncSession) -> None:
    await seed_lesson_content.seed(db_session)
    await seed_local_audio.seed(db_session)
    await db_session.commit()


async def test_every_exercise_plays_a_clip_that_exists(db_session: AsyncSession) -> None:
    await _seed_both(db_session)

    lesson_id = _content_id(seed_local_audio.LESSON_SLUG)
    stmt = select(ExerciseModel).where(ExerciseModel.lesson_id == lesson_id)
    exercises = (await db_session.execute(stmt)).scalars().all()

    assert len(exercises) == len(seed_local_audio.RECORDINGS)
    for exercise in exercises:
        assert exercise.type == "listening"
        path = exercise.content["audio_url"].removeprefix("/media/")
        assert (MEDIA_DIR / path).is_file(), exercise.content["audio_url"]


async def test_each_answer_is_the_recordings_meaning(db_session: AsyncSession) -> None:
    await _seed_both(db_session)

    for n, (_, meaning, _) in enumerate(seed_local_audio.RECORDINGS):
        exercise = await db_session.get(
            ExerciseModel, _content_id(f"exercise:local-audio-lab:{n + 1}")
        )
        assert exercise is not None
        correct = next(
            c["text"]
            for c in exercise.content["choices"]
            if c["id"] == exercise.answer_key["correct_choice_id"]
        )
        assert correct == meaning


async def test_the_section_sits_first_in_english_to_amharic(db_session: AsyncSession) -> None:
    await _seed_both(db_session)

    course_id = _content_id(seed_lesson_content.DEFAULT_COURSE_SLUG)
    stmt = (
        select(CategoryModel)
        .where(CategoryModel.course_id == course_id)
        .order_by(CategoryModel.order_index)
    )
    first = (await db_session.execute(stmt)).scalars().first()
    assert first is not None
    assert first.title == "Audio Lab"


async def test_seeding_twice_changes_nothing(db_session: AsyncSession) -> None:
    await _seed_both(db_session)
    await seed_local_audio.seed(db_session)
    await db_session.commit()

    lesson_id = _content_id(seed_local_audio.LESSON_SLUG)
    stmt = select(ExerciseModel).where(ExerciseModel.lesson_id == lesson_id)
    assert len((await db_session.execute(stmt)).scalars().all()) == 4


def test_only_a_sqlite_database_counts_as_local() -> None:
    assert seed_local_audio.is_local("sqlite+aiosqlite:///./dev.db")
    assert not seed_local_audio.is_local("postgresql://u:p@ep-x.neon.tech/neondb")
