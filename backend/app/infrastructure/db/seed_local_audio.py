"""Local-only seed: an "Audio Lab" section of English to Amharic whose
listening exercises play real recordings from `backend/media/audio/`.

Run with, from `backend/`:

    DATABASE_URL=sqlite+aiosqlite:///./dev.db \
        uv run python -m app.infrastructure.db.seed_local_audio

Refuses any database but SQLite, so it cannot reach Neon: the clips are
served by the local backend at `/media` (see `main.py`) and are not part of
production content yet. Run the main seed first -- the section belongs to
its English to Amharic course.

To add a recording: put the file in `media/audio/am/`, add a
`(word, meaning, file)` line to `RECORDINGS`, and re-run.
"""

from __future__ import annotations

import asyncio
import sys
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.infrastructure.db.seed_lesson_content import DEFAULT_COURSE_SLUG, seed_content
from app.infrastructure.db.session import get_session_factory

# (Amharic heard, English meaning, clip under media/audio/)
RECORDINGS: list[tuple[str, str, str]] = [
    ("ሰላም", "Hello", "am/hello.m4a"),
    ("አንድ", "One", "am/one.m4a"),
    ("አስር", "Ten", "am/ten.m4a"),
    # The form used to a man.
    ("እንዴት ነህ", "How are you?", "am/how-are-you.m4a"),
]

_CHOICE_IDS = ("a", "b", "c", "d")

CATEGORY_SLUG = "category:local-audio-lab"
SKILL_SLUG = "skill:local-audio-lab"
LESSON_SLUG = "lesson:local-audio-lab:first-recordings"


def _exercises() -> list[dict[str, Any]]:
    meanings = [meaning for _, meaning, _ in RECORDINGS]
    exercises = []
    for n, (_, meaning, clip) in enumerate(RECORDINGS):
        # Four options, the right one moving one place each exercise so it
        # is not always first.
        others = [m for m in meanings if m != meaning][:3]
        options = others[:]
        options.insert(n % 4, meaning)
        exercises.append(
            {
                "slug": f"exercise:local-audio-lab:{n + 1}",
                "order_index": n + 1,
                "type": "listening",
                "prompt": "What does this mean?",
                "content": {
                    "audio_url": f"/media/audio/{clip}",
                    "choices": [
                        {"id": _CHOICE_IDS[i], "text": text} for i, text in enumerate(options)
                    ],
                },
                "answer_key": {"correct_choice_id": _CHOICE_IDS[n % 4]},
            }
        )
    return exercises


# order_index 0: above every other section of the course.
CATEGORIES: list[dict[str, Any]] = [
    {
        "slug": CATEGORY_SLUG,
        "course_slug": DEFAULT_COURSE_SLUG,
        "title": "Audio Lab",
        "subtitle": "የድምጽ ልምምድ",
        "order_index": 0,
    }
]

CURRICULUM: list[dict[str, Any]] = [
    {
        "slug": SKILL_SLUG,
        "category_slug": CATEGORY_SLUG,
        "title": "Listen",
        "order_index": 1,
        "lessons": [
            {
                "slug": LESSON_SLUG,
                "title": "First Recordings",
                "order_index": 1,
                "exercises": _exercises(),
            }
        ],
    }
]


def is_local(database_url: str) -> bool:
    return database_url.startswith("sqlite")


async def seed(session: AsyncSession) -> None:
    await seed_content(
        session, courses=[], vocabulary=[], categories=CATEGORIES, curriculum=CURRICULUM
    )


async def main() -> None:
    if not is_local(get_settings().database_url):
        sys.exit(
            "seed_local_audio only runs against the local SQLite database. "
            "Set DATABASE_URL=sqlite+aiosqlite:///./dev.db"
        )
    session_factory = get_session_factory()
    async with session_factory() as session:
        await seed(session)
        await session.commit()
    print(  # noqa: T201 -- CLI seed script, intentional operator-facing output
        f"Seeded the Audio Lab section: {len(RECORDINGS)} listening exercises."
    )


if __name__ == "__main__":
    asyncio.run(main())
