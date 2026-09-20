"""Tests for bolt `022-category-content-seed`: the four new categories'
content is structurally sound and seeds idempotently (story 004).

Structural checks run against the seed data itself (fast, no DB); the
database-backed tests confirm what actually lands in the tables. Content
correctness in the Amharic sense (native-speaker review, NFR-3) cannot be
tested here -- these guard shape, links and uniqueness.
"""

from __future__ import annotations

import re

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
    VocabItemModel,
)
from app.infrastructure.db.seed_category_content import (
    NEW_CATEGORIES,
    NEW_CURRICULUM,
    NEW_VOCABULARY,
    PLACEHOLDER_AUDIO_URL,
)
from app.infrastructure.db.seed_lesson_content import seed

_FIDEL = re.compile(r"[ሀ-፿]")
_NEW_CATEGORY_TITLES = {
    "Family & People",
    "Numbers & Time",
    "Travel & Places",
    "Colors, Body & Health",
}


def _exercises(skill: dict) -> list[dict]:
    return [e for lesson in skill["lessons"] for e in lesson["exercises"]]


class TestNewCategoryStructure:
    def test_the_four_requested_categories_are_present_in_order(self) -> None:
        assert {c["title"] for c in NEW_CATEGORIES} == _NEW_CATEGORY_TITLES
        assert [c["order_index"] for c in NEW_CATEGORIES] == [2, 3, 4, 5]

    def test_every_new_category_has_two_skills_of_two_lessons(self) -> None:
        for category in NEW_CATEGORIES:
            skills = [s for s in NEW_CURRICULUM if s["category_slug"] == category["slug"]]
            assert [s["order_index"] for s in skills] == [1, 2], category["title"]
            for skill in skills:
                assert [lesson["order_index"] for lesson in skill["lessons"]] == [1, 2]

    def test_every_lesson_has_at_least_four_exercises_and_the_three_core_types(self) -> None:
        for skill in NEW_CURRICULUM:
            for lesson in skill["lessons"]:
                types = {e["type"] for e in lesson["exercises"]}
                assert len(lesson["exercises"]) >= 4, lesson["title"]
                assert types >= {"multiple_choice", "listening", "sentence_construction"}, lesson[
                    "title"
                ]

    def test_every_new_category_has_at_least_one_match_pairs_exercise(self) -> None:
        for category in NEW_CATEGORIES:
            types = {
                e["type"]
                for s in NEW_CURRICULUM
                if s["category_slug"] == category["slug"]
                for e in _exercises(s)
            }
            assert "match_pairs" in types, category["title"]

    def test_exercise_order_within_each_lesson_is_consecutive_from_one(self) -> None:
        for skill in NEW_CURRICULUM:
            for lesson in skill["lessons"]:
                orders = [e["order_index"] for e in lesson["exercises"]]
                assert orders == list(range(1, len(orders) + 1)), lesson["title"]


class TestNewContentIntegrity:
    def test_slugs_are_unique_across_everything_new(self) -> None:
        slugs = [c["slug"] for c in NEW_CATEGORIES]
        slugs += [s["slug"] for s in NEW_CURRICULUM]
        slugs += [lesson["slug"] for s in NEW_CURRICULUM for lesson in s["lessons"]]
        slugs += [e["slug"] for s in NEW_CURRICULUM for e in _exercises(s)]
        slugs += [v["slug"] for v in NEW_VOCABULARY]
        assert len(slugs) == len(set(slugs))

    def test_choice_based_exercises_have_four_choices_with_a_real_correct_id(self) -> None:
        for skill in NEW_CURRICULUM:
            for e in _exercises(skill):
                if e["type"] not in ("multiple_choice", "listening"):
                    continue
                choices = e["content"]["choices"]
                ids = [c["id"] for c in choices]
                assert len(choices) == 4, e["slug"]
                assert len(set(ids)) == 4, e["slug"]
                assert e["answer_key"]["correct_choice_id"] in ids, e["slug"]
                assert len({c["text"] for c in choices}) == 4, f"duplicate choice: {e['slug']}"

    def test_the_correct_choice_is_not_always_in_the_same_position(self) -> None:
        positions = {
            e["answer_key"]["correct_choice_id"]
            for s in NEW_CURRICULUM
            for e in _exercises(s)
            if e["type"] == "multiple_choice"
        }
        assert len(positions) > 1

    def test_sentence_sequences_use_only_word_bank_tiles(self) -> None:
        for skill in NEW_CURRICULUM:
            for e in _exercises(skill):
                if e["type"] != "sentence_construction":
                    continue
                bank_ids = [t["id"] for t in e["content"]["word_bank"]]
                sequence = e["answer_key"]["correct_sequence"]
                assert len(set(bank_ids)) == len(bank_ids), e["slug"]
                assert sequence
                assert set(sequence) <= set(bank_ids), e["slug"]
                assert len(bank_ids) > len(sequence), f"no distractor tiles: {e['slug']}"

    def test_match_pairs_cover_each_tile_exactly_once(self) -> None:
        for skill in NEW_CURRICULUM:
            for e in _exercises(skill):
                if e["type"] != "match_pairs":
                    continue
                left = {t["id"] for t in e["content"]["left_tiles"]}
                right = {t["id"] for t in e["content"]["right_tiles"]}
                pairs = e["answer_key"]["correct_pairs"]
                assert {p[0] for p in pairs} == left, e["slug"]
                assert {p[1] for p in pairs} == right, e["slug"]
                assert len(pairs) == len(left) == len(right) == 4, e["slug"]

    def test_match_pairs_are_real_pairings_not_positional(self) -> None:
        # The right column is rotated, so a positional (l1-r1, ...) answer
        # key would be wrong: at least one pair must not line up by index.
        for skill in NEW_CURRICULUM:
            for e in _exercises(skill):
                if e["type"] != "match_pairs":
                    continue
                pairs = e["answer_key"]["correct_pairs"]
                assert any(p[0][1:] != p[1][1:] for p in pairs), e["slug"]

    def test_vocab_links_reference_existing_vocab_and_none_are_shared(self) -> None:
        vocab_slugs = {v["slug"] for v in NEW_VOCABULARY}
        linked = [
            e["vocab_slug"] for s in NEW_CURRICULUM for e in _exercises(s) if e.get("vocab_slug")
        ]
        assert set(linked) == vocab_slugs
        assert len(linked) == len(set(linked))
        assert len(linked) == 32

    def test_only_multiple_choice_exercises_are_vocab_linked(self) -> None:
        for skill in NEW_CURRICULUM:
            for e in _exercises(skill):
                assert bool(e.get("vocab_slug")) == (e["type"] == "multiple_choice"), e["slug"]

    def test_vocab_words_are_amharic_and_translations_are_not(self) -> None:
        for v in NEW_VOCABULARY:
            assert _FIDEL.search(v["word"]), v
            assert not _FIDEL.search(v["translation"]), v

    def test_english_to_amharic_questions_have_an_amharic_correct_answer(self) -> None:
        for skill in NEW_CURRICULUM:
            for e in _exercises(skill):
                if e["type"] == "multiple_choice" and e["prompt"].startswith("How do you say"):
                    correct = next(
                        c["text"]
                        for c in e["content"]["choices"]
                        if c["id"] == e["answer_key"]["correct_choice_id"]
                    )
                    assert _FIDEL.search(correct), e["slug"]

    def test_listening_exercises_use_the_documented_placeholder_audio(self) -> None:
        for skill in NEW_CURRICULUM:
            for e in _exercises(skill):
                if e["type"] == "listening":
                    assert e["content"]["audio_url"] == PLACEHOLDER_AUDIO_URL


class TestSeedingTheNewContent:
    async def test_seeding_creates_the_expected_row_counts(self, db_session: AsyncSession) -> None:
        await seed(db_session)
        await db_session.commit()

        for model, expected in (
            (CategoryModel, 8),
            (SkillModel, 16),
            (LessonModel, 32),
            (ExerciseModel, 159),
            (VocabItemModel, 64),
        ):
            got = (await db_session.execute(select(func.count()).select_from(model))).scalar_one()
            assert got == expected, model.__name__

    async def test_every_seeded_exercise_vocab_link_resolves_to_a_vocab_row(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        vocab_ids = {v.id for v in (await db_session.execute(select(VocabItemModel))).scalars()}
        linked = [
            e.vocab_item_id
            for e in (await db_session.execute(select(ExerciseModel))).scalars()
            if e.vocab_item_id
        ]
        assert linked
        assert set(linked) <= vocab_ids

    async def test_a_second_run_changes_no_row_counts(self, db_session: AsyncSession) -> None:
        await seed(db_session)
        await db_session.commit()
        await seed(db_session)
        await db_session.commit()

        for model, expected in (
            (CategoryModel, 8),
            (SkillModel, 16),
            (LessonModel, 32),
            (ExerciseModel, 159),
            (VocabItemModel, 64),
        ):
            got = (await db_session.execute(select(func.count()).select_from(model))).scalar_one()
            assert got == expected, model.__name__

    @pytest.mark.parametrize("title", sorted(_NEW_CATEGORY_TITLES))
    async def test_each_new_category_is_seeded_with_an_amharic_subtitle(
        self, db_session: AsyncSession, title: str
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        category = (
            await db_session.execute(select(CategoryModel).where(CategoryModel.title == title))
        ).scalar_one()
        assert _FIDEL.search(category.subtitle)
