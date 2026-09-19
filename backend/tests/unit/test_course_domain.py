"""Unit tests for bolt `024-courses-service`'s pure domain rules (ADR-12,
ADR-13): language pairs, the course selection policy, the one course-
activation path, onboarding pair resolution, and the lesson-course gate.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest

from app.domain.course import CourseSelectionPolicy, CourseStatus, LanguagePair
from app.domain.entities import User
from app.domain.exceptions import CourseNotAvailableError, InvalidPendingSelectionError
from app.domain.lesson.exceptions import LessonCourseUnavailableError
from app.domain.lesson.services import LessonAccessPolicy
from app.domain.services import OnboardingAttachmentPolicy, activate_course_for_user
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
)
from tests.fakes import EN_AM_COURSE_ID, make_course

EN_AM = make_course()
AM_OM = make_course(
    "c-am-om", learning="om", from_language="am", title="Amharic to Afaan Oromo", order_index=2
)
OM_AM = make_course(
    "c-om-am",
    learning="am",
    from_language="om",
    title="Afaan Oromo to Amharic",
    status=CourseStatus.COMING_SOON,
    order_index=3,
)


def _user() -> User:
    return User(
        id=str(uuid.uuid4()),
        provider_identity=ProviderIdentity(AuthProvider.GOOGLE, "sub-1"),
        selected_language=LanguageCode(code="am"),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        notification_enabled=True,
        created_at=datetime.now(UTC),
        active_course_id=EN_AM_COURSE_ID,
    )


class TestLanguagePairAndCourse:
    def test_pair_of_the_same_language_is_rejected(self) -> None:
        with pytest.raises(ValueError):
            LanguagePair(learning="am", from_language="am")

    def test_course_exposes_its_pair_and_availability(self) -> None:
        assert EN_AM.pair == LanguagePair(learning="am", from_language="en")
        assert EN_AM.is_available is True
        assert OM_AM.is_available is False

    def test_all_three_language_codes_are_valid_and_others_are_not(self) -> None:
        for code in ("am", "om", "en"):
            assert LanguageCode(code=code).code == code
        with pytest.raises(InvalidPendingSelectionError):
            LanguageCode(code="fr")


class TestCourseSelectionPolicy:
    def test_only_an_available_course_can_be_activated(self) -> None:
        policy = CourseSelectionPolicy()

        assert policy.can_activate(EN_AM) is True
        assert policy.can_activate(OM_AM) is False
        with pytest.raises(CourseNotAvailableError):
            policy.ensure_activatable(OM_AM)

    def test_resolve_for_pair_finds_only_an_available_course(self) -> None:
        policy = CourseSelectionPolicy()
        courses = [EN_AM, AM_OM, OM_AM]

        assert policy.resolve_for_pair(LanguagePair("om", "am"), courses) == AM_OM
        # om to am exists but is coming soon.
        assert policy.resolve_for_pair(LanguagePair("am", "om"), courses) is None
        assert policy.resolve_for_pair(LanguagePair("en", "am"), courses) is None

    def test_fallback_is_the_first_available_course_by_order(self) -> None:
        policy = CourseSelectionPolicy()

        assert policy.fallback_course([OM_AM, AM_OM, EN_AM]) == EN_AM
        assert policy.fallback_course([OM_AM]) is None


class TestActivateCourseForUser:
    def test_sets_the_active_course_and_mirrors_its_learning_language(self) -> None:
        updated = activate_course_for_user(_user(), AM_OM)

        assert updated.active_course_id == "c-am-om"
        assert updated.selected_language.code == "om"

    def test_leaves_every_other_field_alone(self) -> None:
        user = _user()

        updated = activate_course_for_user(user, AM_OM)

        assert updated.id == user.id
        assert updated.daily_xp_target == user.daily_xp_target
        assert updated.created_at == user.created_at

    def test_a_coming_soon_course_is_rejected_and_the_user_is_unchanged(self) -> None:
        user = _user()

        with pytest.raises(CourseNotAvailableError):
            activate_course_for_user(user, OM_AM)

        assert user.active_course_id == EN_AM_COURSE_ID
        assert user.selected_language.code == "am"


class TestOnboardingPairResolution:
    def test_an_absent_from_language_defaults_to_english(self) -> None:
        course = OnboardingAttachmentPolicy().resolve_course_for_new_user(
            LanguageCode(code="am"), None, [EN_AM, AM_OM]
        )

        assert course == EN_AM

    def test_an_amharic_speaker_can_learn_afaan_oromo(self) -> None:
        course = OnboardingAttachmentPolicy().resolve_course_for_new_user(
            LanguageCode(code="om"), "am", [EN_AM, AM_OM]
        )

        assert course == AM_OM

    def test_the_same_language_twice_is_rejected(self) -> None:
        with pytest.raises(InvalidPendingSelectionError):
            OnboardingAttachmentPolicy().resolve_course_for_new_user(
                LanguageCode(code="am"), "am", [EN_AM]
            )

    def test_a_pair_with_no_available_course_is_rejected(self) -> None:
        policy = OnboardingAttachmentPolicy()

        with pytest.raises(InvalidPendingSelectionError):
            policy.resolve_course_for_new_user(LanguageCode(code="am"), "om", [EN_AM, OM_AM])
        with pytest.raises(InvalidPendingSelectionError):
            policy.resolve_course_for_new_user(LanguageCode(code="en"), None, [EN_AM])

    def test_an_unsupported_from_language_is_rejected(self) -> None:
        with pytest.raises(InvalidPendingSelectionError):
            OnboardingAttachmentPolicy().resolve_course_for_new_user(
                LanguageCode(code="am"), "fr", [EN_AM]
            )


class TestLessonCourseGate:
    def test_an_available_course_passes(self) -> None:
        LessonAccessPolicy().ensure_course_available(EN_AM)

    def test_a_coming_soon_course_is_rejected(self) -> None:
        with pytest.raises(LessonCourseUnavailableError):
            LessonAccessPolicy().ensure_course_available(OM_AM)

    def test_an_unknown_course_is_not_gated(self) -> None:
        LessonAccessPolicy().ensure_course_available(None)
