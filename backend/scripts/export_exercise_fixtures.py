"""Exports every seeded exercise for the admin site's round-trip test
(bolt `038-admin-exercise-editors`).

The admin site's exercise forms must send back exactly what the server
stored. The strongest check is to load every exercise the seed creates into
its form and save it unchanged, so the admin tests need that data without a
running backend. This script produces it:

    ./.venv/Scripts/python.exe scripts/export_exercise_fixtures.py

It seeds a throwaway SQLite database in a temporary folder with the main
seed (`seed_lesson_content.seed`), reads the exercises back, and writes
`admin/src/test/data/seeded-exercises.json`. It never opens `dev.db`,
never reads `DATABASE_URL`, and so cannot reach Neon.

Re-run it whenever the seed's exercises change, and commit the result.
"""

from __future__ import annotations

import asyncio
import json
import sys
import tempfile
from pathlib import Path

from sqlalchemy import create_engine, select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

from app.infrastructure.db import lesson_models  # noqa: E402
from app.infrastructure.db.models import Base  # noqa: E402
from app.infrastructure.db.seed_lesson_content import seed  # noqa: E402

OUT = BACKEND.parent / "admin" / "src" / "test" / "data" / "seeded-exercises.json"


async def _export(db: Path) -> list[dict[str, object]]:
    sync_engine = create_engine(f"sqlite:///{db}")
    Base.metadata.create_all(sync_engine)
    sync_engine.dispose()

    engine = create_async_engine(f"sqlite+aiosqlite:///{db}")
    try:
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
            rows = (
                await session.execute(
                    select(lesson_models.ExerciseModel).order_by(
                        lesson_models.ExerciseModel.lesson_id,
                        lesson_models.ExerciseModel.order_index,
                    )
                )
            ).scalars()
            return [
                {
                    "id": row.id,
                    "type": row.type,
                    "prompt": row.prompt,
                    "content": row.content,
                    "answer_key": row.answer_key,
                }
                for row in rows
            ]
    finally:
        await engine.dispose()


def main() -> None:
    with tempfile.TemporaryDirectory() as folder:
        exercises = asyncio.run(_export(Path(folder) / "seed.db"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(exercises, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    counts: dict[str, int] = {}
    for e in exercises:
        counts[str(e["type"])] = counts.get(str(e["type"]), 0) + 1
    print(f"Wrote {len(exercises)} exercises to {OUT.relative_to(BACKEND.parent)}: {counts}")


if __name__ == "__main__":
    main()
