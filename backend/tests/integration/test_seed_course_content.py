"""Tests for bolt `025-course-content-seed` (story 006): the three Afaan Oromo
/ Amharic starter courses are structurally sound, in the right script and
language for each direction, seed idempotently, and can be studied end to end
over HTTP.

Structural checks run against the seed data itself (fast, no DB); the
database-backed tests confirm what lands in the tables. Language correctness
(native-speaker review, NFR-3) cannot be tested here -- these guard shape,
links, script and uniqueness.
"""

from __future__ import annotations

import asyncio
import re
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
    VocabItemModel,
)
from app.infrastructure.db.seed_category_content import PLACEHOLDER_AUDIO_URL
from app.infrastructure.db.seed_course_content import (
    NEW_COURSE_CATEGORIES,
    NEW_COURSE_CURRICULUM,
    NEW_COURSE_VOCABULARY,
    NEW_COURSES,
)
from app.infrastructure.db.seed_lesson_content import (
    CATEGORIES,
    COURSES,
    CURRICULUM,
    VOCABULARY,
    _content_id,
    seed,
)
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

_FIDEL = re.compile(r"[ሀ-፿]")
_PAIRS = {  # course slug -> (learning, from)
    "course:en-om": ("om", "en"),
    "course:am-om": ("om", "am"),
    "course:om-am": ("am", "om"),
}


def _skills(course_slug: str) -> list[dict]:
    category_slugs = {c["slug"] for c in NEW_COURSE_CATEGORIES if c["course_slug"] == course_slug}
    return [s for s in NEW_COURSE_CURRICULUM if s["category_slug"] in category_slugs]


def _exercises(course_slug: str) -> list[dict]:
    return [e for s in _skills(course_slug) for lesson in s["lessons"] for e in lesson["exercises"]]


def _correct_text(exercise: dict) -> str:
    return next(
        c["text"]
        for c in exercise["content"]["choices"]
        if c["id"] == exercise["answer_key"]["correct_choice_id"]
    )


def _all_text(exercise: dict) -> str:
    groups = ("choices", "word_bank", "left_tiles", "right_tiles")
    tiles = " ".join(t["text"] for g in groups for t in exercise["content"].get(g, []))
    return f"{exercise['prompt']} {tiles}"


class TestCourseDefinitions:
    def test_the_three_requested_courses_exist_and_are_available(self) -> None:
        pairs = {c["slug"]: (c["learning_language"], c["from_language"]) for c in NEW_COURSES}

        assert pairs == _PAIRS
        assert all(c["status"] == "available" for c in NEW_COURSES)

    def test_course_pairs_and_order_do_not_clash_with_the_existing_course(self) -> None:
        all_pairs = [(c["learning_language"], c["from_language"]) for c in COURSES]
        orders = [c["order_index"] for c in COURSES]

        assert len(all_pairs) == len(set(all_pairs)) == 4
        assert len(orders) == len(set(orders))
        assert ("am", "en") in all_pairs  # English to Amharic still there

    def test_each_course_has_one_category_two_skills_and_two_lessons_each(self) -> None:
        for course_slug in _PAIRS:
            categories = [c for c in NEW_COURSE_CATEGORIES if c["course_slug"] == course_slug]
            assert [c["order_index"] for c in categories] == [1], course_slug
            skills = _skills(course_slug)
            assert [s["order_index"] for s in skills] == [1, 2], course_slug
            for skill in skills:
                assert [lesson["order_index"] for lesson in skill["lessons"]] == [1, 2]

    def test_every_lesson_has_at_least_four_exercises_and_the_three_core_types(self) -> None:
        for course_slug in _PAIRS:
            for skill in _skills(course_slug):
                for lesson in skill["lessons"]:
                    types = {e["type"] for e in lesson["exercises"]}
                    assert len(lesson["exercises"]) >= 4, (course_slug, lesson["title"])
                    assert types >= {"multiple_choice", "listening", "sentence_construction"}

    def test_every_course_has_a_match_pairs_exercise(self) -> None:
        for course_slug in _PAIRS:
            types = {e["type"] for e in _exercises(course_slug)}
            assert "match_pairs" in types, course_slug

    def test_exercise_order_within_each_lesson_is_consecutive_from_one(self) -> None:
        for course_slug in _PAIRS:
            for skill in _skills(course_slug):
                for lesson in skill["lessons"]:
                    orders = [e["order_index"] for e in lesson["exercises"]]
                    assert orders == list(range(1, len(orders) + 1)), lesson["title"]


class TestCourseContentIntegrity:
    def test_slugs_are_unique_across_the_whole_seed(self) -> None:
        slugs = [c["slug"] for c in COURSES] + [c["slug"] for c in CATEGORIES]
        slugs += [s["slug"] for s in CURRICULUM]
        slugs += [lesson["slug"] for s in CURRICULUM for lesson in s["lessons"]]
        slugs += [
            e["slug"] for s in CURRICULUM for lesson in s["lessons"] for e in lesson["exercises"]
        ]
        slugs += [v["slug"] for v in VOCABULARY]

        assert len(slugs) == len(set(slugs))

    def test_choice_based_exercises_have_four_choices_with_a_real_correct_id(self) -> None:
        for course_slug in _PAIRS:
            for e in _exercises(course_slug):
                if e["type"] not in ("multiple_choice", "listening"):
                    continue
                ids = [c["id"] for c in e["content"]["choices"]]
                assert len(ids) == len(set(ids)) == 4, e["slug"]
                assert e["answer_key"]["correct_choice_id"] in ids, e["slug"]
                texts = [c["text"] for c in e["content"]["choices"]]
                assert len(set(texts)) == 4, f"duplicate choice: {e['slug']}"

    def test_the_correct_choice_is_not_always_in_the_same_position(self) -> None:
        for course_slug in _PAIRS:
            positions = {
                e["answer_key"]["correct_choice_id"]
                for e in _exercises(course_slug)
                if e["type"] == "multiple_choice"
            }
            assert len(positions) > 1, course_slug

    def test_sentence_sequences_use_only_bank_tiles_and_the_bank_has_distractors(self) -> None:
        for course_slug in _PAIRS:
            for e in _exercises(course_slug):
                if e["type"] != "sentence_construction":
                    continue
                bank = [t["id"] for t in e["content"]["word_bank"]]
                sequence = e["answer_key"]["correct_sequence"]
                assert len(set(bank)) == len(bank), e["slug"]
                assert sequence and set(sequence) <= set(bank), e["slug"]
                assert len(bank) > len(sequence), f"no distractor tiles: {e['slug']}"
                assert bank[: len(sequence)] != sequence, f"bank already in order: {e['slug']}"

    def test_match_pairs_cover_each_tile_once_and_are_not_positional(self) -> None:
        for course_slug in _PAIRS:
            for e in _exercises(course_slug):
                if e["type"] != "match_pairs":
                    continue
                left = {t["id"] for t in e["content"]["left_tiles"]}
                right = {t["id"] for t in e["content"]["right_tiles"]}
                pairs = e["answer_key"]["correct_pairs"]
                assert {p[0] for p in pairs} == left, e["slug"]
                assert {p[1] for p in pairs} == right, e["slug"]
                assert len(pairs) == 4, e["slug"]
                assert any(p[0][1:] != p[1][1:] for p in pairs), e["slug"]

    def test_vocab_is_linked_only_from_multiple_choice_and_none_is_shared(self) -> None:
        for course_slug in _PAIRS:
            vocab_slugs = {
                v["slug"] for v in NEW_COURSE_VOCABULARY if v["course_slug"] == course_slug
            }
            linked = [e["vocab_slug"] for e in _exercises(course_slug) if e.get("vocab_slug")]
            assert set(linked) == vocab_slugs, course_slug
            assert len(linked) == len(set(linked)) == 8, course_slug
            for e in _exercises(course_slug):
                assert bool(e.get("vocab_slug")) == (e["type"] == "multiple_choice"), e["slug"]

    def test_listening_exercises_use_the_documented_placeholder_audio(self) -> None:
        for course_slug in _PAIRS:
            for e in _exercises(course_slug):
                if e["type"] == "listening":
                    assert e["content"]["audio_url"] == PLACEHOLDER_AUDIO_URL

    def test_no_placeholder_text_slipped_in(self) -> None:
        for course_slug in _PAIRS:
            for e in _exercises(course_slug):
                text = _all_text(e).lower()
                assert not any(m in text for m in ("lorem", "ipsum", "xxx", "todo")), e["slug"]


class TestScriptAndLanguagePerDirection:
    def test_english_to_afaan_oromo_is_latin_script_throughout(self) -> None:
        for e in _exercises("course:en-om"):
            assert not _FIDEL.search(_all_text(e)), e["slug"]
        assert all(
            not _FIDEL.search(v["word"] + v["translation"])
            for v in NEW_COURSE_VOCABULARY
            if v["course_slug"] == "course:en-om"
        )

    def test_amharic_to_afaan_oromo_asks_in_amharic_and_answers_in_afaan_oromo(self) -> None:
        for e in _exercises("course:am-om"):
            if e["type"] == "multiple_choice" and e["vocab_slug"].endswith(":1"):
                assert _FIDEL.search(e["prompt"]), e["slug"]
                assert not _FIDEL.search(_correct_text(e)), e["slug"]
            if e["type"] == "sentence_construction":
                assert _FIDEL.search(e["prompt"]), e["slug"]
                assert not any(_FIDEL.search(t["text"]) for t in e["content"]["word_bank"])
            if e["type"] == "match_pairs":
                assert all(not _FIDEL.search(t["text"]) for t in e["content"]["left_tiles"])
                assert all(_FIDEL.search(t["text"]) for t in e["content"]["right_tiles"])
        for v in (v for v in NEW_COURSE_VOCABULARY if v["course_slug"] == "course:am-om"):
            assert not _FIDEL.search(v["word"]) and _FIDEL.search(v["translation"]), v

    def test_afaan_oromo_to_amharic_asks_in_afaan_oromo_and_answers_in_amharic(self) -> None:
        for e in _exercises("course:om-am"):
            if e["type"] == "multiple_choice" and e["vocab_slug"].endswith(":1"):
                assert "Amaaraatiin" in e["prompt"], e["slug"]
                assert _FIDEL.search(_correct_text(e)), e["slug"]
            if e["type"] == "sentence_construction":
                assert e["prompt"].startswith("Hiiki:"), e["slug"]
                assert all(_FIDEL.search(t["text"]) for t in e["content"]["word_bank"])
            if e["type"] == "match_pairs":
                assert all(_FIDEL.search(t["text"]) for t in e["content"]["left_tiles"])
                assert all(not _FIDEL.search(t["text"]) for t in e["content"]["right_tiles"])
        for v in (v for v in NEW_COURSE_VOCABULARY if v["course_slug"] == "course:om-am"):
            assert _FIDEL.search(v["word"]) and not _FIDEL.search(v["translation"]), v

    def test_the_same_word_appears_in_every_direction(self) -> None:
        # Each course teaches the same lesson-1 first word: hello.
        prompts = {
            course: next(e["prompt"] for e in _exercises(course) if e["type"] == "multiple_choice")
            for course in _PAIRS
        }

        assert "'hello'" in prompts["course:en-om"]
        assert "ሰላም" in prompts["course:am-om"]
        assert "Akkam" in prompts["course:om-am"]


class TestSeedingTheCourses:
    async def test_the_four_courses_are_seeded_as_available_with_the_right_pairs(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        rows = (
            await db_session.execute(select(CourseModel).order_by(CourseModel.order_index))
        ).scalars()
        got = [(c.learning_language, c.from_language, c.status) for c in rows]

        assert got == [
            ("am", "en", "available"),
            ("om", "en", "available"),
            ("om", "am", "available"),
            ("am", "om", "available"),
        ]

    async def test_each_new_course_holds_its_own_content(self, db_session: AsyncSession) -> None:
        await seed(db_session)
        await db_session.commit()

        for slug in _PAIRS:
            course_id = _content_id(slug)
            counts = {}
            for name, stmt in {
                "categories": select(func.count())
                .select_from(CategoryModel)
                .where(CategoryModel.course_id == course_id),
                "skills": select(func.count())
                .select_from(SkillModel)
                .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
                .where(CategoryModel.course_id == course_id),
                "lessons": select(func.count())
                .select_from(LessonModel)
                .join(SkillModel, SkillModel.id == LessonModel.skill_id)
                .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
                .where(CategoryModel.course_id == course_id),
                "exercises": select(func.count())
                .select_from(ExerciseModel)
                .join(LessonModel, LessonModel.id == ExerciseModel.lesson_id)
                .join(SkillModel, SkillModel.id == LessonModel.skill_id)
                .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
                .where(CategoryModel.course_id == course_id),
                "vocab": select(func.count())
                .select_from(VocabItemModel)
                .where(VocabItemModel.course_id == course_id),
            }.items():
                counts[name] = (await db_session.execute(stmt)).scalar_one()
            assert counts == {
                "categories": 1,
                "skills": 2,
                "lessons": 4,
                "exercises": 18,
                "vocab": 8,
            }, slug

    async def test_the_english_to_amharic_course_is_unchanged(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        categories = (
            await db_session.execute(
                select(func.count())
                .select_from(CategoryModel)
                .where(CategoryModel.course_id == EN_AM_COURSE_ID)
            )
        ).scalar_one()
        vocab = (
            await db_session.execute(
                select(func.count())
                .select_from(VocabItemModel)
                .where(VocabItemModel.course_id == EN_AM_COURSE_ID)
            )
        ).scalar_one()
        assert (categories, vocab) == (5, 40)

    async def test_a_second_run_changes_no_row_counts(self, db_session: AsyncSession) -> None:
        await seed(db_session)
        await db_session.commit()
        await seed(db_session)
        await db_session.commit()

        for model, expected in (
            (CourseModel, 4),
            (CategoryModel, 8),
            (SkillModel, 16),
            (LessonModel, 32),
            (ExerciseModel, 143),
            (VocabItemModel, 64),
        ):
            got = (await db_session.execute(select(func.count()).select_from(model))).scalar_one()
            assert got == expected, model.__name__

    async def test_every_vocab_link_points_at_a_vocab_item_of_the_same_course(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        vocab_course = {
            v.id: v.course_id for v in (await db_session.execute(select(VocabItemModel))).scalars()
        }
        rows = (
            await db_session.execute(
                select(ExerciseModel.vocab_item_id, CategoryModel.course_id)
                .join(LessonModel, LessonModel.id == ExerciseModel.lesson_id)
                .join(SkillModel, SkillModel.id == LessonModel.skill_id)
                .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
                .where(ExerciseModel.vocab_item_id.is_not(None))
            )
        ).all()
        assert rows
        for vocab_item_id, course_id in rows:
            assert vocab_course[vocab_item_id] == course_id


@pytest.fixture
def seeded_real_content(db_path: Path) -> None:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())


_SIGNUPS = {
    "course:en-om": {"language": "om", "daily_goal_minutes": 10},
    "course:am-om": {"language": "om", "from_language": "am", "daily_goal_minutes": 10},
    "course:om-am": {"language": "am", "from_language": "om", "daily_goal_minutes": 10},
}


def _sign_up(make_client: Any, slug: str) -> tuple[Any, dict[str, str], dict[str, Any]]:
    client = make_client(FakeTokenVerifier(subject=f"user-{slug}"), FakeTokenVerifier())
    response = client.post(
        "/api/v1/auth/google", json={"id_token": "x", "pending_selection": _SIGNUPS[slug]}
    )
    assert response.status_code == 200, response.text
    data = response.json()
    return client, {"Authorization": f"Bearer {data['session_token']}"}, data["user"]


@pytest.mark.parametrize("slug", sorted(_PAIRS))
class TestStudyingEachNewCourseOverHttp:
    def test_signup_lands_on_the_course_and_shows_its_tree(
        self, make_client: Any, seeded_real_content: None, slug: str
    ) -> None:
        client, headers, user = _sign_up(make_client, slug)

        tree = client.get("/api/v1/skill-tree", headers=headers).json()

        assert user["active_course_id"] == _content_id(slug)
        assert tree["course"]["id"] == _content_id(slug)
        assert [c["title"] for c in tree["categories"]] == ["Foundations & Greetings"]
        assert [s["title"] for s in tree["skills"]] == ["Greetings & Basics", "Food & Drink"]
        assert [s["state"] for s in tree["skills"]] == ["active", "locked"]

    def test_the_first_lesson_can_be_completed_and_creates_that_courses_vocab_progress(
        self, make_client: Any, seeded_real_content: None, slug: str, db_path: Path
    ) -> None:
        client, headers, user = _sign_up(make_client, slug)
        tree = client.get("/api/v1/skill-tree", headers=headers).json()
        lesson_id = tree["skills"][0]["lesson_id"]
        lesson = client.get(f"/api/v1/lessons/{lesson_id}", headers=headers).json()
        assert len(lesson["exercises"]) == 4

        response = client.post(
            f"/api/v1/lessons/{lesson_id}/complete",
            headers=headers,
            json={
                "attempt_id": f"attempt-{slug}",
                "correct_count": 4,
                "total_count": 4,
                "time_spent_seconds": 20.0,
                "client_completed_at": datetime.now(UTC).isoformat(),
            },
        )

        assert response.status_code == 200, response.text
        assert response.json()["xp_earned"] > 0
        with sqlite3.connect(db_path) as conn:
            course_ids = conn.execute(
                "SELECT DISTINCT v.course_id FROM user_vocab_progress p "
                "JOIN vocab_items v ON v.id = p.vocab_item_id WHERE p.user_id = ?",
                (user["id"],),
            ).fetchall()
        assert course_ids == [(_content_id(slug),)]

    def test_finishing_the_first_skill_unlocks_the_second(
        self, make_client: Any, seeded_real_content: None, slug: str
    ) -> None:
        client, headers, _ = _sign_up(make_client, slug)
        tree = client.get("/api/v1/skill-tree", headers=headers).json()
        skill_id = tree["skills"][0]["id"]
        for n in (1, 2):
            tree = client.get("/api/v1/skill-tree", headers=headers).json()
            lesson_id = next(s["lesson_id"] for s in tree["skills"] if s["id"] == skill_id)
            lesson = client.get(f"/api/v1/lessons/{lesson_id}", headers=headers).json()
            total = len(lesson["exercises"])
            response = client.post(
                f"/api/v1/lessons/{lesson_id}/complete",
                headers=headers,
                json={
                    "attempt_id": f"attempt-{slug}-{n}",
                    "correct_count": total,
                    "total_count": total,
                    "time_spent_seconds": 20.0,
                    "client_completed_at": datetime.now(UTC).isoformat(),
                },
            )
            assert response.status_code == 200, response.text

        states = [
            s["state"] for s in client.get("/api/v1/skill-tree", headers=headers).json()["skills"]
        ]
        assert states == ["completed", "active"]
