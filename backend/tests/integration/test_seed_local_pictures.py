"""The local-only Picture Lab section and its committed sample pictures
(bolt `051-image-choice-samples`): the files, their credits, and the seed."""

from __future__ import annotations

import asyncio
import json
import shutil
import struct
import subprocess
from collections import Counter
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import Session as SyncSession

from app.config import Settings
from app.domain.lesson.exercise_parts import validate_exercise
from app.infrastructure.db import seed_lesson_content, seed_local_pictures
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    ExerciseModel,
    UserVocabProgressModel,
    VocabItemModel,
)
from app.infrastructure.db.seed_lesson_content import _content_id
from tests.fakes import FakeTokenVerifier

PICTURES_DIR = seed_local_pictures.SAMPLE_PICTURES_DIR
CREDITS = PICTURES_DIR / "credits.json"
ALLOWED_LICENCES = {"CC0 1.0", "CC BY 4.0", "CC BY-SA 4.0"}
CREDIT_FIELDS = {
    "file",
    "subject",
    "author",
    "source",
    "source_url",
    "licence",
    "licence_url",
    "changes",
}


def webp_size(data: bytes) -> tuple[int, int]:
    """Width and height from a WebP file's header, without an image library.
    Raises AssertionError for anything that is not WebP."""
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP", "not a WebP file"
    chunk = data[12:16]
    if chunk == b"VP8X":
        width = int.from_bytes(data[24:27], "little") + 1
        height = int.from_bytes(data[27:30], "little") + 1
        return width, height
    if chunk == b"VP8L":
        assert data[20] == 0x2F, "bad lossless signature"
        bits = int.from_bytes(data[21:25], "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if chunk == b"VP8 ":
        assert data[23:26] == b"\x9d\x01\x2a", "bad lossy signature"
        width, height = struct.unpack("<HH", data[26:30])
        return width & 0x3FFF, height & 0x3FFF
    raise AssertionError(f"unknown WebP chunk {chunk!r}")


def _credits() -> list[dict[str, str]]:
    pictures: list[dict[str, str]] = json.loads(CREDITS.read_text(encoding="utf-8"))["pictures"]
    return pictures


def _exercises() -> list[dict[str, Any]]:
    exercises: list[dict[str, Any]] = seed_local_pictures.CURRICULUM[0]["lessons"][0]["exercises"]
    return exercises


def _file_of(url: str) -> str:
    return url.rsplit("/", 1)[-1]


# --- the committed files ------------------------------------------------------


class TestThePictures:
    def test_the_webp_reader_reads_each_kind_of_header(self) -> None:
        # A lossy, a lossless and an extended header, 300×200 each.
        lossy = b"RIFF\0\0\0\0WEBPVP8 \0\0\0\0\0\0\0\x9d\x01\x2a" + struct.pack("<HH", 300, 200)
        lossless_bits = (300 - 1) | ((200 - 1) << 14)
        lossless = b"RIFF\0\0\0\0WEBPVP8L\0\0\0\0\x2f" + lossless_bits.to_bytes(4, "little")
        extended = (
            b"RIFF\0\0\0\0WEBPVP8X\0\0\0\0\0\0\0\0"
            + (300 - 1).to_bytes(3, "little")
            + (200 - 1).to_bytes(3, "little")
        )
        for data in (lossy, lossless, extended):
            assert webp_size(data) == (300, 200)
        with pytest.raises(AssertionError):
            webp_size(b"\x89PNG\r\n\x1a\n" + b"\0" * 30)

    @pytest.mark.parametrize("file", sorted(seed_local_pictures.ALT_TEXT))
    def test_each_picture_is_a_small_webp(self, file: str) -> None:
        data = (PICTURES_DIR / file).read_bytes()

        width, height = webp_size(data)

        assert max(width, height) <= 512
        assert min(width, height) > 0
        assert len(data) <= 300 * 1024

    def test_the_folder_holds_only_the_pictures_and_their_credits(self) -> None:
        on_disk = {p.name for p in PICTURES_DIR.iterdir()}
        assert on_disk == {*seed_local_pictures.ALT_TEXT, "credits.json"}

    def test_git_tracks_the_folder(self) -> None:
        # `backend/media` is ignored; the committed pictures must not be.
        if shutil.which("git") is None:
            pytest.skip("git is not installed")
        for path in (CREDITS, *(PICTURES_DIR / f for f in seed_local_pictures.ALT_TEXT)):
            result = subprocess.run(  # noqa: S603 -- fixed arguments
                ["git", "check-ignore", "-q", str(path)],  # noqa: S607
                cwd=PICTURES_DIR,
                check=False,
            )
            assert result.returncode == 1, f"{path.name} is git-ignored"


class TestTheCredits:
    def test_every_entry_has_every_field(self) -> None:
        for entry in _credits():
            assert set(entry) == CREDIT_FIELDS, entry["file"]
            for field in CREDIT_FIELDS:
                assert isinstance(entry[field], str) and entry[field].strip(), (entry, field)

    def test_every_licence_is_a_free_one_with_its_link(self) -> None:
        for entry in _credits():
            assert entry["licence"] in ALLOWED_LICENCES, entry
            assert entry["licence_url"].startswith("https://creativecommons.org/"), entry
            assert entry["source_url"].startswith("https://"), entry

    def test_each_picture_is_credited_exactly_once(self) -> None:
        files = Counter(entry["file"] for entry in _credits())
        assert all(n == 1 for n in files.values()), files
        assert set(files) == set(seed_local_pictures.ALT_TEXT)

    def test_every_picture_a_question_shows_is_credited_and_every_credit_is_used(self) -> None:
        # Distractors too.
        shown = {
            _file_of(choice["image_url"])
            for exercise in _exercises()
            for choice in exercise["content"]["choices"]
        }
        assert shown == {entry["file"] for entry in _credits()}


# --- the seed ------------------------------------------------------------------


class TestTheQuestions:
    def test_three_image_choice_and_two_audio_image_choice(self) -> None:
        types = Counter(exercise["type"] for exercise in _exercises())
        assert types == {"image_choice": 3, "audio_image_choice": 2}

    @pytest.mark.parametrize("exercise", _exercises(), ids=lambda e: e["slug"])
    def test_each_passes_validation_where_local_media_is_allowed(
        self, exercise: dict[str, Any]
    ) -> None:
        validate_exercise(
            exercise["type"],
            exercise["prompt"],
            exercise["content"],
            exercise["answer_key"],
            allow_local_media=True,
        )

    def test_each_answer_is_the_picture_of_its_word(self) -> None:
        expected = [answer for _, _, answer in seed_local_pictures.IMAGE_WORDS] + [
            answer for _, _, answer, _ in seed_local_pictures.AUDIO_WORDS
        ]
        for exercise, answer in zip(_exercises(), expected, strict=True):
            correct = exercise["answer_key"]["correct_choice_id"]
            chosen = next(c for c in exercise["content"]["choices"] if c["id"] == correct)
            assert _file_of(chosen["image_url"]) == answer

    def test_each_word_is_answered_by_the_picture_that_means_it(self) -> None:
        # Written out here, not read from the seed, so a wrong pairing there
        # cannot pass by agreeing with itself.
        meanings = {
            "ውሃ": "water.webp",
            "ውሻ": "dog.webp",
            "ቤት": "house.webp",
            "አንድ": "number-1.webp",
            "አስር": "number-10.webp",
        }
        word_of = {v["slug"]: v["word"] for v in seed_local_pictures.VOCABULARY}
        for exercise in _exercises():
            correct = exercise["answer_key"]["correct_choice_id"]
            chosen = next(c for c in exercise["content"]["choices"] if c["id"] == correct)
            assert _file_of(chosen["image_url"]) == meanings[word_of[exercise["vocab_slug"]]]

    def test_the_prompts_name_the_word_or_ask_for_what_is_heard(self) -> None:
        for exercise, (word, _, _) in zip(
            _exercises(), seed_local_pictures.IMAGE_WORDS, strict=False
        ):
            assert exercise["prompt"] == f"Choose the picture: '{word}'"
        for exercise in _exercises()[3:]:
            assert exercise["prompt"] == "Tap the picture you hear"

    def test_the_audio_questions_play_the_audio_labs_recordings(self) -> None:
        clips = [
            e["content"]["audio_url"] for e in _exercises() if e["type"] == "audio_image_choice"
        ]
        assert clips == ["/media/audio/am/one.m4a", "/media/audio/am/ten.m4a"]

    def test_the_right_answer_moves_from_question_to_question(self) -> None:
        answers = [e["answer_key"]["correct_choice_id"] for e in _exercises()]
        assert len(set(answers)) == 4

    def test_every_question_has_its_own_new_word(self) -> None:
        slugs = [e["vocab_slug"] for e in _exercises()]
        assert len(set(slugs)) == len(slugs) == 5
        assert set(slugs) == {v["slug"] for v in seed_local_pictures.VOCABULARY}
        main_seed_slugs = {v["slug"] for v in seed_lesson_content.VOCABULARY}
        assert not set(slugs) & main_seed_slugs


def test_copying_puts_every_picture_where_its_address_points(tmp_path: Path) -> None:
    target = seed_local_pictures.copy_pictures(tmp_path / "images" / "samples")

    for exercise in _exercises():
        for choice in exercise["content"]["choices"]:
            url = choice["image_url"]
            assert url.startswith("/media/images/samples/"), url
            copied = target / _file_of(url)
            assert copied.read_bytes() == (PICTURES_DIR / _file_of(url)).read_bytes()


def test_copying_again_overwrites_a_stale_picture(tmp_path: Path) -> None:
    target = tmp_path / "samples"
    target.mkdir()
    (target / "dog.webp").write_bytes(b"old")

    seed_local_pictures.copy_pictures(target)

    assert (target / "dog.webp").read_bytes() == (PICTURES_DIR / "dog.webp").read_bytes()


async def _seed_both(session: AsyncSession) -> None:
    await seed_lesson_content.seed(session)
    await seed_local_pictures.seed(session)
    await session.commit()


class TestSeeding:
    async def test_it_adds_the_questions_to_english_to_amharic(
        self, db_session: AsyncSession
    ) -> None:
        await _seed_both(db_session)

        lesson_id = _content_id(seed_local_pictures.LESSON_SLUG)
        stmt = (
            select(ExerciseModel)
            .where(ExerciseModel.lesson_id == lesson_id)
            .order_by(ExerciseModel.order_index)
        )
        stored = (await db_session.execute(stmt)).scalars().all()

        assert [e.type for e in stored] == [e["type"] for e in _exercises()]
        for row, source in zip(stored, _exercises(), strict=True):
            assert row.content == source["content"]
            assert row.answer_key == source["answer_key"]
            assert row.vocab_item_id == _content_id(source["vocab_slug"])

    async def test_each_word_belongs_to_the_course_and_has_no_other_question(
        self, db_session: AsyncSession
    ) -> None:
        await _seed_both(db_session)

        for vocab in seed_local_pictures.VOCABULARY:
            item = await db_session.get(VocabItemModel, _content_id(vocab["slug"]))
            assert item is not None
            assert item.course_id == _content_id(seed_lesson_content.DEFAULT_COURSE_SLUG)
            assert item.word == vocab["word"]
            stmt = select(ExerciseModel).where(ExerciseModel.vocab_item_id == item.id)
            assert len((await db_session.execute(stmt)).scalars().all()) == 1

    async def test_the_section_sits_first_in_english_to_amharic(
        self, db_session: AsyncSession
    ) -> None:
        await _seed_both(db_session)

        course_id = _content_id(seed_lesson_content.DEFAULT_COURSE_SLUG)
        stmt = (
            select(CategoryModel)
            .where(CategoryModel.course_id == course_id)
            .order_by(CategoryModel.order_index)
        )
        first = (await db_session.execute(stmt)).scalars().first()
        assert first is not None
        assert first.title == "Picture Lab"

    async def test_seeding_twice_changes_nothing(self, db_session: AsyncSession) -> None:
        await _seed_both(db_session)
        await seed_local_pictures.seed(db_session)
        await db_session.commit()

        lesson_id = _content_id(seed_local_pictures.LESSON_SLUG)
        exercises = select(ExerciseModel).where(ExerciseModel.lesson_id == lesson_id)
        assert len((await db_session.execute(exercises)).scalars().all()) == 5
        words = select(VocabItemModel).where(
            VocabItemModel.id.in_([_content_id(v["slug"]) for v in seed_local_pictures.VOCABULARY])
        )
        assert len((await db_session.execute(words)).scalars().all()) == 5


def test_only_a_sqlite_database_is_seeded(monkeypatch: pytest.MonkeyPatch) -> None:
    neon = Settings(_env_file=None, database_url="postgresql+asyncpg://u:p@ep-x.neon.tech/neondb")
    monkeypatch.setattr(seed_local_pictures, "get_settings", lambda: neon)
    copied: list[Path] = []
    monkeypatch.setattr(seed_local_pictures, "copy_pictures", lambda: copied.append(Path()))

    with pytest.raises(SystemExit, match="only runs against the local SQLite database"):
        asyncio.run(seed_local_pictures.main())
    assert copied == []


# --- practice ------------------------------------------------------------------


@pytest.fixture
def seeded(db_path: Path) -> Path:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await _seed_both(session)
        await engine.dispose()

    asyncio.run(_seed())
    return db_path


def test_practice_offers_each_sample_word_with_its_picture_question(
    make_client: Any, seeded: Path
) -> None:
    client: TestClient = make_client(FakeTokenVerifier(subject="sub-learner"), FakeTokenVerifier())
    signed_in = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()
    h = {"Authorization": f"Bearer {signed_in['session_token']}"}
    engine = create_engine(f"sqlite:///{seeded}")
    with SyncSession(engine) as session:
        for vocab in seed_local_pictures.VOCABULARY:
            session.add(
                UserVocabProgressModel(
                    user_id=signed_in["user"]["id"],
                    vocab_item_id=_content_id(vocab["slug"]),
                    box_level=1,
                    next_review_at=datetime.now(UTC) - timedelta(hours=1),
                    last_seen_at=datetime.now(UTC) - timedelta(days=1),
                )
            )
        session.commit()
    engine.dispose()

    response = client.get("/api/v1/practice/due-items", headers=h)

    assert response.status_code == 200, response.json()
    by_word = {item["vocab_item_id"]: item for item in response.json()["items"]}
    for exercise in _exercises():
        item = by_word[_content_id(exercise["vocab_slug"])]
        assert item["exercise"]["id"] == _content_id(exercise["slug"])
        assert item["exercise"]["type"] == exercise["type"]
        assert item["exercise"]["choices"] == exercise["content"]["choices"]
