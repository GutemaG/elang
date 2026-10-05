"""Integration tests: the Sounds tab's charts, over HTTP against a temp
SQLite database. Admins make, fill and turn on a chart
(`/api/v1/admin/sound-charts`); the app reads the ones that are on
(`/api/v1/sound-charts`), with ETags so an unchanged chart is never sent
twice.
"""

from __future__ import annotations

import re
import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.api import admin_routers, dependencies
from app.infrastructure.external.r2_storage import R2Storage
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin/sound-charts"
APP = "/api/v1/sound-charts"
CLIP = "https://pub-abc.r2.dev/am/sounds/0123456789ab.m4a"

STORAGE = R2Storage(
    account_id="acct123",
    bucket="ethio-lang",
    access_key_id="AKIDTEST",
    secret_access_key="r2-secret-never-shown",
    public_base_url="https://pub-abc.r2.dev",
)


@pytest.fixture
def client(
    make_client: ClientFactory, db_path: Path, monkeypatch: pytest.MonkeyPatch
) -> TestClient:
    with sqlite3.connect(db_path) as conn:
        conn.executemany(
            "INSERT INTO languages (code, name, native_name, created_at) "
            "VALUES (?, ?, ?, '2026-10-04')",
            [("am", "Amharic", "አማርኛ"), ("om", "Afaan Oromo", "Afaan Oromoo")],
        )
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    client.app.dependency_overrides[admin_routers.get_audio_storage] = lambda: STORAGE
    return client


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _create(client: TestClient, h: dict, language: str = "om", template: str = "qubee") -> Any:
    response = client.post(A, json={"language": language, "template": template}, headers=h)
    assert response.status_code == 201, response.text
    return response.json()


def _record_all(client: TestClient, h: dict, chart: dict) -> dict:
    """Gives every letter that needs one a recording."""
    updates = [
        {"id": x["id"], "audio_url": CLIP}
        for x in chart["letters"]
        if x["same_as_id"] is None and x["audio_url"] is None
    ]
    response = client.patch(
        f"{A}/{chart['language']}/letters", json={"letters": updates}, headers=h
    )
    assert response.status_code == 200, response.text
    return response.json()


def _turn_on(client: TestClient, h: dict, language: str) -> Any:
    return client.patch(f"{A}/{language}", json={"enabled": True}, headers=h)


class TestStartingAChart:
    def test_the_fidel_template_fills_every_letter_and_links_the_same_sounds(
        self, client: TestClient, h: dict
    ) -> None:
        chart = _create(client, h, "am", "fidel")

        assert chart["enabled"] is False
        assert chart["language_name"] == "Amharic"
        assert [g["key"] for g in chart["groups"]] == ["fidel", "labialised"]
        assert chart["counts"] == {
            "letters": 260,
            "ready": 0,
            "needs_review": 0,
            "draft": 260,
            "needs_recording": 225,
            "same_sound": 35,
        }
        assert chart["gaps"] == {"no_letters": False, "no_romanization": 0, "no_audio": 260}
        letters = chart["letters"]
        assert [x["glyph"] for x in letters[:3]] == ["ሀ", "ሁ", "ሂ"]
        by_id = {x["id"]: x for x in letters}
        hha = next(x for x in letters if x["glyph"] == "ሐ")
        assert by_id[hha["same_as_id"]]["glyph"] == "ሀ"

    def test_a_language_has_one_chart_and_must_exist(self, client: TestClient, h: dict) -> None:
        _create(client, h)

        again = client.post(A, json={"language": "om", "template": "empty"}, headers=h)
        assert again.status_code == 409
        assert again.json()["error_code"] == "content_exists"
        missing = client.post(A, json={"language": "ti", "template": "empty"}, headers=h)
        assert missing.status_code == 404
        unknown = client.post(A, json={"language": "am", "template": "runes"}, headers=h)
        assert unknown.status_code == 422

    def test_lists_every_chart_with_its_counts(self, client: TestClient, h: dict) -> None:
        _create(client, h, "om", "qubee")
        _create(client, h, "am", "empty")

        charts = client.get(A, headers=h).json()["charts"]
        assert [(c["language"], c["counts"]["letters"]) for c in charts] == [("am", 0), ("om", 37)]
        assert "letters" not in charts[0]

    def test_only_admins_may_use_it(self, make_client: ClientFactory, db_path: Path) -> None:
        learner = make_client(
            FakeTokenVerifier(subject="sub-l", email="l@example.com"), FakeTokenVerifier()
        )
        token = learner.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
        response = learner.get(A, headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 403


class TestLetters:
    def test_one_change_saves_every_field_and_raises_the_version(
        self, client: TestClient, h: dict
    ) -> None:
        chart = _create(client, h)
        dh = next(x for x in chart["letters"] if x["glyph"] == "Dh dh")

        response = client.patch(
            f"{A}/om/letters",
            json={
                "letters": [
                    {
                        "id": dh["id"],
                        "kind": None,
                        "audio_url": CLIP,
                        "hint": {"en": " A d with the tongue back ", "am": ""},
                        "example_word": "dhugaa",
                        "example_romanization": "dhugaa",
                        "example_meaning": {"en": "truth", "am": "እውነት"},
                        "example_audio_url": CLIP,
                        "status": "needs_review",
                        "recorded_by": "Chaltu",
                    }
                ]
            },
            headers=h,
        )

        assert response.status_code == 200, response.text
        body = response.json()
        saved = next(x for x in body["letters"] if x["id"] == dh["id"])
        assert saved["hint"] == {"en": "A d with the tongue back"}
        assert (dh["kind"], saved["kind"]) == ("consonant", None)
        assert saved["example_meaning"] == {"en": "truth", "am": "እውነት"}
        assert (saved["status"], saved["recorded_by"]) == ("needs_review", "Chaltu")
        assert body["version"] == chart["version"] + 1
        assert body["counts"]["needs_review"] == 1

    @pytest.mark.parametrize(
        ("change", "field"),
        [
            ({"audio_url": "http://insecure.example/a.mp3"}, "letters[1].audio_url"),
            ({"status": "done"}, "letters[1].status"),
            ({"kind": "semivowel"}, "letters[1].kind"),
            ({"glyph": ""}, "letters[1].glyph"),
            ({"romanization": "x" * 33}, "letters[1].romanization"),
            ({"hint": {"english": "x"}}, "letters[1].hint"),
            ({"position": 3}, "letters[1].position"),
        ],
    )
    def test_one_bad_change_saves_none_and_says_where(
        self, client: TestClient, h: dict, change: dict, field: str
    ) -> None:
        chart = _create(client, h)
        first, second = chart["letters"][:2]

        response = client.patch(
            f"{A}/om/letters",
            json={
                "letters": [{"id": first["id"], "audio_url": CLIP}, {"id": second["id"], **change}]
            },
            headers=h,
        )

        assert response.status_code == 422
        assert response.json()["details"]["field"] == field
        after = client.get(f"{A}/om", headers=h).json()
        assert after["letters"][0]["audio_url"] is None
        assert after["version"] == chart["version"]

    def test_same_as_points_one_step_at_a_letter_of_this_chart(
        self, client: TestClient, h: dict
    ) -> None:
        chart = _create(client, h, "am", "fidel")
        by_glyph = {x["glyph"]: x for x in chart["letters"]}

        def point(glyph: str, target: str | None) -> Any:
            return client.patch(
                f"{A}/am/letters",
                json={"letters": [{"id": by_glyph[glyph]["id"], "same_as_id": target}]},
                headers=h,
            )

        # ሀ is shared by ሐ and ኀ, so it keeps a sound of its own.
        assert point("ሀ", by_glyph["ለ"]["id"]).status_code == 422
        # ሐ already borrows ሀ's sound: nothing may borrow from it.
        assert point("ለ", by_glyph["ሐ"]["id"]).status_code == 422
        assert point("ለ", by_glyph["ለ"]["id"]).status_code == 422
        assert point("ለ", "no-such-letter").status_code == 422
        assert point("ሐ", None).status_code == 200

    def test_adds_and_deletes_letters(self, client: TestClient, h: dict) -> None:
        _create(client, h, "am", "empty")

        added = client.post(
            f"{A}/am/letters",
            json={"group": "letters", "glyph": "፩", "romanization": "and"},
            headers=h,
        )
        assert added.status_code == 201, added.text
        letter = added.json()
        assert (letter["position"], letter["status"]) == (0, "draft")
        assert (
            client.post(
                f"{A}/am/letters", json={"group": "numbers", "glyph": "፪"}, headers=h
            ).status_code
            == 422
        )

        assert client.delete(f"{A}/am/letters/{letter['id']}", headers=h).status_code == 204
        assert client.get(f"{A}/am", headers=h).json()["letters"] == []

    def test_a_letter_others_share_cannot_be_deleted(self, client: TestClient, h: dict) -> None:
        chart = _create(client, h, "am", "fidel")
        ha = chart["letters"][0]

        response = client.delete(f"{A}/am/letters/{ha['id']}", headers=h)
        assert response.status_code == 409
        assert response.json()["details"]["letters"] == 2

    def test_upload_links_are_for_this_charts_sounds(self, client: TestClient, h: dict) -> None:
        _create(client, h)

        response = client.post(
            f"{A}/om/audio/uploads", json={"content_type": "audio/mp4", "size": 9000}, headers=h
        )
        assert response.status_code == 201
        body = response.json()
        assert re.fullmatch(r"om/sounds/[0-9a-f]{12}\.m4a", body["key"])
        assert body["public_url"] == f"https://pub-abc.r2.dev/{body['key']}"
        assert "r2-secret-never-shown" not in response.text
        bad = client.post(
            f"{A}/om/audio/uploads", json={"content_type": "video/mp4", "size": 9}, headers=h
        )
        assert bad.status_code == 422


class TestTurningOn:
    def test_is_refused_until_every_sound_can_play(self, client: TestClient, h: dict) -> None:
        chart = _create(client, h, "am", "fidel")

        refused = _turn_on(client, h, "am")
        assert refused.status_code == 409
        assert refused.json()["error_code"] == "sound_chart_incomplete"
        assert refused.json()["details"]["no_audio"] == 260

        _record_all(client, h, chart)
        response = _turn_on(client, h, "am")
        assert response.status_code == 200, response.text
        assert response.json()["enabled"] is True

    def test_a_chart_that_is_on_cannot_lose_a_sound(self, client: TestClient, h: dict) -> None:
        chart = _record_all(client, h, _create(client, h))
        _turn_on(client, h, "om")
        first = chart["letters"][0]

        response = client.patch(
            f"{A}/om/letters", json={"letters": [{"id": first["id"], "audio_url": None}]}, headers=h
        )
        assert response.status_code == 409
        assert client.get(f"{A}/om", headers=h).json()["letters"][0]["audio_url"] == CLIP
        # Off first, then it may be deleted.
        assert client.delete(f"{A}/om", headers=h).status_code == 409
        client.patch(f"{A}/om", json={"enabled": False}, headers=h)
        assert client.delete(f"{A}/om", headers=h).status_code == 204
        assert client.get(f"{A}/om", headers=h).status_code == 404

    def test_renames_the_chart_and_its_groups(self, client: TestClient, h: dict) -> None:
        _create(client, h)

        response = client.patch(
            f"{A}/om",
            json={
                "title": {"en": "Qubee", "om": "Qubee Afaan Oromoo"},
                "group_names": {"pairs": {"en": "Pairs"}},
            },
            headers=h,
        )
        assert response.status_code == 200
        groups = {g["key"]: g for g in response.json()["groups"]}
        assert groups["pairs"]["names"] == {"en": "Pairs"}
        assert (
            client.patch(
                f"{A}/om", json={"group_names": {"nope": {"en": "x"}}}, headers=h
            ).status_code
            == 422
        )


class TestWhatTheAppReads:
    def test_shows_only_charts_that_are_on(self, client: TestClient, h: dict) -> None:
        chart = _record_all(client, h, _create(client, h, "am", "fidel"))
        _create(client, h, "om", "qubee")

        assert client.get(APP).json() == {"charts": []}
        assert client.get(f"{APP}/am").status_code == 404

        _turn_on(client, h, "am")
        index = client.get(APP)
        assert index.status_code == 200
        assert index.json()["charts"] == [
            {
                "language": "am",
                "title": {"en": "Fidel", "am": "ፊደል", "om": "Fidel"},
                "version": chart["version"] + 1,
                "letter_count": 260,
                "icon": "ሀ",
            }
        ]
        assert client.get(f"{APP}/om").status_code == 404

    def test_a_letter_that_sounds_the_same_plays_the_other_ones_recording(
        self, client: TestClient, h: dict
    ) -> None:
        chart = _create(client, h, "am", "fidel")
        updates = [
            {"id": x["id"], "audio_url": f"https://pub-abc.r2.dev/am/sounds/{i:012x}.m4a"}
            for i, x in enumerate(chart["letters"])
            if x["same_as_id"] is None
        ]
        client.patch(f"{A}/am/letters", json={"letters": updates}, headers=h)
        ha = chart["letters"][0]
        client.patch(
            f"{A}/am/letters",
            json={
                "letters": [
                    {
                        "id": ha["id"],
                        "recorded_by": "Selam",
                        "example_word": "ሀገር",
                        "example_romanization": "hager",
                        "example_meaning": {"en": "country"},
                    }
                ]
            },
            headers=h,
        )
        _turn_on(client, h, "am")

        body = client.get(f"{APP}/am").json()
        fidel, labialised = body["groups"]
        assert (fidel["columns"], fidel["column_labels"][0]) == (7, "e")
        assert len(fidel["letters"]) == 238 and len(labialised["letters"]) == 22
        letters = {x["glyph"]: x for x in fidel["letters"]}
        assert letters["ሐ"]["same_as"] == "ሀ"
        assert letters["ሐ"]["audio_url"] == letters["ሀ"]["audio_url"]
        assert letters["ሀ"]["example"] == {
            "word": "ሀገር",
            "romanization": "hager",
            "meaning": {"en": "country"},
            "audio_url": None,
        }
        assert letters["ሁ"]["example"] is None
        assert body["credits"] == ["Selam"]
        # Nothing only admins should see.
        assert "status" not in letters["ሀ"] and "recorded_by" not in letters["ሀ"]

    def test_qubee_is_a_to_z_with_its_vowels_marked(self, client: TestClient, h: dict) -> None:
        _record_all(client, h, _create(client, h, "om", "qubee"))
        _turn_on(client, h, "om")

        body = client.get(f"{APP}/om").json()
        assert [g["key"] for g in body["groups"]] == ["alphabet", "pairs", "long_vowels"]
        alphabet = body["groups"][0]["letters"]
        assert [(x["glyph"], x["kind"]) for x in alphabet[:3]] == [
            ("A a", "vowel"),
            ("B b", "consonant"),
            ("C c", "consonant"),
        ]
        assert body["groups"][0]["names"]["en"] == "A–Z"

    def test_can_be_cached_and_revalidated(self, client: TestClient, h: dict) -> None:
        chart = _record_all(client, h, _create(client, h))
        _turn_on(client, h, "om")

        first = client.get(f"{APP}/om")
        etag = first.headers["etag"]
        assert etag == f'"sounds-om-{chart["version"] + 1}"'
        assert "public" in first.headers["cache-control"]
        assert "max-age=" in first.headers["cache-control"]

        again = client.get(f"{APP}/om", headers={"If-None-Match": etag})
        assert again.status_code == 304
        assert again.content == b""
        assert again.headers["etag"] == etag
        # Also a weak or listed tag, as proxies send them.
        listed = client.get(f"{APP}/om", headers={"If-None-Match": f'"other", W/{etag}'})
        assert listed.status_code == 304

        index = client.get(APP)
        assert client.get(APP, headers={"If-None-Match": index.headers["etag"]}).status_code == 304

        # Any change is a new version, so the old tag no longer matches.
        client.patch(
            f"{A}/om/letters",
            json={"letters": [{"id": chart["letters"][0]["id"], "romanization": "aa"}]},
            headers=h,
        )
        changed = client.get(f"{APP}/om", headers={"If-None-Match": etag})
        assert changed.status_code == 200
        assert changed.headers["etag"] != etag
        assert client.get(APP, headers={"If-None-Match": index.headers["etag"]}).status_code == 200

    def test_needs_no_sign_in(self, client: TestClient) -> None:
        assert client.get(APP).status_code == 200


async def test_charts_keep_to_the_foreign_keys(db_path: Path) -> None:
    """Postgres checks each foreign key as a row goes in; SQLite does too
    once asked. So a template whose letters share sounds with later ones,
    and deleting a chart whose letters point at each other, both work."""
    from sqlalchemy import event, text
    from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

    from app.application import sound_use_cases as uc
    from app.application.admin_content_use_cases import AdminContext
    from app.infrastructure.db.sound_repository import SqlAlchemySoundRepository

    engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")

    @event.listens_for(engine.sync_engine, "connect")
    def _on(dbapi_connection: Any, _: Any) -> None:
        dbapi_connection.execute("PRAGMA foreign_keys=ON")

    ctx = AdminContext(email=ADMIN)
    async with AsyncSession(engine) as session:
        await session.execute(
            text(
                "INSERT INTO languages (code, name, native_name, created_at) "
                "VALUES ('am', 'Amharic', 'አማርኛ', '2026-10-04')"
            )
        )
        repo = SqlAlchemySoundRepository(session)
        view = await uc.create_chart(repo, ctx, language="am", template="fidel")
        assert view.counts.same_sound == 35
        await session.commit()

        await uc.delete_chart(repo, ctx, "am")
        await session.commit()
        assert (await session.execute(text("SELECT COUNT(*) FROM sound_letters"))).scalar() == 0
    await engine.dispose()
