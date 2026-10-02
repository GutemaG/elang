"""The admin site's learner pages and reports (`026-learner-reports`).

Three reads, none of which changes anything:

- `list_learners`: every learner with their totals, searchable, sortable
  and a page at a time;
- `get_learner`: one learner's totals, recent days, progress through each
  course they have studied, and latest lessons;
- `get_report`: activity counted by day, week or month, with the totals
  for the whole range and the range before it, for the dashboard.

Days are UTC days and weeks start on Monday, as the streak and the weekly
leagues count them.
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from typing import Literal

from app.domain.lesson.exceptions import ContentNotFoundError, InvalidRangeError
from app.domain.lesson.services import longest_streak
from app.infrastructure.db.admin_learner_repository import (
    Attempt,
    LearnerRow,
    SqlAlchemyAdminLearnerRepository,
)
from app.infrastructure.db.lesson_models import CourseModel, UserStreakModel

Period = Literal["day", "week", "month"]
# (buckets shown when none are asked for, the most that may be asked for)
PERIOD_COUNTS: dict[str, tuple[int, int]] = {"day": (30, 92), "week": (12, 53), "month": (12, 24)}

SORTS = ("last_active", "xp", "lessons", "streak", "joined", "name")
MAX_PAGE = 100
# The learner page's activity calendar: thirteen weeks.
ACTIVITY_DAYS = 91
RECENT_ATTEMPTS = 25
TOP_LEARNERS = 10


# --- shared ------------------------------------------------------------------


def _accuracy(correct: int, answered: int) -> float | None:
    return round(correct / answered, 4) if answered else None


def live_streak(streak: UserStreakModel | None, today: date) -> int:
    """The streak as it stands today: a streak whose last day is before
    yesterday has already ended (unless a freeze covers the one missed
    day), even though the stored count only resets on the next lesson."""
    if streak is None or streak.last_completed_date is None:
        return 0
    gap = (today - streak.last_completed_date).days
    if gap <= 1 or (gap == 2 and streak.active_freeze_count > 0):
        return streak.current_streak
    return 0


def _name(row: LearnerRow) -> str:
    return row.user.first_name or (row.user.email or "").split("@")[0] or "Learner"


def _as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def _midnight(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=UTC)


# --- the learner list --------------------------------------------------------


@dataclass(frozen=True)
class LearnerSummary:
    id: str
    name: str
    email: str | None
    joined_at: datetime
    course_id: str
    course_title: str
    lessons: int
    practice_sessions: int
    xp: int
    accuracy: float | None
    skills_completed: int
    current_streak: int
    last_active_at: datetime | None


@dataclass(frozen=True)
class LearnerPage:
    learners: list[LearnerSummary]
    # Every learner matching the search and course, of which `learners` is
    # one page; and how many of those were active lately or never started.
    total: int
    active_today: int
    active_7_days: int
    not_started: int


def _summary(row: LearnerRow, courses: dict[str, CourseModel], today: date) -> LearnerSummary:
    course = courses.get(row.user.active_course_id)
    return LearnerSummary(
        id=row.user.id,
        name=_name(row),
        email=row.user.email,
        joined_at=_as_utc(row.user.created_at),
        course_id=row.user.active_course_id,
        course_title=course.title if course else row.user.active_course_id,
        lessons=row.lessons,
        practice_sessions=row.practice_sessions,
        xp=row.xp,
        accuracy=_accuracy(row.correct, row.answered),
        skills_completed=row.skills_completed,
        current_streak=live_streak(row.streak, today),
        last_active_at=row.last_active_at,
    )


def _sort_key(sort: str):  # type: ignore[no-untyped-def]
    never = datetime.min.replace(tzinfo=UTC)
    return {
        "last_active": lambda s: (s.last_active_at or never, s.joined_at),
        "xp": lambda s: (s.xp, s.lessons),
        "lessons": lambda s: (s.lessons, s.xp),
        "streak": lambda s: (s.current_streak, s.xp),
        "joined": lambda s: s.joined_at,
        "name": lambda s: (s.name.casefold(), s.email or ""),
    }[sort]


async def list_learners(
    repo: SqlAlchemyAdminLearnerRepository,
    *,
    search: str = "",
    course_id: str | None = None,
    sort: str = "last_active",
    descending: bool = True,
    offset: int = 0,
    limit: int = 25,
    now: datetime,
) -> LearnerPage:
    if sort not in SORTS:
        raise InvalidRangeError(f"`sort` must be one of {', '.join(SORTS)}")
    if offset < 0 or not 1 <= limit <= MAX_PAGE:
        raise InvalidRangeError(f"`offset` must be 0 or more and `limit` 1 to {MAX_PAGE}")

    today = now.astimezone(UTC).date()
    courses = await repo.courses_by_id()
    rows = await repo.list_learners(search=search.strip(), course_id=course_id or None)
    summaries = sorted(
        (_summary(row, courses, today) for row in rows),
        key=_sort_key(sort),
        reverse=descending,
    )
    week_ago = _midnight(today - timedelta(days=6))
    return LearnerPage(
        learners=summaries[offset : offset + limit],
        total=len(summaries),
        active_today=sum(
            1 for s in summaries if s.last_active_at and s.last_active_at.date() == today
        ),
        active_7_days=sum(
            1 for s in summaries if s.last_active_at and s.last_active_at >= week_ago
        ),
        not_started=sum(1 for s in summaries if s.lessons == 0),
    )


# --- one learner ---------------------------------------------------------------


@dataclass(frozen=True)
class DayActivity:
    date: date
    lessons: int
    practice_sessions: int
    xp: int


@dataclass(frozen=True)
class SkillProgress:
    id: str
    title: str
    state: Literal["completed", "started", "not_started"]
    crown_level: int
    lessons_total: int
    lessons_done: int


@dataclass(frozen=True)
class SectionProgress:
    id: str
    title: str
    skills: list[SkillProgress]


@dataclass(frozen=True)
class CourseProgress:
    course_id: str
    title: str
    current: bool
    skills_total: int
    skills_completed: int
    lessons_total: int
    lessons_done: int
    sections: list[SectionProgress]


@dataclass(frozen=True)
class RecentAttempt:
    kind: Literal["lesson", "practice"]
    at: datetime
    lesson_title: str | None
    skill_title: str | None
    course_title: str | None
    correct: int
    answered: int
    xp: int


@dataclass(frozen=True)
class LearnerDetail:
    learner: LearnerSummary
    auth_provider: str
    daily_xp_target: int
    longest_streak: int
    days_active: int
    activity: list[DayActivity]
    courses: list[CourseProgress]
    recent: list[RecentAttempt]


async def get_learner(
    repo: SqlAlchemyAdminLearnerRepository, user_id: str, *, now: datetime
) -> LearnerDetail:
    row = await repo.get_learner(user_id)
    if row is None:
        raise ContentNotFoundError(f"No learner has id '{user_id}'")
    today = now.astimezone(UTC).date()
    courses = await repo.courses_by_id()
    lessons = await repo.lesson_attempts_of(user_id)
    practice = await repo.practice_attempts_of(user_id)
    progress = {p.skill_id: p for p in await repo.skill_progress_of(user_id)}

    # Each day the learner studied, and the last thirteen weeks of them.
    days: set[date] = set()
    by_day: dict[date, list[int]] = defaultdict(lambda: [0, 0, 0])
    first_shown = today - timedelta(days=ACTIVITY_DAYS - 1)
    for attempt, *_ in lessons:
        day = _as_utc(attempt.completed_at).date()
        days.add(day)
        if day >= first_shown:
            by_day[day][0] += 1
            by_day[day][2] += attempt.xp_awarded
    for session in practice:
        day = _as_utc(session.completed_at).date()
        days.add(day)
        if day >= first_shown:
            by_day[day][1] += 1
            by_day[day][2] += session.xp_awarded

    # Progress through the course they are on and any other they studied.
    done_lessons: dict[str, set[str]] = defaultdict(set)
    studied: list[str] = []
    for attempt, _lesson, skill_id, _skill, course_id in lessons:
        done_lessons[skill_id].add(attempt.lesson_id)
        if course_id not in studied:
            studied.append(course_id)
    current = row.user.active_course_id
    course_ids = [current] + [c for c in studied if c != current]
    outlines = await repo.course_outlines(course_ids)
    course_progress: list[CourseProgress] = []
    for course_id in course_ids:
        outline = outlines.get(course_id)
        if outline is None:
            continue
        sections = []
        for section in outline.sections:
            skills = []
            for skill in (s for s in outline.skills if s.category_id == section.id):
                total = outline.lesson_counts.get(skill.id, 0)
                done = min(total, len(done_lessons.get(skill.id, ())))
                p = progress.get(skill.id)
                state: Literal["completed", "started", "not_started"] = (
                    "completed"
                    if p is not None and p.completed_at is not None
                    else "started"
                    if done
                    else "not_started"
                )
                skills.append(
                    SkillProgress(
                        id=skill.id,
                        title=skill.title,
                        state=state,
                        crown_level=p.crown_level if p else 0,
                        lessons_total=total,
                        lessons_done=done,
                    )
                )
            sections.append(SectionProgress(id=section.id, title=section.title, skills=skills))
        all_skills = [s for section in sections for s in section.skills]
        course_progress.append(
            CourseProgress(
                course_id=course_id,
                title=outline.course.title,
                current=course_id == current,
                skills_total=len(all_skills),
                skills_completed=sum(1 for s in all_skills if s.state == "completed"),
                lessons_total=sum(s.lessons_total for s in all_skills),
                lessons_done=sum(s.lessons_done for s in all_skills),
                sections=sections,
            )
        )

    recent = [
        RecentAttempt(
            kind="lesson",
            at=_as_utc(attempt.completed_at),
            lesson_title=lesson_title,
            skill_title=skill_title,
            course_title=courses[course_id].title if course_id in courses else None,
            correct=attempt.correct_count,
            answered=attempt.total_count,
            xp=attempt.xp_awarded,
        )
        for attempt, lesson_title, _skill_id, skill_title, course_id in lessons[:RECENT_ATTEMPTS]
    ] + [
        RecentAttempt(
            kind="practice",
            at=_as_utc(session.completed_at),
            lesson_title=None,
            skill_title=None,
            course_title=None,
            correct=session.correct_count,
            answered=session.total_count,
            xp=session.xp_awarded,
        )
        for session in practice[:RECENT_ATTEMPTS]
    ]
    recent.sort(key=lambda r: r.at, reverse=True)

    return LearnerDetail(
        learner=_summary(row, courses, today),
        auth_provider=row.user.auth_provider,
        daily_xp_target=row.user.daily_xp_target,
        longest_streak=longest_streak(days),
        days_active=len(days),
        activity=[
            DayActivity(date=day, lessons=n[0], practice_sessions=n[1], xp=n[2])
            for day, n in sorted(by_day.items())
        ],
        courses=course_progress,
        recent=recent[:RECENT_ATTEMPTS],
    )


# --- reports -----------------------------------------------------------------


def bucket_start(day: date, period: str) -> date:
    """The first day of the day, week (Monday) or month holding `day`."""
    if period == "week":
        return day - timedelta(days=day.weekday())
    if period == "month":
        return day.replace(day=1)
    return day


def next_bucket(start: date, period: str) -> date:
    if period == "week":
        return start + timedelta(days=7)
    if period == "month":
        return (start.replace(day=28) + timedelta(days=4)).replace(day=1)
    return start + timedelta(days=1)


def previous_bucket(start: date, period: str) -> date:
    if period == "month":
        return (start - timedelta(days=1)).replace(day=1)
    return start - (timedelta(days=7) if period == "week" else timedelta(days=1))


def buckets(period: str, count: int, end: date) -> list[date]:
    """The first days of `count` buckets, oldest first, the last holding `end`."""
    starts = [bucket_start(end, period)]
    while len(starts) < count:
        starts.append(previous_bucket(starts[-1], period))
    return starts[::-1]


@dataclass(frozen=True)
class Totals:
    new_learners: int
    active_learners: int
    lessons: int
    practice_sessions: int
    xp: int
    accuracy: float | None
    skills_completed: int


@dataclass(frozen=True)
class Bucket:
    start: date
    # The last day it covers; `partial` when that is today or later, so the
    # bucket is still filling.
    end: date
    partial: bool
    totals: Totals


@dataclass(frozen=True)
class Snapshot:
    """Right now, whatever range is shown."""

    total_learners: int
    active_today: int
    active_7_days: int
    active_30_days: int


@dataclass(frozen=True)
class CourseActivity:
    course_id: str
    title: str
    learners: int
    active_learners: int
    lessons: int
    xp: int
    skills_completed: int


@dataclass(frozen=True)
class TopLearner:
    id: str
    name: str
    email: str | None
    xp: int
    lessons: int
    accuracy: float | None


@dataclass(frozen=True)
class Report:
    period: str
    course_id: str | None
    start: date
    end: date
    totals: Totals
    previous: Totals
    buckets: list[Bucket]
    now: Snapshot
    courses: list[CourseActivity]
    top_learners: list[TopLearner]


def _totals(
    attempts: Iterable[Attempt], joined: Iterable[datetime], completed: Iterable[datetime]
) -> Totals:
    attempts = list(attempts)
    correct = sum(a.correct for a in attempts)
    answered = sum(a.answered for a in attempts)
    return Totals(
        new_learners=sum(1 for _ in joined),
        active_learners=len({a.user_id for a in attempts}),
        lessons=sum(1 for a in attempts if not a.practice),
        practice_sessions=sum(1 for a in attempts if a.practice),
        xp=sum(a.xp for a in attempts),
        accuracy=_accuracy(correct, answered),
        skills_completed=sum(1 for _ in completed),
    )


async def get_report(
    repo: SqlAlchemyAdminLearnerRepository,
    *,
    period: str = "week",
    count: int | None = None,
    end: date | None = None,
    course_id: str | None = None,
    now: datetime,
) -> Report:
    if period not in PERIOD_COUNTS:
        raise InvalidRangeError("`period` must be day, week or month")
    default_count, max_count = PERIOD_COUNTS[period]
    count = default_count if count is None else count
    if not 1 <= count <= max_count:
        raise InvalidRangeError(f"`count` must be 1 to {max_count} for {period}s")
    today = now.astimezone(UTC).date()
    end = min(end or today, today)

    starts = buckets(period, count, end)
    range_start = starts[0]
    range_end = next_bucket(starts[-1], period)  # exclusive
    previous_start = buckets(period, count, previous_bucket(range_start, period))[0]
    month_ago = today - timedelta(days=29)
    fetch_start = min(previous_start, month_ago)
    fetch_end = max(range_end, today + timedelta(days=1))

    courses = await repo.courses_by_id()
    attempts = await repo.attempts_between(_midnight(fetch_start), _midnight(fetch_end))
    accounts = await repo.accounts()
    completions = await repo.skills_completed_between(_midnight(fetch_start), _midnight(fetch_end))
    if course_id:
        attempts = [a for a in attempts if a.course_id == course_id]
        accounts = [a for a in accounts if a[2] == course_id]
        completions = [c for c in completions if c[1] == course_id]

    def between(first: date, after: date) -> Totals:
        lo, hi = _midnight(first), _midnight(after)
        return _totals(
            (a for a in attempts if lo <= a.at < hi),
            (joined for _, joined, _ in accounts if lo <= joined < hi),
            (at for _, _, at in completions if lo <= at < hi),
        )

    def active_since(first: date) -> int:
        lo = _midnight(first)
        return len({a.user_id for a in attempts if a.at >= lo})

    shown = [a for a in attempts if _midnight(range_start) <= a.at < _midnight(range_end)]

    per_course: dict[str, list[Attempt]] = defaultdict(list)
    for a in shown:
        if a.course_id:
            per_course[a.course_id].append(a)
    on_course: dict[str, int] = defaultdict(int)
    for _, _, c in accounts:
        on_course[c] += 1
    completed_on: dict[str, int] = defaultdict(int)
    for _, c, at in completions:
        if _midnight(range_start) <= at < _midnight(range_end):
            completed_on[c] += 1
    course_rows = [
        CourseActivity(
            course_id=c.id,
            title=c.title,
            learners=on_course.get(c.id, 0),
            active_learners=len({a.user_id for a in per_course.get(c.id, [])}),
            lessons=sum(1 for a in per_course.get(c.id, []) if not a.practice),
            xp=sum(a.xp for a in per_course.get(c.id, [])),
            skills_completed=completed_on.get(c.id, 0),
        )
        for c in courses.values()
        if not course_id or c.id == course_id
    ]

    per_learner: dict[str, list[Attempt]] = defaultdict(list)
    for a in shown:
        per_learner[a.user_id].append(a)
    leaders = sorted(
        per_learner.items(), key=lambda kv: (sum(a.xp for a in kv[1]), len(kv[1])), reverse=True
    )[:TOP_LEARNERS]
    users = await repo.users_by_id([user_id for user_id, _ in leaders])
    top = []
    for user_id, mine in leaders:
        user = users.get(user_id)
        email = user.email if user else None
        top.append(
            TopLearner(
                id=user_id,
                name=(user.first_name if user else None)
                or (email or "").split("@")[0]
                or "Learner",
                email=email,
                xp=sum(a.xp for a in mine),
                lessons=sum(1 for a in mine if not a.practice),
                accuracy=_accuracy(sum(a.correct for a in mine), sum(a.answered for a in mine)),
            )
        )

    return Report(
        period=period,
        course_id=course_id or None,
        start=range_start,
        end=range_end - timedelta(days=1),
        totals=between(range_start, range_end),
        previous=between(previous_start, range_start),
        buckets=[
            Bucket(
                start=start,
                end=next_bucket(start, period) - timedelta(days=1),
                partial=next_bucket(start, period) - timedelta(days=1) >= today,
                totals=between(start, next_bucket(start, period)),
            )
            for start in starts
        ],
        now=Snapshot(
            total_learners=len(accounts),
            active_today=active_since(today),
            active_7_days=active_since(today - timedelta(days=6)),
            active_30_days=active_since(month_ago),
        ),
        courses=course_rows,
        top_learners=top,
    )
