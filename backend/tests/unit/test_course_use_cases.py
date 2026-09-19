"""Unit tests for bolt `024-courses-service`'s use cases against fake
repositories: the course list, switching the active course, a language change
through `UserPreferencesService`, and signup carrying a language pair.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest

from app.application.course_use_cases import activate_course, list_courses
from app.domain.course import CourseStatus
from app.domain.entities import User
from app.domain.exceptions import (
    CourseNotAvailableError,
    CourseNotFoundError,
    InvalidPendingSelectionError,
    InvalidPreferenceValueError,
)
from app.domain.services import (
    AuthenticationService,
    OnboardingAttachmentPolicy,
    UserPreferencesService,
)
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
)
from tests.fakes import (
    EN_AM_COURSE_ID,
    FakeAuthSessionRepository,
    FakeCourseRepository,
    FakeTokenVerifier,
    FakeUserRepository,
    make_course,
)

EN_AM = make_course()
AM_OM = make_course(
    "c-am-om", learning="om", from_language="am", title="Amharic to Afaan Oromo", order_index=2
)
EN_OM = make_course(
    "c-en-om", learning="om", from_language="en", title="English to Afaan Oromo", order_index=3
)
OM_AM = make_course(
    "c-om-am",
    learning="am",
    from_language="om",
    title="Afaan Oromo to Amharic",
    status=CourseStatus.COMING_SOON,
    order_index=4,
)
ALL_COURSES = [OM_AM, EN_OM, AM_OM, EN_AM]


def _user(active_course_id: str = EN_AM_COURSE_ID, language: str = "am") -> User:
    return User(
        id=str(uuid.uuid4()),
        provider_identity=ProviderIdentity(AuthProvider.GOOGLE, "sub-1"),
        selected_language=LanguageCode(code=language),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        notification_enabled=True,
        created_at=datetime.now(UTC),
        active_course_id=active_course_id,
    )


class TestListCourses:
    async def test_lists_every_course_in_order_with_the_active_one_marked(self) -> None:
        user = _user()
        result = await list_courses(user, FakeCourseRepository(ALL_COURSES))

        assert [s.course.id for s in result.courses] == [
            EN_AM_COURSE_ID,
            "c-am-om",
            "c-en-om",
            "c-om-am",
        ]
        assert result.active_course_id == EN_AM_COURSE_ID
        assert [s.is_active for s in result.courses] == [True, False, False, False]

    async def test_reports_completed_and_total_skills_and_zero_for_empty_courses(self) -> None:
        repo = FakeCourseRepository(
            ALL_COURSES,
            skill_totals={EN_AM_COURSE_ID: 10, "c-am-om": 4},
            completed_skills={EN_AM_COURSE_ID: 3},
        )

        result = await list_courses(_user(), repo)

        by_id = {s.course.id: s for s in result.courses}
        assert (by_id[EN_AM_COURSE_ID].completed_skills, by_id[EN_AM_COURSE_ID].total_skills) == (
            3,
            10,
        )
        assert (by_id["c-am-om"].completed_skills, by_id["c-am-om"].total_skills) == (0, 4)
        assert (by_id["c-om-am"].completed_skills, by_id["c-om-am"].total_skills) == (0, 0)


class TestActivateCourse:
    async def test_switching_persists_the_course_and_the_language_mirror(self) -> None:
        user = _user()
        user_repo = FakeUserRepository([user])

        updated, course = await activate_course(
            user, "c-am-om", FakeCourseRepository(ALL_COURSES), user_repo
        )

        assert course.id == "c-am-om"
        assert updated.active_course_id == "c-am-om"
        assert updated.selected_language.code == "om"
        stored = await user_repo.get_by_id(user.id)
        assert stored is not None and stored.active_course_id == "c-am-om"

    async def test_an_unknown_course_is_not_found_and_nothing_changes(self) -> None:
        user = _user()
        user_repo = FakeUserRepository([user])

        with pytest.raises(CourseNotFoundError):
            await activate_course(user, "nope", FakeCourseRepository(ALL_COURSES), user_repo)

        assert user_repo.update_calls == 0

    async def test_a_coming_soon_course_is_rejected_and_nothing_changes(self) -> None:
        user = _user()
        user_repo = FakeUserRepository([user])

        with pytest.raises(CourseNotAvailableError):
            await activate_course(user, "c-om-am", FakeCourseRepository(ALL_COURSES), user_repo)

        assert user_repo.update_calls == 0
        stored = await user_repo.get_by_id(user.id)
        assert stored is not None and stored.active_course_id == EN_AM_COURSE_ID

    async def test_selecting_the_already_active_course_succeeds_without_a_write(self) -> None:
        user = _user()
        user_repo = FakeUserRepository([user])

        updated, course = await activate_course(
            user, EN_AM_COURSE_ID, FakeCourseRepository(ALL_COURSES), user_repo
        )

        assert updated == user and course.id == EN_AM_COURSE_ID
        assert user_repo.update_calls == 0


class TestLanguageChangeThroughPreferences:
    def _service(self, user: User) -> tuple[UserPreferencesService, FakeUserRepository]:
        repo = FakeUserRepository([user])
        service = UserPreferencesService(
            user_repo=repo,
            onboarding_policy=OnboardingAttachmentPolicy(),
            course_repo=FakeCourseRepository(ALL_COURSES),
        )
        return service, repo

    async def test_a_language_change_activates_the_course_from_the_current_from_language(
        self,
    ) -> None:
        user = _user()
        service, _ = self._service(user)

        updated = await service.update_preferences(user, "om", None, None)

        # The user learns from English, so `om` means English to Afaan Oromo.
        assert updated.active_course_id == "c-en-om"
        assert updated.selected_language.code == "om"

    async def test_the_from_language_follows_the_active_course(self) -> None:
        user = _user(active_course_id="c-am-om", language="om")
        service, _ = self._service(user)

        # From Amharic, learning Amharic is not a course (same language).
        with pytest.raises(InvalidPreferenceValueError):
            await service.update_preferences(user, "am", None, None)

    async def test_a_language_with_no_available_course_is_rejected(self) -> None:
        user = _user()
        service, repo = self._service(user)

        with pytest.raises(InvalidPreferenceValueError):
            await service.update_preferences(user, "en", None, None)

        assert repo.update_calls == 0

    async def test_resubmitting_the_current_language_keeps_the_course(self) -> None:
        user = _user()
        service, _ = self._service(user)

        updated = await service.update_preferences(user, "am", 15, None)

        assert updated.active_course_id == EN_AM_COURSE_ID
        assert updated.daily_xp_target.xp_per_day == 60


class TestSignupWithLanguagePair:
    def _service(self) -> tuple[AuthenticationService, FakeUserRepository]:
        user_repo = FakeUserRepository()
        service = AuthenticationService(
            google_verifier=FakeTokenVerifier(subject="g-1"),
            apple_verifier=FakeTokenVerifier(),
            user_repo=user_repo,
            session_repo=FakeAuthSessionRepository(),
            onboarding_policy=OnboardingAttachmentPolicy(),
            course_repo=FakeCourseRepository(ALL_COURSES),
        )
        return service, user_repo

    async def test_an_amharic_speaker_signing_up_to_learn_afaan_oromo_gets_that_course(
        self,
    ) -> None:
        service, _ = self._service()

        result = await service.authenticate_with_google("t", "om", 10, "am")

        assert result.user.active_course_id == "c-am-om"
        assert result.user.selected_language.code == "om"

    async def test_no_from_language_means_english(self) -> None:
        service, _ = self._service()

        result = await service.authenticate_with_google("t", "om", 10)

        assert result.user.active_course_id == "c-en-om"

    async def test_no_pending_selection_starts_english_to_amharic(self) -> None:
        service, _ = self._service()

        result = await service.authenticate_with_google("t", None, None)

        assert result.user.active_course_id == EN_AM_COURSE_ID

    async def test_an_unresolvable_pair_rejects_signup_and_creates_no_user(self) -> None:
        service, user_repo = self._service()

        # Afaan Oromo to Amharic exists but is coming soon.
        with pytest.raises(InvalidPendingSelectionError):
            await service.authenticate_with_google("t", "am", 10, "om")

        assert await user_repo.find_by_provider_identity(AuthProvider.GOOGLE, "g-1") is None
