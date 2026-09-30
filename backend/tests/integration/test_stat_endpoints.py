"""Integration tests for bolt `059-stat-pill-service`:
`GET /api/v1/streak/history` and `GET /api/v1/amole/transactions`, via
`TestClient` against a real temp-file SQLite database, signing in through
the real `/api/v1/auth/google` endpoint.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session as SyncSession

from app.infrastructure.db.lesson_models import (
    AmoleTransactionModel,
    LessonAttemptModel,
    UserStreakModel,
)
from app.infrastructure.db.models import UserModel
from tests.fakes import FakeTokenVerifier


def _sign_in(make_client: Any, subject: str = "google-user-1") -> tuple[Any, str]:
    client = make_client(FakeTokenVerifier(subject=subject), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant-fake-token"})
    assert response.status_code == 200
    return client, response.json()["session_token"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _user_ids(db_path: Path) -> list[str]:
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        ids = [row.id for row in session.scalars(select(UserModel).order_by(UserModel.created_at))]
    engine.dispose()
    return ids


def _add(db_path: Path, *rows: Any) -> None:
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add_all(rows)
        session.commit()
    engine.dispose()


def _attempt(
    attempt_id: str, user_id: str, when: datetime, result: dict[str, Any]
) -> LessonAttemptModel:
    return LessonAttemptModel(
        id=attempt_id,
        user_id=user_id,
        lesson_id="lesson-1",
        correct_count=3,
        total_count=4,
        xp_awarded=0 if result.get("is_review") else 30,
        completed_at=when,
        result=result,
    )


def _at(day: int, hour: int = 12) -> datetime:
    return datetime(2026, 9, day, hour, tzinfo=UTC)


class TestStreakHistory:
    def test_practised_days_streaks_and_join_date(self, make_client: Any, db_path: Path) -> None:
        client, token = _sign_in(make_client)
        (user_id,) = _user_ids(db_path)
        _add(
            db_path,
            _attempt("a1", user_id, _at(1), {"is_review": False}),
            _attempt("a2", user_id, _at(2), {"is_review": False}),
            # A row saved before reviews existed has no `is_review`.
            _attempt("a3", user_id, _at(3, hour=23), {}),
            # A replay only: not a practised day.
            _attempt("r5", user_id, _at(5), {"is_review": True}),
            _attempt("a20", user_id, _at(20), {"is_review": False}),
            _attempt("a20b", user_id, _at(20, hour=21), {"is_review": True}),
            UserStreakModel(
                user_id=user_id,
                current_streak=1,
                last_completed_date=date(2026, 9, 20),
                active_freeze_count=0,
            ),
        )

        response = client.get(
            "/api/v1/streak/history",
            params={"from": "2026-09-02", "to": "2026-09-30"},
            headers=_auth(token),
        )

        assert response.status_code == 200
        body = response.json()
        assert body["from"] == "2026-09-02"
        assert body["to"] == "2026-09-30"
        assert body["practised_days"] == ["2026-09-02", "2026-09-03", "2026-09-20"]
        assert body["current_streak"] == 1
        # 1-3 September: day 1 is outside the range but still counts.
        assert body["longest_streak"] == 3
        assert body["joined_on"] == datetime.now(UTC).date().isoformat()

    def test_another_learners_days_are_not_shown(self, make_client: Any, db_path: Path) -> None:
        _sign_in(make_client, subject="someone-else")
        client, token = _sign_in(make_client)
        other, me = _user_ids(db_path)
        _add(
            db_path,
            _attempt("theirs", other, _at(10), {"is_review": False}),
            _attempt("mine", me, _at(11), {"is_review": False}),
        )

        body = client.get(
            "/api/v1/streak/history",
            params={"from": "2026-09-01", "to": "2026-09-30"},
            headers=_auth(token),
        ).json()

        assert body["practised_days"] == ["2026-09-11"]

    def test_a_new_learner_gets_an_empty_calendar(self, make_client: Any) -> None:
        client, token = _sign_in(make_client)

        response = client.get(
            "/api/v1/streak/history",
            params={"from": "2026-09-01", "to": "2026-09-30"},
            headers=_auth(token),
        )

        assert response.status_code == 200
        body = response.json()
        assert body["practised_days"] == []
        assert body["current_streak"] == 0
        assert body["longest_streak"] == 0

    def test_a_backwards_range_is_422(self, make_client: Any) -> None:
        client, token = _sign_in(make_client)

        response = client.get(
            "/api/v1/streak/history",
            params={"from": "2026-09-10", "to": "2026-09-09"},
            headers=_auth(token),
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_range"

    def test_186_days_is_allowed_and_187_is_422(self, make_client: Any) -> None:
        client, token = _sign_in(make_client)
        end = date(2026, 9, 30)

        def ask(days: int) -> int:
            start = end - timedelta(days=days - 1)
            return client.get(
                "/api/v1/streak/history",
                params={"from": start.isoformat(), "to": end.isoformat()},
                headers=_auth(token),
            ).status_code

        assert ask(186) == 200
        assert ask(187) == 422

    def test_missing_or_malformed_dates_are_422(self, make_client: Any) -> None:
        client, token = _sign_in(make_client)

        missing = client.get(
            "/api/v1/streak/history", params={"from": "2026-09-01"}, headers=_auth(token)
        )
        malformed = client.get(
            "/api/v1/streak/history",
            params={"from": "yesterday", "to": "2026-09-30"},
            headers=_auth(token),
        )

        assert missing.status_code == 422
        assert malformed.status_code == 422

    def test_without_a_session_is_401(self, make_client: Any) -> None:
        client, _ = _sign_in(make_client)

        response = client.get(
            "/api/v1/streak/history", params={"from": "2026-09-01", "to": "2026-09-30"}
        )

        assert response.status_code == 401


class TestAmoleHistory:
    @staticmethod
    def _entry(entry_id: str, user_id: str, minute: int, amount: int, source: str) -> Any:
        return AmoleTransactionModel(
            id=entry_id,
            user_id=user_id,
            amount=amount,
            source=source,
            reference_id=f"ref-{entry_id}",
            created_at=datetime(2030, 1, 1, 12, minute, tzinfo=UTC),
        )

    def test_newest_first_with_amount_source_and_time(
        self, make_client: Any, db_path: Path
    ) -> None:
        client, token = _sign_in(make_client)
        (user_id,) = _user_ids(db_path)
        _add(
            db_path,
            self._entry("e1", user_id, 1, 10, "lesson_completion"),
            self._entry("e2", user_id, 2, -350, "bean_refill"),
            self._entry("e3", user_id, 3, 5, "perfect_lesson"),
        )

        response = client.get("/api/v1/amole/transactions", headers=_auth(token))

        assert response.status_code == 200
        entries = response.json()["entries"]
        assert [(e["amount"], e["source"]) for e in entries[:3]] == [
            (5, "perfect_lesson"),
            (-350, "bean_refill"),
            (10, "lesson_completion"),
        ]
        assert entries[0]["created_at"].startswith("2030-01-01T12:03:00")

    def test_the_limit_and_its_default(self, make_client: Any, db_path: Path) -> None:
        client, token = _sign_in(make_client)
        (user_id,) = _user_ids(db_path)
        _add(
            db_path,
            *[self._entry(f"e{n}", user_id, n, 1, "lesson_completion") for n in range(25)],
        )

        default = client.get("/api/v1/amole/transactions", headers=_auth(token)).json()
        three = client.get(
            "/api/v1/amole/transactions", params={"limit": 3}, headers=_auth(token)
        ).json()

        assert len(default["entries"]) == 20
        assert len(three["entries"]) == 3

    def test_ties_come_back_in_a_stable_order(self, make_client: Any, db_path: Path) -> None:
        client, token = _sign_in(make_client)
        (user_id,) = _user_ids(db_path)
        _add(
            db_path,
            *[self._entry(f"t{n}", user_id, 5, n, "lesson_completion") for n in range(4)],
        )

        first = client.get("/api/v1/amole/transactions", headers=_auth(token)).json()
        second = client.get("/api/v1/amole/transactions", headers=_auth(token)).json()

        assert first == second
        assert [e["amount"] for e in first["entries"][:4]] == [3, 2, 1, 0]

    def test_another_learners_entries_are_not_shown(self, make_client: Any, db_path: Path) -> None:
        _sign_in(make_client, subject="someone-else")
        client, token = _sign_in(make_client)
        other, _me = _user_ids(db_path)
        _add(db_path, self._entry("theirs", other, 1, 999, "lesson_completion"))

        entries = client.get("/api/v1/amole/transactions", headers=_auth(token)).json()["entries"]

        assert all(e["amount"] != 999 for e in entries)

    def test_a_limit_out_of_range_is_422(self, make_client: Any) -> None:
        client, token = _sign_in(make_client)

        for limit in (0, 51):
            response = client.get(
                "/api/v1/amole/transactions", params={"limit": limit}, headers=_auth(token)
            )
            assert response.status_code == 422

    def test_without_a_session_is_401(self, make_client: Any) -> None:
        client, _ = _sign_in(make_client)

        assert client.get("/api/v1/amole/transactions").status_code == 401
