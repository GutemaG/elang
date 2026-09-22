"""Shared in-memory/fake test doubles.

Per `coding-standards.md`: mock at the network/DB boundary only, never the
domain logic under test. These doubles replace `TokenVerifier` (network) and
the `UserRepository`/`AuthSessionRepository` Protocols (DB) -- never
`AuthenticationService`, `OnboardingAttachmentPolicy`, or
`SessionValidationService` themselves, which are always exercised for real.
"""

from __future__ import annotations

import uuid
from collections.abc import Sequence
from dataclasses import replace
from datetime import UTC, date, datetime

from app.domain.course import Course, CourseStatus
from app.domain.entities import AuthSession, User
from app.domain.lesson.entities import (
    AmoleTransaction,
    Category,
    Exercise,
    Lesson,
    LessonAttempt,
    Skill,
    UserBeans,
    UserSkillProgress,
    UserStreak,
    UserVocabProgress,
    VocabItem,
)
from app.domain.value_objects import AuthProvider, VerifiedIdentity

# Bolt 024: the deterministic id of the English to Amharic course -- the same
# one the migration and the seed create (uuid5 of the "course:en-am" slug), so
# fixtures, the fake repositories and the real test database all agree.
EN_AM_COURSE_ID = str(
    uuid.uuid5(uuid.uuid5(uuid.NAMESPACE_DNS, "buna.app/lesson-content"), "course:en-am")
)


def make_course(
    course_id: str = EN_AM_COURSE_ID,
    *,
    learning: str = "am",
    from_language: str = "en",
    title: str = "English to Amharic",
    status: CourseStatus = CourseStatus.AVAILABLE,
    order_index: int = 1,
) -> Course:
    return Course(
        id=course_id,
        learning_language=learning,
        from_language=from_language,
        title=title,
        status=status,
        order_index=order_index,
    )


class FakeCourseRepository:
    """In-memory stand-in for `app.domain.course.CourseRepository` (bolt
    `024-courses-service`). `get_for_skill` answers from `course_by_skill`,
    falling back to the first course, so tests that do not care about courses
    just get an available English to Amharic course.
    """

    def __init__(
        self,
        courses: list[Course] | None = None,
        course_by_skill: dict[str, str] | None = None,
        skill_totals: dict[str, int] | None = None,
        completed_skills: dict[str, int] | None = None,
    ) -> None:
        self._courses = list(courses) if courses is not None else [make_course()]
        self._course_by_skill = dict(course_by_skill or {})
        self._skill_totals = dict(skill_totals or {})
        self._completed_skills = dict(completed_skills or {})

    async def list_all(self) -> list[Course]:
        return sorted(self._courses, key=lambda c: c.order_index)

    async def get_by_id(self, course_id: str) -> Course | None:
        return next((c for c in self._courses if c.id == course_id), None)

    async def get_for_skill(self, skill_id: str) -> Course | None:
        course_id = self._course_by_skill.get(skill_id)
        if course_id is not None:
            return await self.get_by_id(course_id)
        return self._courses[0] if self._courses else None

    async def count_skills_by_course(self) -> dict[str, int]:
        return dict(self._skill_totals)

    async def count_completed_skills_by_course(self, user_id: str) -> dict[str, int]:
        return dict(self._completed_skills)


class FakeTokenVerifier:
    """Stands in for `GoogleTokenVerifier`/`AppleTokenVerifier`.

    Configure `subject` to succeed with that provider_user_id, or
    `exception` to simulate `InvalidTokenError`/`ExpiredTokenError`/
    `ProviderUnreachableError`. Never makes a real network call.
    """

    def __init__(
        self,
        *,
        subject: str | None = None,
        exception: Exception | None = None,
        email: str | None = None,
    ) -> None:
        self.next_subject = subject
        self.next_exception = exception
        # The provider-verified email to vouch for (ADR-16); `None` is an
        # unverified or absent email.
        self.next_email = email
        self.calls: list[str] = []

    async def verify(self, token: str) -> VerifiedIdentity:
        self.calls.append(token)
        if self.next_exception is not None:
            raise self.next_exception
        if self.next_subject is None:
            raise AssertionError("FakeTokenVerifier: no subject or exception configured")
        return VerifiedIdentity(subject=self.next_subject, email=self.next_email)

    async def aclose(self) -> None:
        """No-op -- matches AppleTokenVerifier's interface for lifespan/teardown symmetry."""


class FakeUserRepository:
    """In-memory stand-in for `app.domain.repositories.UserRepository`."""

    def __init__(self, users: list[User] | None = None) -> None:
        self._users: dict[str, User] = {u.id: u for u in (users or [])}
        self.get_by_id_calls = 0
        self.update_calls = 0

    async def find_by_provider_identity(
        self, auth_provider: AuthProvider, provider_user_id: str
    ) -> User | None:
        for user in self._users.values():
            if (
                user.provider_identity.auth_provider == auth_provider
                and user.provider_identity.provider_user_id == provider_user_id
            ):
                return user
        return None

    async def add(self, user: User) -> User:
        self._users[user.id] = user
        return user

    async def get_by_id(self, user_id: str) -> User | None:
        self.get_by_id_calls += 1
        return self._users.get(user_id)

    async def update(self, user: User) -> User:
        self.update_calls += 1
        self._users[user.id] = user
        return user

    async def set_email(self, user_id: str, email: str | None) -> User:
        user = replace(self._users[user_id], email=email)
        self._users[user_id] = user
        return user


class FakeAuthSessionRepository:
    """In-memory stand-in for `app.domain.repositories.AuthSessionRepository`."""

    def __init__(self) -> None:
        self._sessions: dict[str, AuthSession] = {}
        self._session_id_by_token: dict[str, str] = {}
        self.extend_calls = 0

    async def add(self, session: AuthSession) -> AuthSession:
        self._sessions[session.id] = session
        self._session_id_by_token[session.token.value] = session.id
        return session

    async def find_by_token(self, token_value: str) -> AuthSession | None:
        session_id = self._session_id_by_token.get(token_value)
        if session_id is None:
            return None
        return self._sessions.get(session_id)

    async def get_by_id(self, session_id: str) -> AuthSession | None:
        return self._sessions.get(session_id)

    async def extend(self, session_id: str, expires_at: datetime) -> None:
        session = self._sessions[session_id]
        self._sessions[session_id] = replace(
            session, token=replace(session.token, expires_at=expires_at)
        )
        self.extend_calls += 1


class FakeCategoryRepository:
    """In-memory stand-in for `app.domain.lesson.repositories.CategoryRepository`."""

    def __init__(self, categories: list[Category] | None = None) -> None:
        self._categories = list(categories or [])

    async def list_all(self) -> list[Category]:
        return sorted(self._categories, key=lambda c: c.order_index)

    async def list_by_course(self, course_id: str) -> list[Category]:
        return sorted(
            (c for c in self._categories if c.course_id == course_id),
            key=lambda c: c.order_index,
        )


class FakeSkillRepository:
    """In-memory stand-in for `app.domain.lesson.repositories.SkillRepository`."""

    def __init__(self, skills: list[Skill] | None = None) -> None:
        self._skills = list(skills or [])

    async def list_all(self) -> list[Skill]:
        return list(self._skills)


# Bolt 008: fixed, stable stand-in for a real `updated_at`-derived content
# version -- unit tests for `get_lesson_content`/`get_skill_tree` don't
# exercise version-change behavior (that's covered by the real
# `SqlAlchemyLessonRepository` integration tests), just that the signal is
# threaded through.
FAKE_CONTENT_VERSION = datetime(2026, 1, 1, tzinfo=UTC)


class FakeLessonRepository:
    """In-memory stand-in for `app.domain.lesson.repositories.LessonRepository`."""

    def __init__(self, lessons: list[Lesson] | None = None) -> None:
        self._lessons: dict[str, Lesson] = {lesson.id: lesson for lesson in (lessons or [])}

    async def get_by_id(self, lesson_id: str) -> Lesson | None:
        return self._lessons.get(lesson_id)

    async def get_content_version(self, lesson_id: str) -> datetime | None:
        if lesson_id not in self._lessons:
            return None
        return FAKE_CONTENT_VERSION


class FakeLessonRepositoryWithSkillIndex(FakeLessonRepository):
    """`FakeLessonRepository` extended with `list_lesson_ids_by_skill`
    (bolt 005) -- a separate class so bolt 004's tests exercising the
    plain `FakeLessonRepository` contract are untouched.
    """

    async def list_lesson_ids_by_skill(self, skill_id: str) -> tuple[str, ...]:
        matching = [lesson for lesson in self._lessons.values() if lesson.skill_id == skill_id]
        matching.sort(key=lambda lesson: lesson.order_index)
        return tuple(lesson.id for lesson in matching)

    async def list_lesson_ids_by_skills(
        self, skill_ids: Sequence[str]
    ) -> dict[str, tuple[str, ...]]:
        result: dict[str, tuple[str, ...]] = {}
        for skill_id in set(skill_ids):
            lesson_ids = await self.list_lesson_ids_by_skill(skill_id)
            if lesson_ids:
                result[skill_id] = lesson_ids
        return result

    async def list_content_versions_by_skills(
        self, skill_ids: Sequence[str]
    ) -> dict[str, datetime]:
        return {
            skill_id: FAKE_CONTENT_VERSION
            for skill_id in set(skill_ids)
            if any(lesson.skill_id == skill_id for lesson in self._lessons.values())
        }

    async def list_exercises_by_vocab_item_ids(
        self, vocab_item_ids: Sequence[str]
    ) -> dict[str, Exercise]:
        wanted = set(vocab_item_ids)
        resolved: dict[str, Exercise] = {}
        for lesson in self._lessons.values():
            for exercise in lesson.exercises:
                if exercise.vocab_item_id in wanted and exercise.vocab_item_id not in resolved:
                    resolved[exercise.vocab_item_id] = exercise
        return resolved


class FakeUserSkillProgressRepository:
    """In-memory stand-in for
    `app.domain.lesson.repositories.UserSkillProgressRepository`.
    """

    def __init__(self, progress_rows: list[UserSkillProgress] | None = None) -> None:
        self._rows: dict[tuple[str, str], UserSkillProgress] = {
            (row.user_id, row.skill_id): row for row in (progress_rows or [])
        }

    async def list_by_user(self, user_id: str) -> list[UserSkillProgress]:
        return [row for row in self._rows.values() if row.user_id == user_id]

    async def get(self, user_id: str, skill_id: str) -> UserSkillProgress | None:
        return self._rows.get((user_id, skill_id))

    async def upsert(self, progress: UserSkillProgress) -> None:
        self._rows[(progress.user_id, progress.skill_id)] = progress


class FakeUserBeansRepository:
    """In-memory stand-in for
    `app.domain.lesson.repositories.UserBeansRepository`.
    """

    def __init__(self, beans: list[UserBeans] | None = None) -> None:
        self._rows: dict[str, UserBeans] = {b.user_id: b for b in (beans or [])}

    async def get(self, user_id: str) -> UserBeans | None:
        return self._rows.get(user_id)

    async def upsert(self, beans: UserBeans) -> None:
        self._rows[beans.user_id] = beans


class FakeUserStreakRepository:
    """In-memory stand-in for
    `app.domain.lesson.repositories.UserStreakRepository`.
    """

    def __init__(self, streaks: list[UserStreak] | None = None) -> None:
        self._rows: dict[str, UserStreak] = {s.user_id: s for s in (streaks or [])}

    async def get(self, user_id: str) -> UserStreak | None:
        return self._rows.get(user_id)

    async def upsert(self, streak: UserStreak) -> None:
        self._rows[streak.user_id] = streak


class FakeLessonAttemptRepository:
    """In-memory stand-in for
    `app.domain.lesson.repositories.LessonAttemptRepository`.
    """

    def __init__(self, attempts: list[LessonAttempt] | None = None) -> None:
        self._rows: dict[str, LessonAttempt] = {a.id: a for a in (attempts or [])}
        self.add_calls = 0

    async def get(self, attempt_id: str) -> LessonAttempt | None:
        return self._rows.get(attempt_id)

    async def add(self, attempt: LessonAttempt) -> None:
        self.add_calls += 1
        self._rows[attempt.id] = attempt

    async def sum_xp_by_user(self, user_id: str) -> int:
        return sum(a.xp_awarded for a in self._rows.values() if a.user_id == user_id)

    async def sum_xp_by_user_between(self, user_id: str, start: date, end: date) -> int:
        return sum(
            a.xp_awarded
            for a in self._rows.values()
            if a.user_id == user_id and start <= a.completed_at.date() < end
        )


class FakeAmoleTransactionRepository:
    """In-memory stand-in for
    `app.domain.lesson.repositories.AmoleTransactionRepository` (bolt
    `017-amole-service`). `add_if_new` enforces the same `(source,
    reference_id)` uniqueness the real DB `UNIQUE` constraint would.
    """

    def __init__(self, transactions: list[AmoleTransaction] | None = None) -> None:
        self._rows: dict[tuple[str, str], AmoleTransaction] = {
            (t.source, t.reference_id): t for t in (transactions or [])
        }
        self.add_calls = 0

    async def add_if_new(self, transaction: AmoleTransaction) -> None:
        key = (transaction.source, transaction.reference_id)
        if key in self._rows:
            return
        self.add_calls += 1
        self._rows[key] = transaction

    async def sum_by_user(self, user_id: str) -> int:
        return sum(t.amount for t in self._rows.values() if t.user_id == user_id)


class FakeVocabItemRepository:
    """In-memory stand-in for
    `app.domain.lesson.repositories.VocabItemRepository` (bolt
    `019-srs-tracking-service`).
    """

    def __init__(self, vocab_items: list[VocabItem] | None = None) -> None:
        self._rows: dict[str, VocabItem] = {v.id: v for v in (vocab_items or [])}

    async def get_by_id(self, vocab_item_id: str) -> VocabItem | None:
        return self._rows.get(vocab_item_id)

    async def list_by_ids(self, vocab_item_ids: Sequence[str]) -> list[VocabItem]:
        return [self._rows[vid] for vid in vocab_item_ids if vid in self._rows]


class FakeUserVocabProgressRepository:
    """In-memory stand-in for
    `app.domain.lesson.repositories.UserVocabProgressRepository` (bolt
    `019-srs-tracking-service`).
    """

    def __init__(
        self,
        rows: list[UserVocabProgress] | None = None,
        course_by_vocab_item: dict[str, str] | None = None,
    ) -> None:
        self._rows: dict[tuple[str, str], UserVocabProgress] = {
            (row.user_id, row.vocab_item_id): row for row in (rows or [])
        }
        # Bolt 024: which course each vocab item belongs to, for the
        # course-scoped due queries (unmapped items belong to no course).
        self._course_by_vocab_item = dict(course_by_vocab_item or {})

    def _in_course(self, row: UserVocabProgress, course_id: str | None) -> bool:
        return course_id is None or self._course_by_vocab_item.get(row.vocab_item_id) == course_id

    async def get(self, user_id: str, vocab_item_id: str) -> UserVocabProgress | None:
        return self._rows.get((user_id, vocab_item_id))

    async def upsert(self, progress: UserVocabProgress) -> None:
        self._rows[(progress.user_id, progress.vocab_item_id)] = progress

    async def list_due(
        self, user_id: str, now: datetime, limit: int, course_id: str | None = None
    ) -> list[UserVocabProgress]:
        due = sorted(
            (
                row
                for row in self._rows.values()
                if row.user_id == user_id
                and row.next_review_at <= now
                and self._in_course(row, course_id)
            ),
            key=lambda row: row.next_review_at,
        )
        return due[:limit]

    async def count_due(self, user_id: str, now: datetime, course_id: str | None = None) -> int:
        return sum(
            1
            for row in self._rows.values()
            if row.user_id == user_id
            and row.next_review_at <= now
            and self._in_course(row, course_id)
        )
