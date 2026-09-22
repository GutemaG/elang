"""Integration tests: the seed is insert-only (story 002-seed-insert-only,
bolt 034-admin-api-foundation). The database is the source of truth for
content, so a re-seed never changes a row that already exists.

Uses small content of its own through `seed_content`, so it never mutates
the real curriculum lists other tests read.
"""

from __future__ import annotations

import copy
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
    VocabItemModel,
)
from app.infrastructure.db.seed_lesson_content import (
    CATEGORIES,
    COURSES,
    CURRICULUM,
    VOCABULARY,
    _content_id,
    seed,
    seed_content,
)

COURSE_SLUG = "course:test-insert-only"


def _exercise(n: int) -> dict[str, Any]:
    return {
        "slug": f"exercise:test-insert-only:{n}",
        "order_index": n,
        "type": "multiple_choice",
        "prompt": f"Prompt {n}",
        "content": {"choices": [{"id": "a", "text": "A"}, {"id": "b", "text": "B"}]},
        "answer_key": {"correct_choice_id": "a"},
    }


def _content() -> dict[str, Any]:
    return {
        "courses": [
            {
                "slug": COURSE_SLUG,
                "learning_language": "om",
                "from_language": "am",
                "title": "Test Course",
                "status": "available",
                "order_index": 99,
            }
        ],
        "vocabulary": [
            {
                "slug": "vocab:test-insert-only",
                "course_slug": COURSE_SLUG,
                "word": "w",
                "translation": "t",
            }
        ],
        "categories": [
            {
                "slug": "category:test-insert-only",
                "course_slug": COURSE_SLUG,
                "title": "Section",
                "subtitle": "Sub",
                "order_index": 1,
            }
        ],
        "curriculum": [
            {
                "slug": "skill:test-insert-only",
                "category_slug": "category:test-insert-only",
                "title": "Skill",
                "order_index": 1,
                "lessons": [
                    {
                        "slug": "lesson:test-insert-only",
                        "title": "Lesson",
                        "order_index": 1,
                        "exercises": [_exercise(1), _exercise(2)],
                    }
                ],
            }
        ],
    }


async def _count(session: AsyncSession, model: type) -> int:
    return (await session.execute(select(func.count()).select_from(model))).scalar_one()


async def test_fresh_seed_inserts_every_row_of_the_real_content(db_session: AsyncSession) -> None:
    await seed(db_session)
    await db_session.commit()

    lessons = [lesson for skill in CURRICULUM for lesson in skill["lessons"]]
    # The test database starts with the en-am course already (conftest).
    assert await _count(db_session, CourseModel) == len({c["slug"] for c in COURSES})
    assert await _count(db_session, VocabItemModel) == len(VOCABULARY)
    assert await _count(db_session, CategoryModel) == len(CATEGORIES)
    assert await _count(db_session, SkillModel) == len(CURRICULUM)
    assert await _count(db_session, LessonModel) == len(lessons)
    assert await _count(db_session, ExerciseModel) == sum(len(x["exercises"]) for x in lessons)


async def test_changes_in_seed_code_do_not_reach_existing_rows(db_session: AsyncSession) -> None:
    await seed_content(db_session, **_content())
    await db_session.commit()

    changed = _content()
    changed["courses"][0]["title"] = "Changed"
    changed["vocabulary"][0]["word"] = "changed"
    changed["categories"][0]["title"] = "Changed"
    changed["curriculum"][0]["title"] = "Changed"
    changed["curriculum"][0]["lessons"][0]["title"] = "Changed"
    changed["curriculum"][0]["lessons"][0]["exercises"][0]["prompt"] = "Changed"
    await seed_content(db_session, **changed)
    await db_session.commit()

    assert (await db_session.get(CourseModel, _content_id(COURSE_SLUG))).title == "Test Course"
    vocab = await db_session.get(VocabItemModel, _content_id("vocab:test-insert-only"))
    assert vocab.word == "w"
    category = await db_session.get(CategoryModel, _content_id("category:test-insert-only"))
    assert category.title == "Section"
    assert (
        await db_session.get(SkillModel, _content_id("skill:test-insert-only"))
    ).title == "Skill"
    lesson = await db_session.get(LessonModel, _content_id("lesson:test-insert-only"))
    assert lesson.title == "Lesson"
    exercise = await db_session.get(ExerciseModel, _content_id("exercise:test-insert-only:1"))
    assert exercise.prompt == "Prompt 1"


async def test_an_admin_edit_survives_a_re_seed(db_session: AsyncSession) -> None:
    await seed_content(db_session, **_content())
    await db_session.commit()

    exercise_id = _content_id("exercise:test-insert-only:1")
    exercise = await db_session.get(ExerciseModel, exercise_id)
    exercise.content = {
        "audio_url": "https://cdn.example/a.m4a",
        "choices": exercise.content["choices"],
    }
    exercise.prompt = "Edited"
    await db_session.commit()

    await seed_content(db_session, **_content())
    await db_session.commit()

    await db_session.refresh(exercise)
    assert exercise.prompt == "Edited"
    assert exercise.content["audio_url"] == "https://cdn.example/a.m4a"


async def test_a_new_exercise_under_an_existing_lesson_is_inserted(
    db_session: AsyncSession,
) -> None:
    await seed_content(db_session, **_content())
    await db_session.commit()

    grown = copy.deepcopy(_content())
    grown["curriculum"][0]["lessons"][0]["exercises"].append(_exercise(3))
    await seed_content(db_session, **grown)
    await db_session.commit()

    new = await db_session.get(ExerciseModel, _content_id("exercise:test-insert-only:3"))
    assert new is not None
    assert new.lesson_id == _content_id("lesson:test-insert-only")


async def test_a_deleted_seeded_row_comes_back(db_session: AsyncSession) -> None:
    """Documented consequence: insert-only cannot tell "deleted" from
    "never seeded"."""
    await seed_content(db_session, **_content())
    await db_session.commit()

    exercise_id = _content_id("exercise:test-insert-only:2")
    await db_session.delete(await db_session.get(ExerciseModel, exercise_id))
    await db_session.commit()

    await seed_content(db_session, **_content())
    await db_session.commit()

    assert await db_session.get(ExerciseModel, exercise_id) is not None


async def test_seeding_twice_writes_nothing(db_session: AsyncSession) -> None:
    await seed_content(db_session, **_content())
    await db_session.commit()
    exercise = await db_session.get(ExerciseModel, _content_id("exercise:test-insert-only:1"))
    stamp = exercise.updated_at

    await seed_content(db_session, **_content())
    await db_session.commit()

    await db_session.refresh(exercise)
    # `updated_at` has `onupdate`, so any write would have moved it.
    assert exercise.updated_at == stamp
