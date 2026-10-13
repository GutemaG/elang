"""Integration tests: the Audio library API (intent 029, FR-2 to FR-5), over
HTTP. The store is an in-memory fake with R2's public address, put in
through the router's dependency hook, so nothing leaves the machine."""

from __future__ import annotations

import logging
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, insert

from app.config import Settings
from app.infrastructure.api import audio_library_routers, dependencies
from app.infrastructure.db.curriculum_models import CurriculumEntryModel, CurriculumRowModel
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    ExerciseModel,
    LanguageModel,
    LessonModel,
    SkillModel,
)
from app.infrastructure.db.sound_models import SoundChartModel, SoundLetterModel
from app.infrastructure.external.media_library import StoredFile
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.team import add_member

ClientFactory = Callable[[object, object], TestClient]
OWNER = "owner@example.com"
HELPER = "helper@example.com"
A = "/api/v1/admin/audio-files"
PUB = "https://pub-abc.r2.dev"
NOW = datetime(2026, 10, 13, 12, 0, tzinfo=UTC)
OLD = NOW - timedelta(days=3)

EXERCISE_KEY = "am/lesson-1/aaaaaaaaaaaa.m4a"
SHARED_KEY = "am/lesson-1/bbbbbbbbbbbb.m4a"
LETTER_KEY = "am/sounds/cccccccccccc.m4a"
UNUSED_OLD = "am/lesson-1/gen-am-meron-dddddddddddd.m4a"
UNUSED_NEW = "am/lesson-1/eeeeeeeeeeee.m4a"
MISSING_KEY = "am/lesson-1/ffffffffffff.m4a"
PICTURE = "am/lesson-1/999999999999.webp"


@dataclass
class FakeLibrary:
    files: dict[str, StoredFile] = field(default_factory=dict)
    name: str = "r2"
    public_prefix: str = f"{PUB}/"

    def put(self, key: str, uploaded_at: datetime = OLD, size: int = 1000) -> None:
        self.files[key] = StoredFile(key, size, uploaded_at)

    def public_url(self, key: str) -> str:
        return f"{PUB}/{key}"

    async def list_files(self, prefix: str = "") -> list[StoredFile]:
        return [f for k, f in self.files.items() if k.startswith(prefix)]

    def download_url(self, key: str) -> str:
        return f"https://signed.example/{key}?X-Amz-Signature=x"

    async def move(self, key: str, to_key: str) -> None:
        f = self.files.pop(key)
        self.files[to_key] = StoredFile(to_key, f.size, NOW)

    async def delete(self, key: str) -> None:
        self.files.pop(key, None)


def _seed(db_path: Path) -> None:
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as conn:
        conn.execute(insert(LanguageModel).values(code="am", name="Amharic", native_name="አማርኛ"))
        conn.execute(
            insert(CategoryModel).values(
                id="section-1",
                course_id=EN_AM_COURSE_ID,
                title="Greetings",
                subtitle="",
                order_index=1,
            )
        )
        conn.execute(
            insert(SkillModel).values(
                id="skill-1", category_id="section-1", title="Hello", order_index=1
            )
        )
        conn.execute(
            insert(LessonModel).values(
                id="lesson-1", skill_id="skill-1", title="Saying hi", order_index=2
            )
        )
        for i, (ex_type, content) in enumerate(
            [
                ("multiple_choice", {"choices": []}),
                ("listening", {"audio_url": f"{PUB}/{EXERCISE_KEY}", "choices": []}),
                (
                    "audio_image_choice",
                    {
                        "audio_url": f"{PUB}/{SHARED_KEY}?v=2",
                        "choices": [{"id": "a", "image_url": f"{PUB}/{PICTURE}"}],
                    },
                ),
                ("listening", {"audio_url": f"{PUB}/{MISSING_KEY}", "choices": []}),
                ("listening", {"audio_url": "https://elsewhere.example/a.mp3", "choices": []}),
            ],
            start=1,
        ):
            conn.execute(
                insert(ExerciseModel).values(
                    id=f"ex-{i}",
                    lesson_id="lesson-1",
                    order_index=i * 10,
                    type=ex_type,
                    prompt=f"Prompt {i}",
                    content=content,
                    answer_key={},
                )
            )
        conn.execute(
            insert(CurriculumEntryModel).values(
                course_id=EN_AM_COURSE_ID, ref="L1", kind="lesson", position=1, title="Hello lesson"
            )
        )
        conn.execute(
            insert(CurriculumRowModel).values(
                course_id=EN_AM_COURSE_ID,
                ref="W1",
                kind="word",
                lesson_ref="L1",
                position=1,
                english="hello",
                text="ሰላም",
                audio_url=f"{PUB}/{SHARED_KEY}",
            )
        )
        conn.execute(
            insert(SoundChartModel).values(language="am", title={"en": "Fidel"}, groups=[])
        )
        conn.execute(
            insert(SoundLetterModel).values(
                id="letter-1",
                language="am",
                group_key="h",
                position=1,
                glyph="ሀ",
                romanization="ha",
                audio_url=f"{PUB}/{LETTER_KEY}",
            )
        )
    engine.dispose()


@pytest.fixture
def library() -> FakeLibrary:
    lib = FakeLibrary()
    for key in (EXERCISE_KEY, SHARED_KEY, LETTER_KEY, UNUSED_OLD, PICTURE):
        lib.put(key)
    lib.put(UNUSED_NEW, NOW - timedelta(hours=2))
    return lib


@pytest.fixture
def client(
    make_client: ClientFactory,
    db_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    library: FakeLibrary,
) -> TestClient:
    _seed(db_path)
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=OWNER))
    google = FakeTokenVerifier()
    client = make_client(google, FakeTokenVerifier())
    client.app.dependency_overrides[audio_library_routers.get_media_library] = lambda: library
    client.app.dependency_overrides[audio_library_routers.get_now] = lambda: NOW
    client.google = google
    return client


def _sign_in(client: TestClient, email: str) -> dict[str, str]:
    google = client.google
    google.next_subject = f"sub-{email}"
    google.next_email = email
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    return _sign_in(client, OWNER)


def _files(client: TestClient, h: dict) -> dict[str, dict]:
    response = client.get(A, headers=h)
    assert response.status_code == 200, response.text
    return {f["key"]: f for f in response.json()["files"]}


class TestList:
    def test_lists_audio_only_with_status_source_and_totals(
        self, client: TestClient, h: dict
    ) -> None:
        body = client.get(A, headers=h).json()

        files = {f["key"]: f for f in body["files"]}
        assert set(files) == {EXERCISE_KEY, SHARED_KEY, LETTER_KEY, UNUSED_OLD, UNUSED_NEW}
        assert files[EXERCISE_KEY]["status"] == "in_use"
        assert files[UNUSED_OLD]["status"] == "unused"
        assert files[UNUSED_OLD]["source"] == "generated"
        assert files[EXERCISE_KEY]["source"] == "recorded"
        assert files[EXERCISE_KEY]["url"] == f"{PUB}/{EXERCISE_KEY}"
        assert files[EXERCISE_KEY]["language"] == "am"
        assert body["storage"] == "r2"
        assert body["totals"] == {
            "files": 5,
            "bytes": 5000,
            "in_use": 3,
            "unused": 2,
            "missing": 1,
            "trash": 0,
            "trash_bytes": 0,
        }
        assert body["external_links"] == 1
        assert body["courses"][0]["id"] == EN_AM_COURSE_ID

    def test_newest_first(self, client: TestClient, h: dict) -> None:
        keys = [f["key"] for f in client.get(A, headers=h).json()["files"]]
        assert keys[0] == UNUSED_NEW

    def test_uses_say_where_each_file_is_used_and_how_to_open_it(
        self, client: TestClient, h: dict
    ) -> None:
        files = _files(client, h)

        (use,) = files[EXERCISE_KEY]["uses"]
        assert use["place"] == "exercise"
        assert use["exercise_number"] == 2
        assert use["exercise_type"] == "listening"
        assert (use["course_title"], use["section"], use["skill"], use["lesson"]) == (
            "English to Amharic",
            "Greetings",
            "Hello",
            "Saying hi",
        )
        assert use["admin_path"] == f"/courses/{EN_AM_COURSE_ID}/lessons/lesson-1/exercises/ex-2"

        shared = files[SHARED_KEY]["uses"]
        assert [u["place"] for u in shared] == ["exercise", "workbook"]
        assert shared[1]["admin_path"] == f"/courses/{EN_AM_COURSE_ID}/workbook/lessons/L1"
        assert (shared[1]["lesson"], shared[1]["english"], shared[1]["text"]) == (
            "Hello lesson",
            "hello",
            "ሰላም",
        )

        (letter,) = files[LETTER_KEY]["uses"]
        assert (letter["place"], letter["letter"]) == ("sound", "ሀ")
        assert letter["admin_path"] == "/sounds/am/letters/letter-1"

    def test_a_link_to_a_file_that_is_not_stored_is_missing(
        self, client: TestClient, h: dict
    ) -> None:
        (missing,) = client.get(A, headers=h).json()["missing"]

        assert missing["key"] == MISSING_KEY
        assert missing["uses"][0]["admin_path"].endswith("/exercises/ex-4")

    def test_only_old_unused_files_can_be_trashed(self, client: TestClient, h: dict) -> None:
        files = _files(client, h)

        assert files[UNUSED_OLD]["can_trash"] is True
        assert files[UNUSED_NEW]["can_trash"] is False
        assert files[EXERCISE_KEY]["can_trash"] is False

    def test_no_store_is_503(self, client: TestClient, h: dict) -> None:
        client.app.dependency_overrides[audio_library_routers.get_media_library] = lambda: None

        response = client.get(A, headers=h)

        assert response.status_code == 503
        assert response.json()["error_code"] == "audio_storage_not_configured"

    def test_a_course_admin_may_not_see_it(self, client: TestClient, db_path: Path) -> None:
        add_member(db_path, HELPER, "course_admin", [EN_AM_COURSE_ID])

        response = client.get(A, headers=_sign_in(client, HELPER))

        assert response.status_code == 403
        assert response.json()["error_code"] == "super_admin_only"


class TestTrash:
    def test_moves_restores_and_deletes(
        self,
        client: TestClient,
        h: dict,
        library: FakeLibrary,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        caplog.set_level(logging.INFO)

        moved = client.post(f"{A}/trash", json={"keys": [UNUSED_OLD]}, headers=h)
        assert moved.json() == {"count": 1}
        assert f"trash/{UNUSED_OLD}" in library.files and UNUSED_OLD not in library.files
        (trashed,) = client.get(A, headers=h).json()["trash"]
        assert trashed["original_key"] == UNUSED_OLD
        assert f"action=trash entity=audio_file id={UNUSED_OLD} admin={OWNER}" in caplog.text

        restored = client.post(
            f"{A}/trash/restore", json={"keys": [f"trash/{UNUSED_OLD}"]}, headers=h
        )
        assert restored.json() == {"count": 1}
        assert UNUSED_OLD in library.files

        # A restored file counts as new again, so this one is put back as trashed.
        library.files.pop(UNUSED_OLD)
        library.put(f"trash/{UNUSED_OLD}")
        deleted = client.post(
            f"{A}/trash/delete", json={"keys": [f"trash/{UNUSED_OLD}"]}, headers=h
        )
        assert deleted.json() == {"count": 1}
        assert not any(k.endswith(UNUSED_OLD) for k in library.files)

    @pytest.mark.parametrize("key", [EXERCISE_KEY, UNUSED_NEW])
    def test_refuses_a_file_in_use_or_too_new_and_moves_nothing(
        self, client: TestClient, h: dict, library: FakeLibrary, key: str
    ) -> None:
        response = client.post(f"{A}/trash", json={"keys": [UNUSED_OLD, key]}, headers=h)

        assert response.status_code == 409
        assert response.json()["error_code"] == "audio_file_in_use"
        assert response.json()["details"]["keys"] == [key]
        assert UNUSED_OLD in library.files

    def test_unknown_keys_are_404(self, client: TestClient, h: dict) -> None:
        response = client.post(f"{A}/trash", json={"keys": ["am/x/000000000000.m4a"]}, headers=h)
        assert response.status_code == 404
        assert response.json()["error_code"] == "audio_file_not_found"

    def test_deletes_only_inside_the_trash(
        self, client: TestClient, h: dict, library: FakeLibrary
    ) -> None:
        response = client.post(f"{A}/trash/delete", json={"keys": [UNUSED_OLD]}, headers=h)

        assert response.status_code == 404
        assert UNUSED_OLD in library.files

    def test_restore_will_not_replace_a_file(
        self, client: TestClient, h: dict, library: FakeLibrary
    ) -> None:
        library.put(f"trash/{EXERCISE_KEY}")

        response = client.post(
            f"{A}/trash/restore", json={"keys": [f"trash/{EXERCISE_KEY}"]}, headers=h
        )

        assert response.status_code == 409
        assert response.json()["error_code"] == "audio_file_exists"

    @pytest.mark.parametrize("keys", [[], [f"am/x/{i:012d}.m4a" for i in range(501)]])
    def test_between_1_and_500_keys(self, client: TestClient, h: dict, keys: list[str]) -> None:
        response = client.post(f"{A}/trash", json={"keys": keys}, headers=h)
        assert response.status_code == 422
        assert response.json()["details"]["field"] == "keys"


class TestExport:
    def test_everything_laid_out_by_course_with_one_row_per_use(
        self, client: TestClient, h: dict
    ) -> None:
        body = client.get(f"{A}/export", headers=h).json()

        assert body["name"] == "buna-audio-all-2026-10-13"
        paths = {f["key"]: f["zip_path"] for f in body["files"]}
        lesson = "english-to-amharic/01-greetings/01-hello/02-saying-hi"
        assert paths == {
            EXERCISE_KEY: f"{lesson}/ex02-listening-aaaaaa.m4a",
            SHARED_KEY: f"{lesson}/ex03-audio-image-choice-bbbbbb.m4a",
            LETTER_KEY: "sounds/am/h-01-ha-sound-cccccc.m4a",
        }
        assert body["files"][0]["download_url"].startswith("https://signed.example/")
        shared_rows = [r for r in body["rows"] if r["key"] == SHARED_KEY]
        assert [r["use"]["place"] for r in shared_rows] == ["exercise", "workbook"]
        assert {r["zip_path"] for r in shared_rows} == {paths[SHARED_KEY]}
        (missing,) = [r for r in body["rows"] if r["status"] == "missing"]
        assert (missing["key"], missing["zip_path"]) == (MISSING_KEY, "")

    def test_unused_files_on_request(self, client: TestClient, h: dict) -> None:
        body = client.get(f"{A}/export", params={"include_unused": "true"}, headers=h).json()

        paths = {f["key"]: f["zip_path"] for f in body["files"]}
        assert paths[UNUSED_OLD] == f"unused/am/{UNUSED_OLD.rsplit('/', 1)[-1]}"
        assert UNUSED_NEW in paths
        unused_row = next(r for r in body["rows"] if r["key"] == UNUSED_OLD)
        assert (unused_row["status"], unused_row["use"]) == ("unused", None)

    def test_one_course_keeps_its_language_sounds(self, client: TestClient, h: dict) -> None:
        body = client.get(f"{A}/export", params={"course_id": EN_AM_COURSE_ID}, headers=h).json()

        assert body["name"] == "buna-audio-english-to-amharic-2026-10-13"
        assert {f["key"] for f in body["files"]} == {EXERCISE_KEY, SHARED_KEY, LETTER_KEY}

    def test_an_unknown_course_is_404(self, client: TestClient, h: dict) -> None:
        response = client.get(f"{A}/export", params={"course_id": "nope"}, headers=h)
        assert response.status_code == 404
        assert response.json()["details"] == {"entity": "course", "id": "nope"}
