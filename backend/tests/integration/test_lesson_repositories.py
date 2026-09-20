"""Integration tests for the lesson-content SQLAlchemy repositories, against
a real (temp-file) SQLite database -- exercises the actual `content`/
`answer_key` JSON round trip (ADR-3) and the SQLite timezone-round-trip
normalization (same concern as `001-auth-service`'s equivalent test).
"""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.domain.lesson.value_objects import (
    ChoiceAnswerKey,
    ExerciseType,
    GapFillContent,
    ListeningContent,
    MatchPairsContent,
    MultipleChoiceContent,
    PairAnswerKey,
    SentenceConstructionContent,
    SequenceAnswerKey,
)
from app.infrastructure.db.lesson_models import (
    ExerciseModel,
    LessonModel,
    SkillModel,
    UserSkillProgressModel,
)
from app.infrastructure.db.lesson_repositories import (
    SqlAlchemyLessonRepository,
    SqlAlchemySkillRepository,
    SqlAlchemyUserSkillProgressRepository,
)
from app.infrastructure.db.models import UserModel
from tests.fakes import EN_AM_COURSE_ID


class TestSqlAlchemySkillRepository:
    async def test_list_all_orders_by_order_index_regardless_of_insert_order(
        self, db_session: AsyncSession
    ) -> None:
        db_session.add_all(
            [
                SkillModel(category_id="cat-1", id="s2", title="Food & Drink", order_index=2),
                SkillModel(category_id="cat-1", id="s1", title="Greetings & Basics", order_index=1),
            ]
        )
        await db_session.commit()

        repo = SqlAlchemySkillRepository(db_session)
        skills = await repo.list_all()

        assert [s.id for s in skills] == ["s1", "s2"]

    async def test_list_all_returns_empty_list_when_no_skills_exist(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemySkillRepository(db_session)
        assert await repo.list_all() == []

    async def test_id_defaults_to_a_generated_uuid_when_not_provided(
        self, db_session: AsyncSession
    ) -> None:
        # Exercises SkillModel's `default=_uuid_str` column factory --
        # every other test explicitly sets `id` (deterministic seed content
        # or a fixed test id), so this covers the fallback path directly.
        db_session.add(SkillModel(category_id="cat-1", title="Auto-ID Skill", order_index=99))
        await db_session.commit()

        repo = SqlAlchemySkillRepository(db_session)
        skills = await repo.list_all()

        assert len(skills) == 1
        assert len(skills[0].id) == 36  # UUID string form


class TestSqlAlchemyLessonRepository:
    async def test_get_by_id_returns_none_for_unknown_lesson(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyLessonRepository(db_session)
        assert await repo.get_by_id("does-not-exist") is None

    async def test_get_by_id_loads_lesson_with_all_3_exercise_types_ordered(
        self, db_session: AsyncSession
    ) -> None:
        db_session.add(
            SkillModel(category_id="cat-1", id="s1", title="Greetings & Basics", order_index=1)
        )
        db_session.add(LessonModel(id="l1", skill_id="s1", title="Hello & Goodbye", order_index=1))
        db_session.add_all(
            [
                ExerciseModel(
                    id="e3",
                    lesson_id="l1",
                    order_index=3,
                    type="sentence_construction",
                    prompt="Translate: 'I am fine'",
                    content={
                        "word_bank": [
                            {"id": "w1", "text": "ደህና"},
                            {"id": "w2", "text": "ነኝ"},
                        ]
                    },
                    answer_key={"correct_sequence": ["w1", "w2"]},
                ),
                ExerciseModel(
                    id="e1",
                    lesson_id="l1",
                    order_index=1,
                    type="multiple_choice",
                    prompt="How do you say 'Hello'?",
                    content={
                        "choices": [
                            {"id": "a", "text": "ሰላም"},
                            {"id": "b", "text": "ደህና ሁን"},
                        ]
                    },
                    answer_key={"correct_choice_id": "a"},
                ),
                ExerciseModel(
                    id="e2",
                    lesson_id="l1",
                    order_index=2,
                    type="listening",
                    prompt="What does this word mean?",
                    content={
                        "audio_url": "https://r2-placeholder.buna.dev/audio/hello.mp3",
                        "choices": [
                            {"id": "a", "text": "Hello"},
                            {"id": "b", "text": "Goodbye"},
                        ],
                    },
                    answer_key={"correct_choice_id": "a"},
                ),
            ]
        )
        await db_session.commit()

        repo = SqlAlchemyLessonRepository(db_session)
        lesson = await repo.get_by_id("l1")

        assert lesson is not None
        assert lesson.skill_id == "s1"
        # Ordered by order_index regardless of insertion order.
        assert [e.id for e in lesson.exercises] == ["e1", "e2", "e3"]

        mc = lesson.exercises[0]
        assert mc.type is ExerciseType.MULTIPLE_CHOICE
        assert isinstance(mc.content, MultipleChoiceContent)
        assert mc.content.choices[0].text == "ሰላም"
        assert isinstance(mc.answer_key, ChoiceAnswerKey)
        assert mc.answer_key.correct_choice_id == "a"

        listening = lesson.exercises[1]
        assert listening.type is ExerciseType.LISTENING
        assert isinstance(listening.content, ListeningContent)
        assert listening.content.audio_url == "https://r2-placeholder.buna.dev/audio/hello.mp3"

        sentence = lesson.exercises[2]
        assert sentence.type is ExerciseType.SENTENCE_CONSTRUCTION
        assert isinstance(sentence.content, SentenceConstructionContent)
        assert isinstance(sentence.answer_key, SequenceAnswerKey)
        assert sentence.answer_key.correct_sequence == ("w1", "w2")

    async def test_get_by_id_round_trips_a_match_pairs_exercise(
        self, db_session: AsyncSession
    ) -> None:
        # 004-match-pairs-exercise-type (bolt 011): content/answer_key stay
        # separate, mirroring multiple_choice -- not one self-revealing blob.
        db_session.add(
            SkillModel(category_id="cat-1", id="s1", title="Food & Drink", order_index=1)
        )
        db_session.add(LessonModel(id="l1", skill_id="s1", title="Coffee & Tea", order_index=1))
        db_session.add(
            ExerciseModel(
                id="e1",
                lesson_id="l1",
                order_index=1,
                type="match_pairs",
                prompt="Match each word to its meaning",
                content={
                    "left_tiles": [
                        {"id": "l1", "text": "ቡና"},
                        {"id": "l2", "text": "ሻይ"},
                    ],
                    "right_tiles": [
                        {"id": "r1", "text": "Coffee"},
                        {"id": "r2", "text": "Tea"},
                    ],
                },
                answer_key={"correct_pairs": [["l1", "r1"], ["l2", "r2"]]},
            )
        )
        await db_session.commit()

        repo = SqlAlchemyLessonRepository(db_session)
        lesson = await repo.get_by_id("l1")

        assert lesson is not None
        match_pairs = lesson.exercises[0]
        assert match_pairs.type is ExerciseType.MATCH_PAIRS
        assert isinstance(match_pairs.content, MatchPairsContent)
        assert [t.text for t in match_pairs.content.left_tiles] == ["ቡና", "ሻይ"]
        assert [t.text for t in match_pairs.content.right_tiles] == ["Coffee", "Tea"]
        assert isinstance(match_pairs.answer_key, PairAnswerKey)
        assert match_pairs.answer_key.correct_pairs == (("l1", "r1"), ("l2", "r2"))

    async def test_get_by_id_round_trips_a_gap_fill_exercise(
        self, db_session: AsyncSession
    ) -> None:
        # 015-gap-fill-exercise-type (bolt 030). Before this bolt, anything
        # that was not one of the first three types fell through to
        # match-pairs, so this row would have died on a missing
        # `left_tiles` key rather than loading.
        db_session.add(
            SkillModel(category_id="cat-1", id="s-gf", title="Food & Drink", order_index=1)
        )
        db_session.add(LessonModel(id="l-gf", skill_id="s-gf", title="I'm Hungry", order_index=1))
        db_session.add(
            ExerciseModel(
                id="e-gf",
                lesson_id="l-gf",
                order_index=1,
                type="gap_fill",
                prompt="Complete the sentence: 'I want bread'",
                content={
                    "sentence_before": "",
                    "sentence_after": "እፈልጋለሁ",
                    "choices": [
                        {"id": "a", "text": "ዳቦ"},
                        {"id": "b", "text": "ምግብ"},
                        {"id": "c", "text": "ውሃ"},
                    ],
                },
                answer_key={"correct_choice_id": "a"},
            )
        )
        await db_session.commit()

        repo = SqlAlchemyLessonRepository(db_session)
        lesson = await repo.get_by_id("l-gf")

        assert lesson is not None
        gap_fill = lesson.exercises[0]
        assert gap_fill.type is ExerciseType.GAP_FILL
        assert isinstance(gap_fill.content, GapFillContent)
        assert gap_fill.content.sentence_before == ""
        assert gap_fill.content.sentence_after == "እፈልጋለሁ"
        assert [c.text for c in gap_fill.content.choices] == ["ዳቦ", "ምግብ", "ውሃ"]
        # Shares `multiple_choice`'s answer key rather than adding one.
        assert isinstance(gap_fill.answer_key, ChoiceAnswerKey)
        assert gap_fill.answer_key.correct_choice_id == "a"
        # Not vocab-linked: a vocab item maps to exactly one exercise, and
        # the multiple-choice exercise that teaches ዳቦ already owns it.
        assert gap_fill.vocab_item_id is None


class TestSqlAlchemyUserSkillProgressRepository:
    async def test_list_by_user_round_trips_completed_at_as_timezone_aware(
        self, db_session: AsyncSession
    ) -> None:
        db_session.add(
            UserModel(
                id="u1",
                auth_provider="google",
                provider_user_id="google-sub-1",
                selected_language="am",
                daily_xp_target=40,
                active_course_id=EN_AM_COURSE_ID,
            )
        )
        db_session.add(
            SkillModel(category_id="cat-1", id="s1", title="Greetings & Basics", order_index=1)
        )
        db_session.add(
            UserSkillProgressModel(
                id="p1",
                user_id="u1",
                skill_id="s1",
                unlocked=True,
                crown_level=2,
                completed_at=datetime(2026, 1, 1, tzinfo=UTC),
            )
        )
        await db_session.commit()

        # Force a real round trip through a brand-new session/connection,
        # not an in-memory identity-map hit (same discipline as
        # `001-auth-service`'s equivalent regression test).
        factory = async_sessionmaker(bind=db_session.bind, expire_on_commit=False, autoflush=False)
        async with factory() as fresh_session:
            repo = SqlAlchemyUserSkillProgressRepository(fresh_session)
            rows = await repo.list_by_user("u1")

        assert len(rows) == 1
        assert rows[0].crown_level == 2
        assert rows[0].completed_at is not None
        assert rows[0].completed_at.tzinfo is not None
        # Comparable against a timezone-aware "now" without raising.
        assert rows[0].completed_at < datetime.now(UTC)

    async def test_list_by_user_returns_empty_list_for_user_with_no_rows(
        self, db_session: AsyncSession
    ) -> None:
        repo = SqlAlchemyUserSkillProgressRepository(db_session)
        assert await repo.list_by_user("no-such-user") == []
