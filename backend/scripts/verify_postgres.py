"""Proves this app's schema and content actually work on PostgreSQL.

Every migration in this repo has only ever run against SQLite, and the test
suite never runs them at all -- it builds the schema with
`Base.metadata.create_all`. So "the tests pass" says nothing about whether
`alembic upgrade head` succeeds on Postgres. This script closes that gap.

It checks four things, in order of how badly each would fail in production:

1. **Migrations apply.** `alembic upgrade head` from an empty database.
2. **Seed content loads.** The real seed, not a fixture.
3. **`ck_exercises_type` survived.** Eight migrations widen `CHECK`
   constraints through `op.batch_alter_table`, which on SQLite rebuilds the
   table and on Postgres emits a plain `DROP`/`ADD`. If the `ADD` half ever
   silently no-ops, the database stops rejecting bad exercise types and
   nothing else would notice -- the ORM's own copy of the constraint is
   declarative, never enforced. This inserts a deliberately invalid row and
   *requires* the database to refuse it.
4. **JSON round-trips.** `content`/`answer_key` are `sa.JSON`, a different
   storage type on Postgres than on SQLite. Every seeded exercise is read
   back and reconstructed into its domain value objects through the same
   two functions the API uses, which is where a JSON difference surfaces.

Usage, from `backend/`, with `DATABASE_URL` pointing at the target:

    ./.venv/Scripts/python.exe scripts/verify_postgres.py

Safe by construction: it refuses to run against SQLite, and its only write
beyond the seed is the step-3 probe, which is rolled back.
"""

from __future__ import annotations

import asyncio
import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

BACKEND_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_ROOT))

from sqlalchemy import func, select  # noqa: E402
from sqlalchemy.exc import DBAPIError, IntegrityError  # noqa: E402

from app.config import get_settings  # noqa: E402
from app.domain.lesson.value_objects import ExerciseType  # noqa: E402
from app.infrastructure.db.lesson_models import (  # noqa: E402
    CourseModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
)
from app.infrastructure.db.lesson_repositories import (  # noqa: E402
    _answer_key_from_json,
    _content_from_json,
)
from app.infrastructure.db.session import get_engine, get_session_factory  # noqa: E402

OK = "  ok  "
FAIL = " FAIL "


class VerificationFailed(Exception):
    pass


def _masked_target(url: str) -> str:
    """Host and database only -- the password never reaches stdout."""
    parts = urlsplit(url)
    return f"{parts.hostname or '?'}{parts.path}"


def _run(args: list[str], what: str) -> None:
    result = subprocess.run(
        args,
        cwd=BACKEND_ROOT,
        capture_output=True,
        text=True,
        # Amharic and Afaan Oromo text in the seed output is not printable
        # under the Windows console's default cp1252.
        env={**os.environ, "PYTHONIOENCODING": "utf-8"},
    )
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        raise VerificationFailed(what)


def step_1_migrations() -> None:
    print("\n1. alembic upgrade head")
    _run([sys.executable, "-m", "alembic", "upgrade", "head"], "migrations did not apply")
    print(f"{OK} all migrations applied")


def step_2_seed() -> None:
    print("\n2. seed content")
    _run(
        [sys.executable, "-m", "app.infrastructure.db.seed_lesson_content"],
        "seeding failed",
    )
    print(f"{OK} seed completed")


async def step_3_check_constraint() -> None:
    print("\n3. ck_exercises_type is enforced by the database itself")
    session_factory = get_session_factory()
    async with session_factory() as session:
        lesson_id = (await session.execute(select(LessonModel.id).limit(1))).scalar_one_or_none()
        if lesson_id is None:
            raise VerificationFailed("no lessons to hang the probe row off -- did the seed run?")
        session.add(
            ExerciseModel(
                id="ck-constraint-probe",
                lesson_id=lesson_id,
                # Negative so it cannot collide with uq_exercises_lesson_order
                # and make a *unique* violation look like a *check* violation.
                order_index=-1,
                type="not_a_real_exercise_type",
                prompt="probe",
                content={},
                answer_key={},
            )
        )
        try:
            await session.flush()
        except (IntegrityError, DBAPIError):
            await session.rollback()
            print(f"{OK} invalid exercise type rejected, as it must be")
            return
        await session.rollback()
        raise VerificationFailed(
            "the database ACCEPTED an exercise typed 'not_a_real_exercise_type'.\n"
            "  ck_exercises_type is missing on Postgres: one of the "
            "batch_alter_table CHECK widenings\n"
            "  dropped it without re-adding it. Nothing else in the system "
            "would have caught this."
        )


async def step_4_read_back() -> None:
    print("\n4. content round-trips out of Postgres JSON columns")
    session_factory = get_session_factory()
    async with session_factory() as session:
        for name, column in (
            ("courses", CourseModel.id),
            ("skills", SkillModel.id),
            ("lessons", LessonModel.id),
            ("exercises", ExerciseModel.id),
        ):
            n = (await session.execute(select(func.count(column)))).scalar_one()
            if n == 0:
                raise VerificationFailed(f"no {name} were seeded")
            print(f"{OK} {n} {name}")

        rows = (await session.execute(select(ExerciseModel))).scalars().all()
        seen: set[str] = set()
        for row in rows:
            exercise_type = ExerciseType(row.type)
            # The same two functions the lesson repository uses. A JSON
            # column that came back as a string rather than a dict, or with
            # its keys reordered into something a value object rejects,
            # fails right here rather than in front of a learner.
            _content_from_json(exercise_type, row.content)
            _answer_key_from_json(exercise_type, row.answer_key)
            seen.add(row.type)
        print(f"{OK} all {len(rows)} exercises rebuilt into domain objects")

        missing = {t.value for t in ExerciseType} - seen
        print(f"{OK} types seeded: {', '.join(sorted(seen))}")
        if missing:
            print(f"       not seeded: {', '.join(sorted(missing))}")


async def main() -> int:
    url = get_settings().database_url
    if not urlsplit(url).scheme.startswith("postgres"):
        print(
            f"{FAIL} DATABASE_URL points at '{urlsplit(url).scheme}', not PostgreSQL.\n"
            "       This script exists to test the Postgres path specifically;\n"
            "       running it against SQLite would prove nothing."
        )
        return 1

    print(f"target: {_masked_target(url)}")
    try:
        step_1_migrations()
        step_2_seed()
        await step_3_check_constraint()
        await step_4_read_back()
    except VerificationFailed as exc:
        print(f"\n{FAIL} {exc}")
        return 1
    finally:
        await get_engine().dispose()

    print("\nAll checks passed -- this schema and content work on PostgreSQL.")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
