"""Integration tests: the admin site's learner list, learner page and
reports, over HTTP against a temp SQLite database holding the real seeded
content and two learners whose lessons are written straight into it.

"Now" is fixed at Friday 2 October 2026, noon UTC, so its week began on
Monday 28 September.
"""

from __future__ import annotations

import asyncio
import sqlite3
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.infrastructure.api import admin_learner_routers, dependencies
from app.infrastructure.db.seed_lesson_content import COURSES, _content_id, seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
NOW = datetime(2026, 10, 2, 12, 0, tzinfo=UTC)
EN_OM = _content_id(COURSES[1]["slug"])
ABEBE = "user-abebe"
SARA = "user-sara"


def _at(day: str, clock: str = "09:00") -> str:
    """A timestamp as SQLAlchemy keeps it in SQLite."""
    return f"{day} {clock}:00.000000"


@pytest.fixture
def seeded(db_path: Path) -> Path:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    return db_path


@pytest.fixture
def client(make_client: ClientFactory, seeded: Path, monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    client.app.dependency_overrides[admin_learner_routers.get_now] = lambda: NOW  # type: ignore[attr-defined]
    return client


@pytest.fixture
def lessons(seeded: Path) -> dict[str, str]:
    """The first skill of English to Amharic and its first two lessons."""
    with sqlite3.connect(seeded) as conn:
        skill_id, skill_title = conn.execute(
            "SELECT s.id, s.title FROM skills s JOIN categories c ON c.id = s.category_id "
            "WHERE c.course_id = ? ORDER BY c.order_index, s.order_index LIMIT 1",
            (EN_AM_COURSE_ID,),
        ).fetchone()
        first, second = conn.execute(
            "SELECT id FROM lessons WHERE skill_id = ? ORDER BY order_index LIMIT 2", (skill_id,)
        ).fetchall()
    return {"skill": skill_id, "skill_title": skill_title, "first": first[0], "second": second[0]}


@pytest.fixture
def h(client: TestClient, seeded: Path, lessons: dict[str, str]) -> dict[str, str]:
    """Signs the admin in (which makes them a learner too, with no lessons),
    then adds Abebe, who has studied, and Sara, who joined this week and
    has not."""
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    with sqlite3.connect(seeded) as conn:
        conn.execute("UPDATE users SET created_at = ?, first_name = 'Admin'", (_at("2026-08-01"),))
        conn.executemany(
            "INSERT INTO users (id, auth_provider, provider_user_id, selected_language, "
            "daily_xp_target, notification_enabled, active_course_id, email, created_at, "
            "settings, first_name) VALUES (?, 'google', ?, ?, 20, 1, ?, ?, ?, '{}', ?)",
            [
                (
                    ABEBE,
                    "sub-abebe",
                    "am",
                    EN_AM_COURSE_ID,
                    "abebe@example.com",
                    _at("2026-09-01"),
                    "Abebe",
                ),
                (SARA, "sub-sara", "om", EN_OM, "sara@example.com", _at("2026-09-29"), "Sara"),
            ],
        )
        conn.executemany(
            "INSERT INTO lesson_attempts (id, user_id, lesson_id, correct_count, total_count, "
            "xp_awarded, completed_at, result, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, '{}', ?)",
            [
                ("a1", ABEBE, lessons["first"], 5, 10, 10, _at("2026-09-20"), _at("2026-09-20")),
                ("a2", ABEBE, lessons["second"], 10, 10, 20, _at("2026-10-01"), _at("2026-10-01")),
                ("a3", ABEBE, lessons["first"], 8, 10, 16, _at("2026-10-02"), _at("2026-10-02")),
            ],
        )
        conn.execute(
            "INSERT INTO practice_attempts (id, user_id, correct_count, total_count, "
            "xp_awarded, amole_awarded, completed_at, created_at) "
            "VALUES ('p1', ?, 4, 5, 8, 1, ?, ?)",
            (ABEBE, _at("2026-10-02", "10:00"), _at("2026-10-02", "10:00")),
        )
        conn.execute(
            "INSERT INTO user_skill_progress (id, user_id, skill_id, unlocked, crown_level, "
            "completed_at, completed_lesson_ids_this_cycle, created_at) "
            "VALUES ('sp1', ?, ?, 1, 1, ?, '[]', ?)",
            (ABEBE, lessons["skill"], _at("2026-10-01"), _at("2026-09-20")),
        )
        conn.execute(
            "INSERT INTO user_streaks (user_id, current_streak, last_completed_date, "
            "active_freeze_count, created_at) VALUES (?, 2, '2026-10-02', 0, ?)",
            (ABEBE, _at("2026-10-01")),
        )
    return {"Authorization": f"Bearer {token}"}


class TestLearnerList:
    def test_lists_everyone_most_recently_active_first_with_their_totals(
        self, client: TestClient, h: dict
    ) -> None:
        response = client.get(f"{A}/learners", headers=h)

        assert response.status_code == 200
        body = response.json()
        assert [row["name"] for row in body["learners"]] == ["Abebe", "Sara", "Admin"]
        assert (body["total"], body["active_today"], body["active_7_days"]) == (3, 1, 1)
        assert body["not_started"] == 2
        abebe = body["learners"][0]
        assert abebe == {
            "id": ABEBE,
            "name": "Abebe",
            "email": "abebe@example.com",
            "joined_at": "2026-09-01T09:00:00Z",
            "course_id": EN_AM_COURSE_ID,
            "course_title": abebe["course_title"],
            "lessons": 3,
            "practice_sessions": 1,
            "xp": 54,
            "accuracy": round(27 / 35, 4),
            "skills_completed": 1,
            "current_streak": 2,
            "last_active_at": "2026-10-02T10:00:00Z",
        }

    def test_searches_names_and_emails(self, client: TestClient, h: dict) -> None:
        by_name = client.get(f"{A}/learners", params={"search": "sar"}, headers=h).json()
        by_email = client.get(f"{A}/learners", params={"search": "ABEBE@"}, headers=h).json()

        assert [row["id"] for row in by_name["learners"]] == [SARA]
        assert [row["id"] for row in by_email["learners"]] == [ABEBE]

    def test_filters_by_course_sorts_and_pages(self, client: TestClient, h: dict) -> None:
        on_om = client.get(f"{A}/learners", params={"course_id": EN_OM}, headers=h).json()
        by_name = client.get(
            f"{A}/learners",
            params={"sort": "name", "order": "asc", "offset": 1, "limit": 1},
            headers=h,
        ).json()

        assert [row["id"] for row in on_om["learners"]] == [SARA]
        # Abebe, Admin, Sara: the second of them.
        assert by_name["total"] == 3
        assert [row["name"] for row in by_name["learners"]] == ["Admin"]

    def test_a_streak_whose_last_day_has_passed_shows_as_ended(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        with sqlite3.connect(seeded) as conn:
            conn.execute("UPDATE user_streaks SET last_completed_date = '2026-09-29'")

        abebe = client.get(f"{A}/learners", params={"search": "abebe"}, headers=h).json()

        assert abebe["learners"][0]["current_streak"] == 0

    @pytest.mark.parametrize(
        "params", [{"sort": "beans"}, {"limit": 0}, {"limit": 101}, {"offset": -1}]
    )
    def test_refuses_a_bad_sort_or_page(self, client: TestClient, h: dict, params: dict) -> None:
        response = client.get(f"{A}/learners", params=params, headers=h)

        assert response.status_code == 422

    def test_is_for_admins_only(self, make_client: ClientFactory, seeded: Path) -> None:
        learner = make_client(
            FakeTokenVerifier(subject="sub-x", email="x@example.com"), FakeTokenVerifier()
        )
        token = learner.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]

        for path in ("/learners", "/learners/x", "/reports"):
            response = learner.get(f"{A}{path}", headers={"Authorization": f"Bearer {token}"})
            assert response.status_code == 403


class TestLearnerPage:
    def test_shows_totals_days_progress_and_latest_lessons(
        self, client: TestClient, h: dict, lessons: dict[str, str]
    ) -> None:
        response = client.get(f"{A}/learners/{ABEBE}", headers=h)

        assert response.status_code == 200
        body = response.json()
        assert body["learner"]["xp"] == 54
        assert (body["longest_streak"], body["days_active"]) == (2, 3)
        assert body["activity"] == [
            {"date": "2026-09-20", "lessons": 1, "practice_sessions": 0, "xp": 10},
            {"date": "2026-10-01", "lessons": 1, "practice_sessions": 0, "xp": 20},
            {"date": "2026-10-02", "lessons": 1, "practice_sessions": 1, "xp": 24},
        ]
        [course] = body["courses"]
        assert course["course_id"] == EN_AM_COURSE_ID and course["current"] is True
        assert course["skills_completed"] == 1
        assert course["lessons_done"] == 2
        first_skill = course["sections"][0]["skills"][0]
        assert first_skill["id"] == lessons["skill"]
        assert first_skill["state"] == "completed"
        assert first_skill["crown_level"] == 1
        assert first_skill["lessons_done"] == 2
        later = [s for section in course["sections"] for s in section["skills"]][1:]
        assert {s["state"] for s in later} == {"not_started"}
        assert [(r["kind"], r["xp"]) for r in body["recent"]] == [
            ("practice", 8),
            ("lesson", 16),
            ("lesson", 20),
            ("lesson", 10),
        ]
        assert body["recent"][1]["skill_title"] == lessons["skill_title"]

    def test_a_learner_who_has_not_started_shows_their_course_untouched(
        self, client: TestClient, h: dict
    ) -> None:
        body = client.get(f"{A}/learners/{SARA}", headers=h).json()

        assert body["activity"] == [] and body["recent"] == []
        [course] = body["courses"]
        assert course["course_id"] == EN_OM
        assert course["skills_completed"] == 0 and course["lessons_done"] == 0

    def test_an_unknown_learner_is_not_found(self, client: TestClient, h: dict) -> None:
        response = client.get(f"{A}/learners/nobody", headers=h)

        assert response.status_code == 404


class TestReports:
    def test_counts_this_week_and_the_weeks_before(self, client: TestClient, h: dict) -> None:
        response = client.get(f"{A}/reports", params={"period": "week", "count": 4}, headers=h)

        assert response.status_code == 200
        body = response.json()
        assert (body["start"], body["end"]) == ("2026-09-07", "2026-10-04")
        assert [b["start"] for b in body["buckets"]] == [
            "2026-09-07",
            "2026-09-14",
            "2026-09-21",
            "2026-09-28",
        ]
        assert [b["partial"] for b in body["buckets"]] == [False, False, False, True]
        this_week = body["buckets"][-1]["totals"]
        assert this_week == {
            "new_learners": 1,
            "active_learners": 1,
            "lessons": 2,
            "practice_sessions": 1,
            "xp": 44,
            "accuracy": round(22 / 25, 4),
            "skills_completed": 1,
        }
        assert body["buckets"][1]["totals"]["lessons"] == 1  # 20 September
        assert body["totals"]["lessons"] == 3
        assert body["totals"]["active_learners"] == 1
        # The four weeks before: Abebe joined on 1 September, Admin earlier.
        assert body["previous"]["new_learners"] == 1
        assert body["now"] == {
            "total_learners": 3,
            "active_today": 1,
            "active_7_days": 1,
            "active_30_days": 1,
        }
        assert body["top_learners"] == [
            {
                "id": ABEBE,
                "name": "Abebe",
                "email": "abebe@example.com",
                "xp": 54,
                "lessons": 3,
                "accuracy": round(27 / 35, 4),
            }
        ]
        en_am = next(c for c in body["courses"] if c["course_id"] == EN_AM_COURSE_ID)
        assert (en_am["learners"], en_am["active_learners"], en_am["lessons"]) == (2, 1, 3)

    def test_counts_by_day_and_by_month(self, client: TestClient, h: dict) -> None:
        days = client.get(f"{A}/reports", params={"period": "day", "count": 3}, headers=h).json()
        months = client.get(
            f"{A}/reports", params={"period": "month", "count": 2}, headers=h
        ).json()

        assert [(b["start"], b["totals"]["xp"]) for b in days["buckets"]] == [
            ("2026-09-30", 0),
            ("2026-10-01", 20),
            ("2026-10-02", 24),
        ]
        assert [(b["start"], b["end"], b["totals"]["lessons"]) for b in months["buckets"]] == [
            ("2026-09-01", "2026-09-30", 1),
            ("2026-10-01", "2026-10-31", 2),
        ]

    def test_one_course_counts_only_its_learners_and_lessons(
        self, client: TestClient, h: dict
    ) -> None:
        body = client.get(
            f"{A}/reports", params={"period": "week", "count": 1, "course_id": EN_OM}, headers=h
        ).json()

        assert body["totals"]["lessons"] == 0
        assert body["totals"]["new_learners"] == 1  # Sara
        assert body["now"]["total_learners"] == 1
        assert [c["course_id"] for c in body["courses"]] == [EN_OM]

    def test_an_earlier_range_can_be_shown(self, client: TestClient, h: dict) -> None:
        body = client.get(
            f"{A}/reports", params={"period": "week", "count": 1, "end": "2026-09-20"}, headers=h
        ).json()

        assert body["start"] == "2026-09-14"
        assert body["totals"]["lessons"] == 1
        assert body["buckets"][0]["partial"] is False

    @pytest.mark.parametrize(
        "params",
        [{"period": "year"}, {"period": "day", "count": 93}, {"period": "week", "count": 0}],
    )
    def test_refuses_a_bad_period(self, client: TestClient, h: dict, params: dict) -> None:
        response = client.get(f"{A}/reports", params=params, headers=h)

        assert response.status_code == 422
