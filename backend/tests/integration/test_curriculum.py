"""Integration tests: a course's draft curriculum over HTTP, against a temp
SQLite database (`/api/v1/admin/courses/{id}/curriculum`). The admin site
imports the workbook, reads it with its progress, and corrects, reviews and
records each row.
"""

from __future__ import annotations

import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.api import admin_routers, dependencies
from app.infrastructure.external.r2_storage import R2Storage
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
C = f"/api/v1/admin/courses/{EN_AM_COURSE_ID}/curriculum"
CLIP = "https://pub-abc.r2.dev/am/curriculum/W001/0123456789ab.m4a"

STORAGE = R2Storage(
    account_id="acct123",
    bucket="ethio-lang",
    access_key_id="AKIDTEST",
    secret_access_key="r2-secret-never-shown",
    public_base_url="https://pub-abc.r2.dev",
)


@pytest.fixture
def client(make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    client.app.dependency_overrides[admin_routers.get_audio_storage] = lambda: STORAGE
    return client


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _entries() -> list[dict[str, Any]]:
    return [
        {"ref": "S1", "kind": "section", "position": 1, "title": "First conversations"},
        {"ref": "S1-U01", "kind": "skill", "parent_ref": "S1", "position": 1, "title": "Greetings"},
        {
            "ref": "S1-U01-L1",
            "kind": "lesson",
            "parent_ref": "S1-U01",
            "position": 1,
            "title": "Hello & goodbye",
            "goal": "Can greet someone and say goodbye.",
            "grammar": "ሰላም is used at any time of day.",
        },
        {
            "ref": "S1-U01-L2",
            "kind": "lesson",
            "parent_ref": "S1-U01",
            "position": 2,
            "title": "How are you?",
        },
    ]


def _rows() -> list[dict[str, Any]]:
    return [
        {
            "ref": "W001",
            "kind": "word",
            "lesson_ref": "S1-U01-L1",
            "position": 1,
            "english": "hello",
            "text": "ሰላም",
            "romanization": "selam",
            "confidence": "high",
            "status": "draft",
        },
        {
            "ref": "W002",
            "kind": "word",
            "lesson_ref": "S1-U01-L1",
            "position": 2,
            "english": "goodbye",
            "text": "ደህና ይሁኑ",
            "romanization": "dehna yihunu",
            "notes": "Polite form.",
            "confidence": "medium",
            "status": "draft",
        },
        {
            "ref": "S001",
            "kind": "sentence",
            "lesson_ref": "S1-U01-L1",
            "position": 3,
            "english": "Goodbye, good night",
            "text": "ደህና ይሁኑ፣ ደህና ይደሩ",
            "romanization": "dehna yihunu, dehna yideru",
            "blank": "ይደሩ",
            "accepted": ["ደህና ሁን፣ ደህና እደር"],
            "confidence": "high",
            "status": "draft",
        },
        {
            "ref": "W003",
            "kind": "word",
            "lesson_ref": "S1-U01-L2",
            "position": 1,
            "english": "fine",
        },
    ]


def _import(client: TestClient, h: dict, *, dry_run: bool = False, **body: Any) -> Any:
    payload = {"entries": _entries(), "rows": _rows(), **body}
    url = f"{C}?dry_run=true" if dry_run else C
    return client.put(url, json=payload, headers=h)


def _row(client: TestClient, h: dict, ref: str) -> dict[str, Any]:
    rows = client.get(C, headers=h).json()["rows"]
    return next(r for r in rows if r["ref"] == ref)


def _patch(client: TestClient, h: dict, ref: str, **changes: Any) -> Any:
    version = changes.pop("version", None) or _row(client, h, ref)["version"]
    return client.patch(f"{C}/rows/{ref}", json={"version": version, **changes}, headers=h)


class TestImport:
    def test_an_empty_course_has_an_empty_curriculum(self, client: TestClient, h: dict) -> None:
        response = client.get(C, headers=h)

        assert response.status_code == 200
        body = response.json()
        assert body["language"] == "am"
        assert body["course_title"] == "English to Amharic"
        assert body["entries"] == [] and body["rows"] == []
        assert body["counts"]["rows"] == 0

    def test_imports_the_plan_and_rows(self, client: TestClient, h: dict) -> None:
        response = _import(client, h)

        assert response.status_code == 200, response.text
        result = response.json()
        assert result["dry_run"] is False
        assert result["entries"] == {"added": 4, "changed": 0, "kept": 0, "unchanged": 0}
        assert result["rows"] == {"added": 4, "changed": 0, "kept": 0, "unchanged": 0}

        body = client.get(C, headers=h).json()
        assert [e["ref"] for e in body["entries"]] == ["S1", "S1-U01", "S1-U01-L1", "S1-U01-L2"]
        lesson = next(e for e in body["entries"] if e["ref"] == "S1-U01-L1")
        assert lesson["goal"] == "Can greet someone and say goodbye."
        assert lesson["counts"] == {
            "rows": 3,
            "filled": 3,
            "reviewed": 0,
            "recorded": 0,
            "needs_change": 0,
        }
        assert next(e for e in body["entries"] if e["ref"] == "S1")["counts"] is None
        assert [r["ref"] for r in body["rows"]] == ["W001", "W002", "S001", "W003"]
        sentence = next(r for r in body["rows"] if r["ref"] == "S001")
        assert sentence["blank"] == "ይደሩ"
        assert sentence["accepted"] == ["ደህና ሁን፣ ደህና እደር"]
        assert sentence["version"] == 1 and sentence["updated_by"] == ADMIN
        unfilled = next(r for r in body["rows"] if r["ref"] == "W003")
        assert unfilled["text"] is None and unfilled["status"] == "to_do"
        assert body["counts"]["rows"] == 4 and body["counts"]["filled"] == 3

    def test_a_dry_run_says_what_would_change_and_saves_nothing(
        self, client: TestClient, h: dict
    ) -> None:
        response = _import(client, h, dry_run=True)

        assert response.status_code == 200
        assert response.json()["dry_run"] is True
        assert response.json()["rows"]["added"] == 4
        assert client.get(C, headers=h).json()["rows"] == []

    def test_lists_every_problem_and_saves_nothing(self, client: TestClient, h: dict) -> None:
        rows = _rows()
        rows[0]["status"] = "Reviewed"  # a label, not a key
        rows[2]["blank"] = "ሌሊት"  # not in the sentence
        rows[3]["lesson_ref"] = "S9-U01-L1"  # no such lesson
        rows.append({**rows[1]})  # W002 twice
        entries = _entries()
        entries[2]["parent_ref"] = "S1"  # a lesson in a section
        del entries[0]["title"]

        response = client.put(C, json={"entries": entries, "rows": rows}, headers=h)

        assert response.status_code == 422
        body = response.json()
        assert body["error_code"] == "invalid_import"
        problems = {(p["ref"], p["field"]) for p in body["details"]["rows"]}
        assert problems == {
            ("W001", "status"),
            ("S001", "blank"),
            ("W003", "lesson_ref"),
            ("W002", "ref"),
            ("S1-U01-L1", "parent_ref"),
            ("S1", "title"),
        }
        assert client.get(C, headers=h).json()["entries"] == []

    def test_a_word_has_no_blank(self, client: TestClient, h: dict) -> None:
        rows = _rows()
        rows[0]["blank"] = "ሰላም"

        response = client.put(C, json={"entries": _entries(), "rows": rows}, headers=h)

        assert response.status_code == 422
        assert response.json()["details"]["rows"][0]["field"] == "blank"

    def test_rows_may_join_lessons_already_saved(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        extra = {
            "ref": "W004",
            "kind": "word",
            "lesson_ref": "S1-U01-L2",
            "position": 2,
            "english": "and you?",
        }

        response = client.put(C, json={"rows": [extra]}, headers=h)

        assert response.status_code == 200, response.text
        result = response.json()
        assert result["rows"]["added"] == 1
        # Nothing saved is dropped for being missing from the file.
        assert result["missing_rows"] == ["S001", "W001", "W002", "W003"]
        assert result["missing_entries"] == ["S1", "S1-U01", "S1-U01-L1", "S1-U01-L2"]
        assert len(client.get(C, headers=h).json()["rows"]) == 5

    def test_the_same_file_twice_changes_nothing(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        before = client.get(C, headers=h).json()

        again = _import(client, h).json()

        assert again["entries"] == {"added": 0, "changed": 0, "kept": 0, "unchanged": 4}
        assert again["rows"] == {"added": 0, "changed": 0, "kept": 0, "unchanged": 4}
        assert client.get(C, headers=h).json() == before

    def test_a_changed_file_updates_drafts_but_keeps_reviewed_and_recorded_rows(
        self, client: TestClient, h: dict
    ) -> None:
        _import(client, h)
        assert _patch(client, h, "W001", status="reviewed").status_code == 200
        assert _patch(client, h, "W002", audio_url=CLIP).status_code == 200
        rows = _rows()
        for row in rows:
            row["notes"] = "Checked again."
        entries = _entries()
        entries[1]["title"] = "Saying hello"

        result = client.put(C, json={"entries": entries, "rows": rows}, headers=h).json()

        assert result["entries"]["changed"] == 1
        assert result["rows"] == {"added": 0, "changed": 2, "kept": 2, "unchanged": 0}
        assert result["kept"] == ["W001", "W002"]
        assert _row(client, h, "W001")["notes"] is None
        assert _row(client, h, "W001")["status"] == "reviewed"
        assert _row(client, h, "S001")["notes"] == "Checked again."
        assert _row(client, h, "S001")["version"] == 2

    def test_overwrite_changes_reviewed_rows_and_never_their_audio(
        self, client: TestClient, h: dict
    ) -> None:
        _import(client, h)
        _patch(client, h, "W001", status="reviewed")
        _patch(client, h, "W001", audio_url=CLIP)
        rows = _rows()
        rows[0]["text"] = "ሰላም ነው"
        rows[0]["status"] = "reviewed"

        result = client.put(
            C, json={"entries": _entries(), "rows": rows, "overwrite_reviewed": True}, headers=h
        ).json()

        assert result["rows"]["changed"] == 1 and result["kept"] == []
        row = _row(client, h, "W001")
        assert row["text"] == "ሰላም ነው"
        assert row["audio_url"] == CLIP
        # The recording may not match the new text any more.
        assert row["status"] == "draft"


class TestEditingARow:
    def test_changes_the_fields_sent(self, client: TestClient, h: dict) -> None:
        _import(client, h)

        response = _patch(
            client, h, "W002", text="ደህና ሁን", status="needs_change", comment="Use the polite form?"
        )

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["reset_to_draft"] is False
        row = body["row"]
        assert row["text"] == "ደህና ሁን"
        assert row["status"] == "needs_change"
        assert row["comment"] == "Use the polite form?"
        assert row["romanization"] == "dehna yihunu"
        assert row["version"] == 2
        counts = next(
            e for e in client.get(C, headers=h).json()["entries"] if e["ref"] == "S1-U01-L1"
        )["counts"]
        assert counts["needs_change"] == 1

    def test_an_edit_from_an_old_copy_is_refused(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        assert _patch(client, h, "W001", status="reviewed", version=1).status_code == 200

        stale = _patch(client, h, "W001", comment="Looks fine", version=1)

        assert stale.status_code == 409
        assert stale.json()["error_code"] == "content_changed"
        assert stale.json()["details"] == {"current_version": 2}
        assert _row(client, h, "W001")["comment"] is None

    def test_the_word_to_blank_stays_in_the_sentence(self, client: TestClient, h: dict) -> None:
        _import(client, h)

        moved = _patch(client, h, "S001", text="ደህና ይሁኑ")
        assert moved.status_code == 422
        assert moved.json()["details"]["field"] == "blank"
        both = _patch(client, h, "S001", text="ደህና ይሁኑ", blank="ይሁኑ")
        assert both.status_code == 200
        on_a_word = _patch(client, h, "W001", blank="ሰላም")
        assert on_a_word.status_code == 422

    def test_new_text_sends_a_recorded_row_back_to_draft(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        _patch(client, h, "W001", audio_url=CLIP)
        _patch(client, h, "W001", status="reviewed")

        response = _patch(client, h, "W001", romanization="salam")

        assert response.json()["reset_to_draft"] is True
        assert response.json()["row"]["status"] == "draft"
        assert response.json()["row"]["audio_url"] == CLIP
        # Not when the same edit says what the status is.
        again = _patch(client, h, "W001", text="ሰላም!", status="reviewed").json()
        assert again["reset_to_draft"] is False and again["row"]["status"] == "reviewed"
        # Nor for a row with no recording.
        plain = _patch(client, h, "W002", text="ደህና ሁኑ").json()
        assert plain["reset_to_draft"] is False and plain["row"]["status"] == "draft"

    def test_an_edit_that_changes_nothing_keeps_the_version(
        self, client: TestClient, h: dict
    ) -> None:
        _import(client, h)

        body = _patch(client, h, "W001", text="ሰላም").json()

        assert body["row"]["version"] == 1

    @pytest.mark.parametrize(
        ("changes", "field"),
        [
            ({"status": "done"}, "status"),
            ({"english": "  "}, "english"),
            ({"audio_url": "http://pub-abc.r2.dev/a.m4a"}, "audio_url"),
            ({"text": "x" * 501}, "text"),
            ({"accepted": ["a"] * 11}, "accepted"),
        ],
    )
    def test_refuses_bad_values(
        self, client: TestClient, h: dict, changes: dict, field: str
    ) -> None:
        _import(client, h)

        response = _patch(client, h, "W001", **changes)

        assert response.status_code == 422
        assert response.json()["details"]["field"] == field

    def test_a_missing_row_or_course_is_404(self, client: TestClient, h: dict) -> None:
        _import(client, h)

        assert _patch(client, h, "W999", version=1, text="x").status_code == 404
        other = "/api/v1/admin/courses/no-such-course/curriculum"
        assert client.get(other, headers=h).status_code == 404


class TestRecordings:
    def test_a_rows_recording_is_uploaded_then_saved(self, client: TestClient, h: dict) -> None:
        _import(client, h)

        response = client.post(
            f"{C}/audio/uploads",
            json={"row_ref": "W001", "content_type": "audio/mp4", "size": 1234},
            headers=h,
        )

        assert response.status_code == 201, response.text
        upload = response.json()
        assert upload["key"].startswith("am/curriculum/W001/")
        assert upload["key"].endswith(".m4a")
        assert upload["public_url"] == f"https://pub-abc.r2.dev/{upload['key']}"
        assert "r2-secret-never-shown" not in response.text

        saved = _patch(client, h, "W001", audio_url=upload["public_url"]).json()["row"]
        assert saved["audio_url"] == upload["public_url"]
        assert saved["status"] == "draft"
        cleared = _patch(client, h, "W001", audio_url=None).json()["row"]
        assert cleared["audio_url"] is None

    def test_refuses_other_types_sizes_and_rows(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        url = f"{C}/audio/uploads"

        def post(**body: Any) -> int:
            payload = {"row_ref": "W001", "content_type": "audio/mp4", "size": 10, **body}
            return client.post(url, json=payload, headers=h).status_code

        assert post(content_type="video/mp4") == 422
        assert post(size=6 * 1024 * 1024) == 422
        assert post(row_ref="W999") == 404


def test_every_endpoint_is_admin_only(
    make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch, db_path: Path
) -> None:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    learner = make_client(
        FakeTokenVerifier(subject="sub-learner", email="learner@example.com"),
        FakeTokenVerifier(),
    )
    token = learner.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    h = {"Authorization": f"Bearer {token}"}

    assert learner.get(C, headers=h).status_code == 403
    assert learner.put(C, json={"entries": [], "rows": []}, headers=h).status_code == 403
    assert learner.patch(f"{C}/rows/W001", json={"version": 1}, headers=h).status_code == 403
    upload = {"row_ref": "W001", "content_type": "audio/mp4", "size": 1}
    assert learner.post(f"{C}/audio/uploads", json=upload, headers=h).status_code == 403
    assert learner.get(C).status_code == 401
    with sqlite3.connect(db_path) as conn:
        assert conn.execute("SELECT COUNT(*) FROM curriculum_rows").fetchone() == (0,)
