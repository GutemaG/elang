"""Application layer: one use case per lesson-content operation.

Orchestrates domain services + repositories. No direct SQLAlchemy or HTTP
imports -- callers (the FastAPI routers) are responsible for request/
response mapping.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import UTC, datetime, timedelta

from app.domain.lesson.entities import (
    Lesson,
    LessonAttempt,
    UserBeans,
    UserSkillProgress,
    UserStreak,
)
from app.domain.lesson.exceptions import (
    InsufficientAmoleError,
    InvalidCompletionError,
    LessonNotFoundError,
)
from app.domain.lesson.repositories import (
    LessonAttemptRepository,
    LessonRepository,
    SkillRepository,
    UserBeansRepository,
    UserSkillProgressRepository,
    UserStreakRepository,
)
from app.domain.lesson.services import (
    BeanLedger,
    CompletionTimestampValidator,
    LessonAccessPolicy,
    LessonCompletionService,
    SkillTreeEntry,
    SkillTreeProgressionPolicy,
)
from app.domain.lesson.value_objects import (
    BEANS_MAX,
    REFILL_COST_AMOLE,
    STARTING_AMOLE_BALANCE,
    LessonCompletionOutcome,
)

# Fixed banner (Technical Design Decision 4) -- identical text to the
# already-built `FakeLessonApi`'s hardcoded value, so bolt 007's swap to
# the real backend changes nothing visible. Revisit if a real multi-unit
# curriculum structure is ever scoped.
UNIT_TITLE = "Unit 1: Foundations & Greetings"
UNIT_SUBTITLE = "ሰላምታ እና ፊደል መግቢያ"

# Bolt 008: stable fallback `content_version` for a skill with zero lessons
# (shouldn't happen with real content, mirrors the existing `lesson_id_by_skill`
# `None` fallback) -- fixed and comparable, never "now" (which would make the
# signal unstable across repeated fetches).
_NO_CONTENT_VERSION = datetime(1970, 1, 1, tzinfo=UTC)


def _default_beans(user_id: str, now: datetime) -> UserBeans:
    return UserBeans(
        user_id=user_id,
        current_count=BEANS_MAX,
        last_regen_at=now,
        amole_balance=STARTING_AMOLE_BALANCE,
    )


def _default_streak(user_id: str) -> UserStreak:
    return UserStreak(
        user_id=user_id, current_streak=0, last_completed_date=None, active_freeze_count=0
    )


def _default_progress(user_id: str, skill_id: str) -> UserSkillProgress:
    return UserSkillProgress(
        user_id=user_id, skill_id=skill_id, unlocked=True, crown_level=0, completed_at=None
    )


@dataclass(frozen=True)
class SkillTreeSummary:
    """Story 001's skill entries plus bolt 005's account-level HUD stats --
    everything `GET /skill-tree` returns in one call (Technical Design's
    extended response).
    """

    entries: list[SkillTreeEntry]
    lesson_id_by_skill: dict[str, str | None]
    content_version_by_skill: dict[str, datetime]
    unit_title: str
    unit_subtitle: str
    streak_count: int
    beans: int
    beans_max: int
    total_xp: int


async def get_skill_tree(
    user_id: str,
    skill_repo: SkillRepository,
    progress_repo: UserSkillProgressRepository,
    beans_repo: UserBeansRepository,
    streak_repo: UserStreakRepository,
    attempt_repo: LessonAttemptRepository,
    lesson_repo: LessonRepository,
    now: datetime,
) -> SkillTreeSummary:
    """Story 001: the skill tree, with accurate per-skill state/crown level
    for `user_id` -- including a brand-new user with zero progress rows
    (bootstrap handled entirely by `SkillTreeProgressionPolicy`). Extended
    (bolt 005) with the account's streak/beans/lifetime-XP HUD stats, and
    (bolt 007) with each skill's "next lesson to work on" id, all in this
    same single request.
    """
    skills = await skill_repo.list_all()
    progress_rows = await progress_repo.list_by_user(user_id)
    entries = SkillTreeProgressionPolicy().compute_states(skills, progress_rows)
    progress_by_skill = {p.skill_id: p for p in progress_rows}

    beans = await beans_repo.get(user_id) or _default_beans(user_id, now)
    regenerated_beans = BeanLedger().regenerate(beans, now)
    streak = await streak_repo.get(user_id) or _default_streak(user_id)
    total_xp = await attempt_repo.sum_xp_by_user(user_id)

    # bolt 007: the skill-tree UI needs a concrete lesson to navigate to
    # when a node is tapped, but a skill can have multiple lessons with no
    # server-side "current lesson" ordering concept (only a cycle-completion
    # *set* -- see LessonCompletionService). One grouped query for every
    # skill's lesson ids (not a per-skill round trip) keeps this at the
    # same small constant query count as the rest of get_skill_tree.
    lessons_by_skill = await lesson_repo.list_lesson_ids_by_skills([s.id for s in skills])
    lesson_id_by_skill: dict[str, str | None] = {}
    for skill in skills:
        lesson_ids = lessons_by_skill.get(skill.id, ())
        if not lesson_ids:
            lesson_id_by_skill[skill.id] = None
            continue
        progress = progress_by_skill.get(skill.id)
        done_this_cycle = progress.completed_lesson_ids_this_cycle if progress else frozenset()
        lesson_id_by_skill[skill.id] = next(
            (lid for lid in lesson_ids if lid not in done_this_cycle), lesson_ids[0]
        )

    # Bolt 008: the offline-caching client's staleness check (FR-1 of
    # 003-offline-caching-and-sync) -- one grouped query, not a per-skill
    # round trip, same discipline as `lessons_by_skill` above.
    content_versions = await lesson_repo.list_content_versions_by_skills([s.id for s in skills])
    content_version_by_skill = {
        skill.id: content_versions.get(skill.id, _NO_CONTENT_VERSION) for skill in skills
    }

    return SkillTreeSummary(
        entries=entries,
        lesson_id_by_skill=lesson_id_by_skill,
        content_version_by_skill=content_version_by_skill,
        unit_title=UNIT_TITLE,
        unit_subtitle=UNIT_SUBTITLE,
        streak_count=streak.current_streak,
        beans=regenerated_beans.current_count,
        beans_max=BEANS_MAX,
        total_xp=total_xp,
    )


@dataclass(frozen=True)
class LessonContentResult:
    """`Lesson` plus bolt 008's `content_version` signal -- kept as a
    separate wrapper (same pattern as `SkillTreeSummary`) rather than a
    field on the `Lesson` entity itself, since the version is a derived
    signal for the offline-caching client, not a property of the aggregate.
    """

    lesson: Lesson
    content_version: datetime


async def get_lesson_content(
    user_id: str,
    lesson_id: str,
    lesson_repo: LessonRepository,
    skill_repo: SkillRepository,
    progress_repo: UserSkillProgressRepository,
) -> LessonContentResult:
    """Story 001: a lesson's full, ordered exercise list in one call.

    Raises `LessonNotFoundError` (404) for an unknown lesson id, or
    `SkillLockedError` (403, from `LessonAccessPolicy`) if the lesson's
    owning skill is locked for this user -- enforced here, not just
    optimistically in the router, so a locked skill's lesson is unreachable
    even by direct lesson ID (story 001's edge case).
    """
    lesson = await lesson_repo.get_by_id(lesson_id)
    if lesson is None:
        raise LessonNotFoundError(f"No lesson found with id {lesson_id!r}")

    skills = await skill_repo.list_all()
    progress_rows = await progress_repo.list_by_user(user_id)
    skill_state = SkillTreeProgressionPolicy().state_for_skill(
        lesson.skill_id, skills, progress_rows
    )
    LessonAccessPolicy().ensure_accessible(skill_state)

    # Bolt 008: the offline-caching client's per-lesson staleness check
    # (FR-1 of 003-offline-caching-and-sync).
    content_version = await lesson_repo.get_content_version(lesson_id) or _NO_CONTENT_VERSION

    return LessonContentResult(lesson=lesson, content_version=content_version)


@dataclass(frozen=True)
class BeansStatusResult:
    beans: int
    beans_max: int
    next_bean_at: datetime | None
    amole_balance: int
    refill_cost_amole: int


async def get_beans_status(
    user_id: str, beans_repo: UserBeansRepository, now: datetime
) -> BeansStatusResult:
    """The account's current beans/refill state (regenerated as of `now`),
    for the out-of-beans modal and dashboard HUD. Read-only -- never
    writes a row, same "absence is meaningful" convention as
    `get_skill_tree`.
    """
    beans = await beans_repo.get(user_id) or _default_beans(user_id, now)
    ledger = BeanLedger()
    regenerated = ledger.regenerate(beans, now)
    return BeansStatusResult(
        beans=regenerated.current_count,
        beans_max=BEANS_MAX,
        next_bean_at=ledger.next_bean_at(regenerated),
        amole_balance=regenerated.amole_balance,
        refill_cost_amole=REFILL_COST_AMOLE,
    )


@dataclass(frozen=True)
class RefillResult:
    beans: int
    amole_balance: int


async def refill_beans(
    user_id: str, beans_repo: UserBeansRepository, now: datetime
) -> RefillResult:
    """Story 003: an immediate Beans refill using the account's Amole
    balance. Raises `InsufficientAmoleError` (422) if the balance can't
    cover `REFILL_COST_AMOLE`.
    """
    beans = await beans_repo.get(user_id) or _default_beans(user_id, now)
    ledger = BeanLedger()
    regenerated = ledger.regenerate(beans, now)
    if regenerated.amole_balance < REFILL_COST_AMOLE:
        raise InsufficientAmoleError(
            f"Refill costs {REFILL_COST_AMOLE} Amole; account has {regenerated.amole_balance}"
        )
    refilled = ledger.refill(regenerated, now)
    refilled = replace(refilled, amole_balance=refilled.amole_balance - REFILL_COST_AMOLE)
    await beans_repo.upsert(refilled)
    return RefillResult(beans=refilled.current_count, amole_balance=refilled.amole_balance)


async def complete_lesson(
    *,
    user_id: str,
    lesson_id: str,
    attempt_id: str,
    correct_count: int,
    total_count: int,
    time_spent_seconds: float,
    daily_xp_target: int,
    client_completed_at: datetime,
    account_created_at: datetime,
    lesson_repo: LessonRepository,
    skill_repo: SkillRepository,
    progress_repo: UserSkillProgressRepository,
    beans_repo: UserBeansRepository,
    streak_repo: UserStreakRepository,
    attempt_repo: LessonAttemptRepository,
    now: datetime,
) -> LessonCompletionOutcome:
    """Stories 002/003/004: the account-ledger side of one completed lesson
    attempt. Grading itself already happened client-side (ADR-5) -- this
    orchestrates Beans consumption (bounded by ADR-5's Decision 1), XP
    award, skill-progress/crown-level update, and streak update, all in one
    transaction, idempotent on `attempt_id` (story 003).

    Bolt 008 (`003-offline-caching-and-sync`): `client_completed_at` is the
    moment the user actually completed the lesson (identical to `now` for
    an online completion; earlier for one synced after an offline gap) --
    it drives streak/XP-day attribution and the persisted attempt's
    `completed_at`, while `now` (real server time) still drives Beans
    regeneration, which must reflect real elapsed time regardless of when
    the completion is attributed to. The idempotency check happens before
    timestamp validation so an already-accepted attempt is never rejected
    on retry, no matter what the validator's bounds are.
    """
    existing = await attempt_repo.get(attempt_id)
    if existing is not None:
        return existing.outcome

    CompletionTimestampValidator().validate(client_completed_at, account_created_at, now)

    lesson = await lesson_repo.get_by_id(lesson_id)
    if lesson is None:
        raise LessonNotFoundError(f"No lesson found with id {lesson_id!r}")
    if total_count != len(lesson.exercises):
        raise InvalidCompletionError(
            f"total_count={total_count} does not match the lesson's "
            f"{len(lesson.exercises)} exercises"
        )

    skills = await skill_repo.list_all()
    progress_rows = await progress_repo.list_by_user(user_id)
    skill_state = SkillTreeProgressionPolicy().state_for_skill(
        lesson.skill_id, skills, progress_rows
    )
    LessonAccessPolicy().ensure_accessible(skill_state)

    beans = await beans_repo.get(user_id) or _default_beans(user_id, now)
    wrong_count = total_count - correct_count
    new_beans = BeanLedger().consume(beans, wrong_count, now)

    progress = await progress_repo.get(user_id, lesson.skill_id) or _default_progress(
        user_id, lesson.skill_id
    )
    streak = await streak_repo.get(user_id) or _default_streak(user_id)
    skill_lesson_ids = frozenset(await lesson_repo.list_lesson_ids_by_skill(lesson.skill_id))

    completion_date = client_completed_at.date()
    daily_xp_total_before = await attempt_repo.sum_xp_by_user_between(
        user_id, completion_date, completion_date + timedelta(days=1)
    )

    completion = LessonCompletionService().complete(
        lesson_id=lesson_id,
        skill_lesson_ids=skill_lesson_ids,
        all_skills=skills,
        progress=progress,
        streak=streak,
        correct_count=correct_count,
        total_count=total_count,
        time_spent_seconds=time_spent_seconds,
        daily_xp_total_before=daily_xp_total_before,
        daily_xp_target=daily_xp_target,
        now=client_completed_at,
        completion_date=completion_date,
    )

    await beans_repo.upsert(new_beans)
    await progress_repo.upsert(completion.progress)
    if completion.unlocked_progress is not None:
        await progress_repo.upsert(completion.unlocked_progress)
    await streak_repo.upsert(completion.streak)
    await attempt_repo.add(
        LessonAttempt(
            id=attempt_id,
            user_id=user_id,
            lesson_id=lesson_id,
            correct_count=correct_count,
            total_count=total_count,
            xp_awarded=completion.outcome.xp_awarded,
            completed_at=client_completed_at,
            outcome=completion.outcome,
        )
    )

    return completion.outcome
