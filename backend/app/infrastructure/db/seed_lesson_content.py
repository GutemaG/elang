"""Idempotent seed script for story 005: a small, real, hand-authored
English -> Amharic curriculum.

Run with: `uv run python -m app.infrastructure.db.seed_lesson_content`
(from `backend/`).

Not an Alembic data migration (per `ddd-02-technical-design.md`'s Seed
Design section) -- curriculum copy is expected to be edited and re-run
freely during Construction, which a new migration revision per edit would
make painful. Idempotency is achieved via deterministic, slug-derived
content ids (`uuid5(CONTENT_NAMESPACE, slug)`, ADR-3/Decision 3 in the
technical design) rather than natural-key lookups: every skill/lesson/
exercise row is fetched by its deterministic id and either inserted (first
run) or updated in place (subsequent runs) -- never duplicated, never
deleted.

**Known limitation (documented, non-blocking, mirrors how `001-auth-service`
treated missing real OAuth credentials)**: no real Cloudflare R2 bucket or
credentials exist in this environment. `audio_url` values below use a
clearly-marked, non-functional placeholder scheme
(`https://r2-placeholder.buna.dev/audio/<slug>.mp3`) -- swapping in real R2
URLs later is a pure data update (re-run this idempotent script with real
URLs), not a schema or contract change. Flagged again in
`ddd-03-test-report.md`.
"""

from __future__ import annotations

import asyncio
import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import ExerciseModel, LessonModel, SkillModel
from app.infrastructure.db.session import get_session_factory

# Fixed namespace for this project's seeded content -- combined with a
# stable per-item slug via uuid5 to produce a deterministic, UUID-shaped id
# that is identical on every run (idempotency).
CONTENT_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_DNS, "buna.app/lesson-content")


def _content_id(slug: str) -> str:
    return str(uuid.uuid5(CONTENT_NAMESPACE, slug))


def _audio_url(slug: str) -> str:
    return f"https://r2-placeholder.buna.dev/audio/{slug}.mp3"


def _choice(choice_id: str, text: str) -> dict[str, str]:
    return {"id": choice_id, "text": text}


# --- Curriculum content ------------------------------------------------
# 2 skills, 2 lessons each, 4 exercises per lesson (2 multiple_choice,
# 1 listening, 1 sentence_construction -- a mix of all 3 types per lesson,
# per story 005's acceptance criteria). Real, hand-authored English ->
# Amharic vocabulary (Fidel script, UTF-8) -- a small proof-of-loop set,
# not a complete Phase 1 course, per requirements.md's Business Constraints.

CURRICULUM: list[dict[str, Any]] = [
    {
        "slug": "skill:greetings-and-basics",
        "title": "Greetings & Basics",
        "order_index": 1,
        "lessons": [
            {
                "slug": "lesson:greetings-and-basics:hello-and-goodbye",
                "title": "Hello & Goodbye",
                "order_index": 1,
                "exercises": [
                    {
                        "slug": "exercise:hello-and-goodbye:1",
                        "order_index": 1,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Hello' in Amharic?",
                        "content": {
                            "choices": [
                                _choice("a", "ሰላም"),
                                _choice("b", "ደህና ሁን"),
                                _choice("c", "አመሰግናለሁ"),
                                _choice("d", "አይ"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:hello-and-goodbye:2",
                        "order_index": 2,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Goodbye' in Amharic?",
                        "content": {
                            "choices": [
                                _choice("a", "ደህና ሁን"),
                                _choice("b", "ሰላም"),
                                _choice("c", "እባክዎ"),
                                _choice("d", "አዎ"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:hello-and-goodbye:3",
                        "order_index": 3,
                        "type": "listening",
                        "prompt": "What does this word mean?",
                        "content": {
                            "audio_url": _audio_url("greetings-hello"),
                            "choices": [
                                _choice("a", "Hello"),
                                _choice("b", "Goodbye"),
                                _choice("c", "Thank you"),
                                _choice("d", "Please"),
                            ],
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:hello-and-goodbye:4",
                        "order_index": 4,
                        "type": "sentence_construction",
                        "prompt": "Translate: 'I am fine'",
                        "content": {
                            "word_bank": [
                                _choice("w1", "ደህና"),
                                _choice("w2", "ነኝ"),
                                _choice("w3", "ጥሩ"),
                                _choice("w4", "እንደምን"),
                            ]
                        },
                        "answer_key": {"correct_sequence": ["w1", "w2"]},
                    },
                ],
            },
            {
                "slug": "lesson:greetings-and-basics:please-and-thank-you",
                "title": "Please & Thank You",
                "order_index": 2,
                "exercises": [
                    {
                        "slug": "exercise:please-and-thank-you:1",
                        "order_index": 1,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Thank you'?",
                        "content": {
                            "choices": [
                                _choice("a", "አመሰግናለሁ"),
                                _choice("b", "እባክዎ"),
                                _choice("c", "ይቅርታ"),
                                _choice("d", "አዎ"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:please-and-thank-you:2",
                        "order_index": 2,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Please'?",
                        "content": {
                            "choices": [
                                _choice("a", "እባክዎ"),
                                _choice("b", "አመሰግናለሁ"),
                                _choice("c", "ደህና ሁን"),
                                _choice("d", "የለም"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:please-and-thank-you:3",
                        "order_index": 3,
                        "type": "listening",
                        "prompt": "What does this word mean?",
                        "content": {
                            "audio_url": _audio_url("greetings-thank-you"),
                            "choices": [
                                _choice("a", "Thank you"),
                                _choice("b", "Please"),
                                _choice("c", "Yes"),
                                _choice("d", "No"),
                            ],
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:please-and-thank-you:4",
                        "order_index": 4,
                        "type": "sentence_construction",
                        "prompt": "Translate: 'Yes, please'",
                        "content": {
                            "word_bank": [
                                _choice("w1", "አዎ"),
                                _choice("w2", "እባክዎ"),
                                _choice("w3", "አይ"),
                                _choice("w4", "ደህና"),
                            ]
                        },
                        "answer_key": {"correct_sequence": ["w1", "w2"]},
                    },
                ],
            },
        ],
    },
    {
        "slug": "skill:food-and-drink",
        "title": "Food & Drink",
        "order_index": 2,
        "lessons": [
            {
                "slug": "lesson:food-and-drink:coffee-and-tea",
                "title": "Coffee & Tea",
                "order_index": 1,
                "exercises": [
                    {
                        "slug": "exercise:coffee-and-tea:1",
                        "order_index": 1,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Coffee'?",
                        "content": {
                            "choices": [
                                _choice("a", "ቡና"),
                                _choice("b", "ሻይ"),
                                _choice("c", "ውሃ"),
                                _choice("d", "ወተት"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:coffee-and-tea:2",
                        "order_index": 2,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Tea'?",
                        "content": {
                            "choices": [
                                _choice("a", "ሻይ"),
                                _choice("b", "ቡና"),
                                _choice("c", "ውሃ"),
                                _choice("d", "ዳቦ"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:coffee-and-tea:3",
                        "order_index": 3,
                        "type": "listening",
                        "prompt": "What does this word mean?",
                        "content": {
                            "audio_url": _audio_url("food-water"),
                            "choices": [
                                _choice("a", "Water"),
                                _choice("b", "Coffee"),
                                _choice("c", "Tea"),
                                _choice("d", "Bread"),
                            ],
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:coffee-and-tea:4",
                        "order_index": 4,
                        "type": "sentence_construction",
                        "prompt": "Translate: 'I want coffee'",
                        "content": {
                            "word_bank": [
                                _choice("w1", "እፈልጋለሁ"),
                                _choice("w2", "ቡና"),
                                _choice("w3", "ሻይ"),
                                _choice("w4", "ውሃ"),
                            ]
                        },
                        "answer_key": {"correct_sequence": ["w2", "w1"]},
                    },
                ],
            },
            {
                "slug": "lesson:food-and-drink:im-hungry",
                "title": "I'm Hungry",
                "order_index": 2,
                "exercises": [
                    {
                        "slug": "exercise:im-hungry:1",
                        "order_index": 1,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Bread'?",
                        "content": {
                            "choices": [
                                _choice("a", "ዳቦ"),
                                _choice("b", "ምግብ"),
                                _choice("c", "ውሃ"),
                                _choice("d", "ቡና"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:im-hungry:2",
                        "order_index": 2,
                        "type": "multiple_choice",
                        "prompt": "How do you say 'Food'?",
                        "content": {
                            "choices": [
                                _choice("a", "ምግብ"),
                                _choice("b", "ዳቦ"),
                                _choice("c", "ሻይ"),
                                _choice("d", "ውሃ"),
                            ]
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:im-hungry:3",
                        "order_index": 3,
                        "type": "listening",
                        "prompt": "What does this word mean?",
                        "content": {
                            "audio_url": _audio_url("food-migib"),
                            "choices": [
                                _choice("a", "Food"),
                                _choice("b", "Bread"),
                                _choice("c", "Water"),
                                _choice("d", "Coffee"),
                            ],
                        },
                        "answer_key": {"correct_choice_id": "a"},
                    },
                    {
                        "slug": "exercise:im-hungry:4",
                        "order_index": 4,
                        "type": "sentence_construction",
                        "prompt": "Translate: 'I want bread'",
                        "content": {
                            "word_bank": [
                                _choice("w1", "እፈልጋለሁ"),
                                _choice("w2", "ዳቦ"),
                                _choice("w3", "ምግብ"),
                                _choice("w4", "ውሃ"),
                            ]
                        },
                        "answer_key": {"correct_sequence": ["w2", "w1"]},
                    },
                ],
            },
        ],
    },
]


async def seed(session: AsyncSession) -> None:
    """Idempotent: safe to call repeatedly against the same database.

    Each skill/lesson/exercise is fetched by its deterministic id; if
    absent, inserted; if present, updated in place. No rows are ever
    deleted here.
    """
    for skill_data in CURRICULUM:
        skill_id = _content_id(skill_data["slug"])
        skill = await session.get(SkillModel, skill_id)
        if skill is None:
            skill = SkillModel(id=skill_id)
            session.add(skill)
        skill.title = skill_data["title"]
        skill.order_index = skill_data["order_index"]

        for lesson_data in skill_data["lessons"]:
            lesson_id = _content_id(lesson_data["slug"])
            lesson = await session.get(LessonModel, lesson_id)
            if lesson is None:
                lesson = LessonModel(id=lesson_id)
                session.add(lesson)
            lesson.skill_id = skill_id
            lesson.title = lesson_data["title"]
            lesson.order_index = lesson_data["order_index"]

            for exercise_data in lesson_data["exercises"]:
                exercise_id = _content_id(exercise_data["slug"])
                exercise = await session.get(ExerciseModel, exercise_id)
                if exercise is None:
                    exercise = ExerciseModel(id=exercise_id)
                    session.add(exercise)
                exercise.lesson_id = lesson_id
                exercise.order_index = exercise_data["order_index"]
                exercise.type = exercise_data["type"]
                exercise.prompt = exercise_data["prompt"]
                exercise.content = exercise_data["content"]
                exercise.answer_key = exercise_data["answer_key"]

    await session.flush()


async def main() -> None:
    session_factory = get_session_factory()
    async with session_factory() as session:
        await seed(session)
        await session.commit()
    print(  # noqa: T201 -- CLI seed script, intentional operator-facing output
        f"Seeded {len(CURRICULUM)} skills "
        f"({sum(len(s['lessons']) for s in CURRICULUM)} lessons, "
        f"{sum(len(lesson['exercises']) for s in CURRICULUM for lesson in s['lessons'])} "
        "exercises)."
    )


if __name__ == "__main__":
    asyncio.run(main())
