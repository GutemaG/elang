"""Local-only seed: a "Picture Lab" section of English to Amharic with sample
questions of both picture types (bolt `051-image-choice-samples`).

Run with, from `backend/`:

    DATABASE_URL=sqlite+aiosqlite:///./dev.db \
        uv run python -m app.infrastructure.db.seed_local_pictures

Refuses any database but SQLite, so it cannot reach Neon: the pictures are
served by the local backend at `/media/images/samples/` and are not part of
production content yet. Run the main seed first -- the section belongs to
its English to Amharic course.

The pictures are committed in `backend/sample_pictures/` (built by
`scripts/build_sample_pictures.py`, credited in its `credits.json`) and
copied into `backend/media/images/samples/` on every run. The audio
questions play the Audio Lab's recordings (`seed_local_audio.py`), which
are git-ignored: on a machine without them the questions still seed, but
have no sound.

Each question is linked to its own vocabulary word, which no other
question uses, so practice shows it once the lesson is done. Like the main
seed it is insert-only: re-running adds nothing twice and does not change
rows it already created.
"""

from __future__ import annotations

import asyncio
import shutil
import sys
from pathlib import Path
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.infrastructure.db.seed_lesson_content import DEFAULT_COURSE_SLUG, seed_content
from app.infrastructure.db.seed_local_audio import is_local
from app.infrastructure.db.session import get_session_factory
from app.infrastructure.media import IMAGES_DIR, IMAGES_URL_PREFIX

SAMPLE_PICTURES_DIR = Path(__file__).resolve().parents[3] / "sample_pictures"
SAMPLES_SUBDIR = "samples"

# Every picture a question below shows, with its alt text.
ALT_TEXT: dict[str, str] = {
    "water.webp": "A drop of water",
    "dog.webp": "A dog",
    "house.webp": "A house",
    "cat.webp": "A cat",
    "sun.webp": "The sun",
    "number-1.webp": "The number 1",
    "number-2.webp": "The number 2",
    "number-5.webp": "The number 5",
    "number-10.webp": "The number 10",
}

# (Amharic word, English meaning, the picture that is the answer)
IMAGE_WORDS: list[tuple[str, str, str]] = [
    ("ውሃ", "Water", "water.webp"),
    ("ውሻ", "Dog", "dog.webp"),
    ("ቤት", "House", "house.webp"),
]
_IMAGE_POOL = ["water.webp", "dog.webp", "house.webp", "cat.webp", "sun.webp"]

# (Amharic word, English meaning, the picture that is the answer, clip
# under media/audio/)
AUDIO_WORDS: list[tuple[str, str, str, str]] = [
    ("አንድ", "One", "number-1.webp", "am/one.m4a"),
    ("አስር", "Ten", "number-10.webp", "am/ten.m4a"),
]
_AUDIO_POOL = ["number-1.webp", "number-2.webp", "number-5.webp", "number-10.webp"]

_CHOICE_IDS = ("a", "b", "c", "d")

CATEGORY_SLUG = "category:local-picture-lab"
SKILL_SLUG = "skill:local-picture-lab"
LESSON_SLUG = "lesson:local-picture-lab:first-pictures"


def _vocab_slug(meaning: str) -> str:
    return f"vocab:local-picture-lab:{meaning.lower()}"


def picture_url(file: str) -> str:
    return f"{IMAGES_URL_PREFIX}/{SAMPLES_SUBDIR}/{file}"


def _choices(answer: str, pool: list[str], n: int) -> tuple[list[dict[str, str]], str]:
    """Four pictures from `pool`, the answer moving one place each question
    so it is not always first. The wrong pictures rotate through the pool
    too, so every picture is shown somewhere. Returns the choices and the
    answer's id."""
    others = [p for p in pool if p != answer]
    shift = n % len(others)
    pictures = (others[shift:] + others[:shift])[:3]
    pictures.insert(n % 4, answer)
    choices = [
        {"id": _CHOICE_IDS[i], "image_url": picture_url(p), "alt_text": ALT_TEXT[p]}
        for i, p in enumerate(pictures)
    ]
    return choices, _CHOICE_IDS[n % 4]


def _exercises() -> list[dict[str, Any]]:
    exercises: list[dict[str, Any]] = []
    for word, meaning, answer in IMAGE_WORDS:
        n = len(exercises)
        choices, correct = _choices(answer, _IMAGE_POOL, n)
        exercises.append(
            {
                "slug": f"exercise:local-picture-lab:{n + 1}",
                "order_index": n + 1,
                "type": "image_choice",
                "prompt": f"Choose the picture: '{word}'",
                "content": {"choices": choices},
                "answer_key": {"correct_choice_id": correct},
                "vocab_slug": _vocab_slug(meaning),
            }
        )
    for _, meaning, answer, clip in AUDIO_WORDS:
        n = len(exercises)
        choices, correct = _choices(answer, _AUDIO_POOL, n)
        exercises.append(
            {
                "slug": f"exercise:local-picture-lab:{n + 1}",
                "order_index": n + 1,
                "type": "audio_image_choice",
                "prompt": "Tap the picture you hear",
                "content": {"audio_url": f"/media/audio/{clip}", "choices": choices},
                "answer_key": {"correct_choice_id": correct},
                "vocab_slug": _vocab_slug(meaning),
            }
        )
    return exercises


VOCABULARY: list[dict[str, str]] = [
    {"slug": _vocab_slug(meaning), "word": word, "translation": meaning}
    for word, meaning, *_ in [*IMAGE_WORDS, *AUDIO_WORDS]
]

# order_index -1: above the Audio Lab (0) and every other section of the
# course; positions are unique within a course.
CATEGORIES: list[dict[str, Any]] = [
    {
        "slug": CATEGORY_SLUG,
        "course_slug": DEFAULT_COURSE_SLUG,
        "title": "Picture Lab",
        "subtitle": "የስዕል ልምምድ",
        "order_index": -1,
    }
]

CURRICULUM: list[dict[str, Any]] = [
    {
        "slug": SKILL_SLUG,
        "category_slug": CATEGORY_SLUG,
        "title": "Pictures",
        "order_index": 1,
        "lessons": [
            {
                "slug": LESSON_SLUG,
                "title": "First Pictures",
                "order_index": 1,
                "exercises": _exercises(),
            }
        ],
    }
]


def copy_pictures(target: Path | None = None) -> Path:
    """Copies every committed sample picture to where the local backend
    serves it, overwriting, so a rebuilt picture always reaches `media`."""
    target = target or IMAGES_DIR / SAMPLES_SUBDIR
    target.mkdir(parents=True, exist_ok=True)
    for file in ALT_TEXT:
        shutil.copyfile(SAMPLE_PICTURES_DIR / file, target / file)
    return target


async def seed(session: AsyncSession) -> None:
    await seed_content(
        session, courses=[], vocabulary=VOCABULARY, categories=CATEGORIES, curriculum=CURRICULUM
    )


async def main() -> None:
    if not is_local(get_settings().database_url):
        sys.exit(
            "seed_local_pictures only runs against the local SQLite database. "
            "Set DATABASE_URL=sqlite+aiosqlite:///./dev.db"
        )
    copy_pictures()
    session_factory = get_session_factory()
    async with session_factory() as session:
        await seed(session)
        await session.commit()
    print(  # noqa: T201 -- CLI seed script, intentional operator-facing output
        f"Seeded the Picture Lab section: {len(IMAGE_WORDS)} image choice and "
        f"{len(AUDIO_WORDS)} audio image choice questions."
    )


if __name__ == "__main__":
    asyncio.run(main())
