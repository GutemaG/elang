"""Response schemas for the admin site's learner pages and reports
(`admin_learner_routers.py`). Field for field the dataclasses of
`admin_learner_use_cases`, read from their attributes."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class _FromUseCase(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class AdminLearner(_FromUseCase):
    id: str
    name: str
    email: str | None
    joined_at: datetime
    course_id: str
    course_title: str
    lessons: int
    practice_sessions: int
    xp: int
    # Right answers over all answers, 0 to 1; null before any answer.
    accuracy: float | None
    skills_completed: int
    current_streak: int
    last_active_at: datetime | None


class AdminLearnerPage(_FromUseCase):
    learners: list[AdminLearner]
    total: int
    active_today: int
    active_7_days: int
    not_started: int


class AdminDayActivity(_FromUseCase):
    date: date
    lessons: int
    practice_sessions: int
    xp: int


class AdminSkillProgress(_FromUseCase):
    id: str
    title: str
    state: Literal["completed", "started", "not_started"]
    crown_level: int
    lessons_total: int
    lessons_done: int


class AdminSectionProgress(_FromUseCase):
    id: str
    title: str
    skills: list[AdminSkillProgress]


class AdminCourseProgress(_FromUseCase):
    course_id: str
    title: str
    current: bool
    skills_total: int
    skills_completed: int
    lessons_total: int
    lessons_done: int
    sections: list[AdminSectionProgress]


class AdminRecentAttempt(_FromUseCase):
    kind: Literal["lesson", "practice"]
    at: datetime
    lesson_title: str | None
    skill_title: str | None
    course_title: str | None
    correct: int
    answered: int
    xp: int


class AdminLearnerDetail(_FromUseCase):
    learner: AdminLearner
    auth_provider: str
    daily_xp_target: int
    longest_streak: int
    days_active: int
    activity: list[AdminDayActivity]
    courses: list[AdminCourseProgress]
    recent: list[AdminRecentAttempt]


class AdminTotals(_FromUseCase):
    new_learners: int
    active_learners: int
    lessons: int
    practice_sessions: int
    xp: int
    accuracy: float | None
    skills_completed: int


class AdminBucket(_FromUseCase):
    start: date
    end: date
    partial: bool
    totals: AdminTotals


class AdminSnapshot(_FromUseCase):
    total_learners: int
    active_today: int
    active_7_days: int
    active_30_days: int


class AdminCourseActivity(_FromUseCase):
    course_id: str
    title: str
    learners: int
    active_learners: int
    lessons: int
    xp: int
    skills_completed: int


class AdminTopLearner(_FromUseCase):
    id: str
    name: str
    email: str | None
    xp: int
    lessons: int
    accuracy: float | None


class AdminReport(_FromUseCase):
    period: Literal["day", "week", "month"]
    course_id: str | None
    start: date
    end: date
    totals: AdminTotals
    previous: AdminTotals
    buckets: list[AdminBucket]
    now: AdminSnapshot
    courses: list[AdminCourseActivity]
    top_learners: list[AdminTopLearner]
