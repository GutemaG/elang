"""Integration tests for the idempotent curriculum seed script (story 005).

Verifies the acceptance criteria directly: at least 2 skills each with
multiple lessons, each lesson containing at least the original 3 exercise
types (a floor, not a ceiling -- see `004-match-pairs-exercise-type`'s 5th
exercise on "Coffee & Tea"), real Amharic content, idempotent re-runs, and
the documented audio placeholder scheme.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import ExerciseModel, LessonModel, SkillModel
from app.infrastructure.db.seed_lesson_content import CURRICULUM, seed


class TestSeedIdempotency:
    async def test_running_seed_twice_produces_no_duplicate_rows(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        skill_count_1 = len((await db_session.execute(select(SkillModel))).scalars().all())
        lesson_count_1 = len((await db_session.execute(select(LessonModel))).scalars().all())
        exercise_count_1 = len((await db_session.execute(select(ExerciseModel))).scalars().all())

        await seed(db_session)
        await db_session.commit()

        skill_count_2 = len((await db_session.execute(select(SkillModel))).scalars().all())
        lesson_count_2 = len((await db_session.execute(select(LessonModel))).scalars().all())
        exercise_count_2 = len((await db_session.execute(select(ExerciseModel))).scalars().all())

        assert skill_count_1 == skill_count_2
        assert lesson_count_1 == lesson_count_2
        assert exercise_count_1 == exercise_count_2

    async def test_re_running_seed_after_editing_content_updates_in_place(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        original_title = CURRICULUM[0]["title"]
        CURRICULUM[0]["title"] = "Edited Title For Idempotency Test"
        try:
            await seed(db_session)
            await db_session.commit()

            stmt = select(SkillModel).where(SkillModel.order_index == 1)
            result = await db_session.execute(stmt)
            skill = result.scalar_one()
            assert skill.title == "Edited Title For Idempotency Test"
        finally:
            CURRICULUM[0]["title"] = original_title


class TestSeedContentAcceptanceCriteria:
    async def test_seeds_at_least_2_skills_each_with_multiple_lessons(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        skills = (await db_session.execute(select(SkillModel))).scalars().all()
        assert len(skills) >= 2

        for skill in skills:
            stmt = select(LessonModel).where(LessonModel.skill_id == skill.id)
            lessons = (await db_session.execute(stmt)).scalars().all()
            assert len(lessons) >= 2, f"skill {skill.title!r} has fewer than 2 lessons"

    async def test_every_lesson_has_a_mix_of_at_least_3_exercise_types(
        self, db_session: AsyncSession
    ) -> None:
        # `>=`, not `==`: story 005's original 3-type mix is a floor, not a
        # ceiling -- 004-match-pairs-exercise-type (bolt 011) added a 5th
        # exercise (match_pairs) to one lesson ("Coffee & Tea") without
        # touching the other lessons' original 4-exercise/3-type shape.
        await seed(db_session)
        await db_session.commit()

        lessons = (await db_session.execute(select(LessonModel))).scalars().all()
        assert len(lessons) >= 1

        for lesson in lessons:
            exercises = (
                (
                    await db_session.execute(
                        select(ExerciseModel).where(ExerciseModel.lesson_id == lesson.id)
                    )
                )
                .scalars()
                .all()
            )
            types = {e.type for e in exercises}
            assert types >= {"multiple_choice", "listening", "sentence_construction"}, (
                f"lesson {lesson.title!r} is missing an exercise type: {types}"
            )

    async def test_content_is_real_amharic_fidel_script_not_placeholder_text(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        exercises = (await db_session.execute(select(ExerciseModel))).scalars().all()
        assert len(exercises) >= 1

        # Checked against the prompt + tile text only -- deliberately
        # excludes `audio_url`, which legitimately contains the substring
        # "placeholder" as part of its documented, intentional stub scheme
        # (see the listening-exercise test below), not lorem-ipsum filler.
        lorem_markers = {"lorem", "ipsum", "placeholder", "test test", "xxx"}
        for exercise in exercises:
            all_text = (
                exercise.prompt
                + " "
                + " ".join(
                    item.get("text", "")
                    for group in ("choices", "word_bank", "left_tiles", "right_tiles")
                    for item in exercise.content.get(group, [])
                )
            )
            haystack = all_text.lower()
            for marker in lorem_markers:
                assert marker not in haystack, f"found placeholder text {marker!r} in {exercise.id}"

            # multiple_choice, sentence_construction, and match_pairs
            # exercises present Amharic directly as answer/tile text --
            # verify real Ethiopic (Fidel) script there. `listening`
            # exercises intentionally present the *English* meaning as
            # choices (the Amharic is conveyed by the audio itself), so
            # they're exempted from this particular check and covered by
            # the placeholder-audio-URL test below instead.
            if exercise.type in ("multiple_choice", "sentence_construction", "match_pairs"):
                has_ethiopic = any("ሀ" <= ch <= "፿" for ch in all_text)
                assert has_ethiopic, f"exercise {exercise.id} has no Ethiopic-script text"

    async def test_listening_exercises_include_a_documented_placeholder_audio_url(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        stmt = select(ExerciseModel).where(ExerciseModel.type == "listening")
        listening_exercises = (await db_session.execute(stmt)).scalars().all()
        assert len(listening_exercises) >= 1

        for exercise in listening_exercises:
            audio_url = exercise.content["audio_url"]
            assert audio_url
            # Documented placeholder (no real Cloudflare R2 credentials in
            # this environment) -- but a genuinely resolvable one, not a
            # bare/empty string or a non-existent hostname: real devices
            # download and play this for offline caching
            # (010-offline-caching-and-sync-ui), so it has to actually work.
            assert audio_url.startswith("https://www.kozco.com/")


class TestMatchPairsSeedContent:
    """004-match-pairs-exercise-type (bolt 011): verifies the one seeded
    `match_pairs` exercise this intent's requirements.md commits to.
    """

    async def test_at_least_one_match_pairs_exercise_is_seeded(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        stmt = select(ExerciseModel).where(ExerciseModel.type == "match_pairs")
        match_pairs_exercises = (await db_session.execute(stmt)).scalars().all()
        assert len(match_pairs_exercises) >= 1

    async def test_seeded_match_pairs_content_is_well_formed(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        stmt = select(ExerciseModel).where(ExerciseModel.type == "match_pairs")
        exercise = (await db_session.execute(stmt)).scalars().first()
        assert exercise is not None

        left_ids = {tile["id"] for tile in exercise.content["left_tiles"]}
        right_ids = {tile["id"] for tile in exercise.content["right_tiles"]}
        assert len(left_ids) >= 2
        assert len(left_ids) == len(right_ids)

        correct_pairs = exercise.answer_key["correct_pairs"]
        assert len(correct_pairs) == len(left_ids)
        # Every pair references real tile ids from this exercise's own
        # content -- not a dangling/mismatched reference.
        for left_id, right_id in correct_pairs:
            assert left_id in left_ids
            assert right_id in right_ids
