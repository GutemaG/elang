"""Application layer: one use case per lesson-content operation.

Orchestrates domain services + repositories. No direct SQLAlchemy or HTTP
imports -- callers (the FastAPI routers) are responsible for request/
response mapping.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, replace
from datetime import UTC, datetime, timedelta

from app.domain.course import Course, CourseRepository
from app.domain.lesson.entities import (
    AmoleTransaction,
    Category,
    Exercise,
    Lesson,
    LessonAttempt,
    PracticeAttempt,
    UserBeans,
    UserSkillProgress,
    UserStreak,
    UserVocabProgress,
)
from app.domain.lesson.exceptions import (
    InsufficientAmoleError,
    InvalidCompletionError,
    InvalidPracticeCompletionError,
    LessonNotFoundError,
)
from app.domain.lesson.repositories import (
    AmoleTransactionRepository,
    CategoryRepository,
    LessonAttemptRepository,
    LessonRepository,
    PracticeAttemptRepository,
    SkillRepository,
    UserBeansRepository,
    UserSkillProgressRepository,
    UserStreakRepository,
    UserVocabProgressRepository,
    VocabItemRepository,
)
from app.domain.lesson.services import (
    AmoleAwardPolicy,
    BeanLedger,
    CompletionTimestampValidator,
    LeitnerBoxPolicy,
    LessonAccessPolicy,
    LessonCompletionService,
    SkillTreeEntry,
    SkillTreeProgressionPolicy,
)
from app.domain.lesson.value_objects import (
    AMOLE_PRACTICE_SESSION_AWARD,
    BEANS_MAX,
    LEITNER_BOX_INTERVALS,
    MIN_BOX_LEVEL,
    REFILL_COST_AMOLE,
    STARTING_AMOLE_BALANCE,
    XP_PER_CORRECT_ANSWER,
    AmoleSource,
    LessonCompletionOutcome,
)

# Bolt 008: stable fallback `content_version` for a skill with zero lessons
# (shouldn't happen with real content, mirrors the existing `lesson_id_by_skill`
# `None` fallback) -- fixed and comparable, never "now" (which would make the
# signal unstable across repeated fetches).
_NO_CONTENT_VERSION = datetime(1970, 1, 1, tzinfo=UTC)


def _default_beans(user_id: str, now: datetime) -> UserBeans:
    return UserBeans(user_id=user_id, current_count=BEANS_MAX, last_regen_at=now)


async def _ensure_amole_wallet(
    user_id: str, amole_repo: AmoleTransactionRepository, now: datetime
) -> None:
    """Bolt 017: lazily grants the one-time `STARTING_AMOLE_BALANCE`, the
    same "absence is meaningful, materialized on first real access" laziness
    `_default_beans` used to provide for Amole before ADR-8 split it out of
    `UserBeans`. Idempotent via `add_if_new` -- safe to call on every
    balance read/spend-validation, not just once.
    """
    await amole_repo.add_if_new(
        AmoleTransaction(
            id=str(uuid.uuid4()),
            user_id=user_id,
            amount=STARTING_AMOLE_BALANCE,
            source=AmoleSource.WALLET_CREATED,
            reference_id=user_id,
            created_at=now,
        )
    )


async def get_amole_balance(
    user_id: str, amole_repo: AmoleTransactionRepository, now: datetime
) -> int:
    """Bolt 017: the account's Amole balance -- always `SUM(amount)`
    (ADR-8), never a cached column.
    """
    await _ensure_amole_wallet(user_id, amole_repo, now)
    return await amole_repo.sum_by_user(user_id)


def _default_streak(user_id: str) -> UserStreak:
    return UserStreak(
        user_id=user_id, current_streak=0, last_completed_date=None, active_freeze_count=0
    )


def _default_progress(user_id: str, skill_id: str) -> UserSkillProgress:
    return UserSkillProgress(
        user_id=user_id, skill_id=skill_id, unlocked=True, crown_level=0, completed_at=None
    )


async def _apply_vocab_progress_update(
    *,
    user_id: str,
    vocab_item_id: str,
    was_correct: bool,
    now: datetime,
    vocab_progress_repo: UserVocabProgressRepository,
) -> None:
    """Bolt 019/020: the one place `UserVocabProgress` is ever written --
    shared by `complete_lesson` (per vocab-linked exercise in the lesson)
    and `complete_practice_session` (per graded result), so the two call
    sites can't drift apart on first-appearance/box-transition semantics.
    """
    existing = await vocab_progress_repo.get(user_id, vocab_item_id)
    if existing is None:
        new_progress = UserVocabProgress(
            user_id=user_id,
            vocab_item_id=vocab_item_id,
            box_level=MIN_BOX_LEVEL,
            next_review_at=now + LEITNER_BOX_INTERVALS[MIN_BOX_LEVEL],
            last_seen_at=now,
        )
    else:
        new_box_level, next_review_at = LeitnerBoxPolicy().apply(
            existing.box_level, was_correct, now
        )
        new_progress = replace(
            existing, box_level=new_box_level, next_review_at=next_review_at, last_seen_at=now
        )
    await vocab_progress_repo.upsert(new_progress)


@dataclass(frozen=True)
class SkillTreeSummary:
    """Story 001's skill entries plus bolt 005's account-level HUD stats --
    everything `GET /skill-tree` returns in one call (Technical Design's
    extended response).
    """

    entries: list[SkillTreeEntry]
    lesson_id_by_skill: dict[str, str | None]
    content_version_by_skill: dict[str, datetime]
    categories: list[Category]
    # Bolt 024 (ADR-12): the course this tree belongs to; `None` only when the
    # tree was read unscoped (unit tests), never from the HTTP router.
    course: Course | None
    # Deprecated (ADR-11): derived from the first category, kept only so a
    # client that still reads `unit_title`/`unit_subtitle` keeps working.
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
    category_repo: CategoryRepository,
    now: datetime,
    course_repo: CourseRepository | None = None,
    active_course_id: str | None = None,
) -> SkillTreeSummary:
    """Story 001: the skill tree, with accurate per-skill state/crown level
    for `user_id` -- including a brand-new user with zero progress rows
    (bootstrap handled entirely by `SkillTreeProgressionPolicy`). Extended
    (bolt 005) with the account's streak/beans/lifetime-XP HUD stats, and
    (bolt 007) with each skill's "next lesson to work on" id, all in this
    same single request.

    Bolt 024 (ADR-12): when `active_course_id` is given, only that course's
    categories and skills are returned (the HTTP router always passes it);
    progression is unchanged because it is already per category.
    """
    course: Course | None = None
    if active_course_id is not None:
        categories = await category_repo.list_by_course(active_course_id)
        if course_repo is not None:
            course = await course_repo.get_by_id(active_course_id)
    else:
        categories = await category_repo.list_all()
    category_rank = {c.id: rank for rank, c in enumerate(categories)}
    all_skills = await skill_repo.list_all()
    if active_course_id is not None:
        all_skills = [s for s in all_skills if s.category_id in category_rank]
    # Categories in their own order, then each category's skills; the
    # policy keeps that grouping (ADR-11). Skills whose category isn't
    # listed sort last rather than being dropped.
    skills = sorted(
        all_skills,
        key=lambda s: (category_rank.get(s.category_id, len(categories)), s.order_index),
    )
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
        categories=categories,
        course=course,
        unit_title=categories[0].title if categories else "",
        unit_subtitle=categories[0].subtitle if categories else "",
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
    course_repo: CourseRepository | None = None,
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

    # Bolt 024 (ADR-12): the lesson's own course must be available (not the
    # user's active course); the HTTP router always passes `course_repo`.
    if course_repo is not None:
        LessonAccessPolicy().ensure_course_available(
            await course_repo.get_for_skill(lesson.skill_id)
        )

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
    user_id: str,
    beans_repo: UserBeansRepository,
    amole_repo: AmoleTransactionRepository,
    now: datetime,
) -> BeansStatusResult:
    """The account's current beans/refill state (regenerated as of `now`),
    for the out-of-beans modal and dashboard HUD. Beans side is
    read-only -- never writes a row, same "absence is meaningful"
    convention as `get_skill_tree`. Amole side (bolt 017) may lazily grant
    the one-time starting balance on first-ever access (`_ensure_amole_wallet`),
    which is itself idempotent, not a repeated grant.
    """
    beans = await beans_repo.get(user_id) or _default_beans(user_id, now)
    ledger = BeanLedger()
    regenerated = ledger.regenerate(beans, now)
    amole_balance = await get_amole_balance(user_id, amole_repo, now)
    return BeansStatusResult(
        beans=regenerated.current_count,
        beans_max=BEANS_MAX,
        next_bean_at=ledger.next_bean_at(regenerated),
        amole_balance=amole_balance,
        refill_cost_amole=REFILL_COST_AMOLE,
    )


@dataclass(frozen=True)
class RefillResult:
    beans: int
    amole_balance: int


async def refill_beans(
    user_id: str,
    beans_repo: UserBeansRepository,
    amole_repo: AmoleTransactionRepository,
    now: datetime,
) -> RefillResult:
    """Story 003: an immediate Beans refill using the account's Amole
    balance. Raises `InsufficientAmoleError` (422) if the balance can't
    cover `REFILL_COST_AMOLE`.

    Bolt 017 (ADR-9): the posted `bean_refill` ledger row uses a fresh
    reference per call, matching this endpoint's pre-existing (and
    unchanged) lack of retry protection -- a retried refill request can
    still double-spend today, exactly as it could before this bolt.
    """
    beans = await beans_repo.get(user_id) or _default_beans(user_id, now)
    ledger = BeanLedger()
    regenerated = ledger.regenerate(beans, now)
    balance = await get_amole_balance(user_id, amole_repo, now)
    if balance < REFILL_COST_AMOLE:
        raise InsufficientAmoleError(
            f"Refill costs {REFILL_COST_AMOLE} Amole; account has {balance}"
        )
    refilled = ledger.refill(regenerated, now)
    await beans_repo.upsert(refilled)
    await amole_repo.add_if_new(
        AmoleTransaction(
            id=str(uuid.uuid4()),
            user_id=user_id,
            amount=-REFILL_COST_AMOLE,
            source=AmoleSource.BEAN_REFILL,
            reference_id=str(uuid.uuid4()),
            created_at=now,
        )
    )
    new_balance = await amole_repo.sum_by_user(user_id)
    return RefillResult(beans=refilled.current_count, amole_balance=new_balance)


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
    amole_repo: AmoleTransactionRepository,
    vocab_progress_repo: UserVocabProgressRepository,
    now: datetime,
    missed_exercise_ids: frozenset[str] = frozenset(),
    course_repo: CourseRepository | None = None,
) -> LessonCompletionOutcome:
    """Stories 002/003/004: the account-ledger side of one completed lesson
    attempt. Grading itself already happened client-side (ADR-5) -- this
    orchestrates Beans consumption (bounded by ADR-5's Decision 1), XP
    award, skill-progress/crown-level update, and streak update, all in one
    transaction, idempotent on `attempt_id` (story 003).

    Bolt 017 (intent 007-amole-currency): also awards Amole (flat
    completion amount, perfect-lesson bonus, 7-/30-day streak-milestone
    bonus), all keyed to this same `attempt_id` as their ledger
    `reference_id` (ADR-8) -- the top-level idempotency check below is the
    primary guard against a retried request re-awarding; the ledger's own
    `(source, reference_id)` uniqueness is a backstop, not the only guard.

    Bolt 008 (`003-offline-caching-and-sync`): `client_completed_at` is the
    moment the user actually completed the lesson (identical to `now` for
    an online completion; earlier for one synced after an offline gap) --
    it drives streak/XP-day attribution and the persisted attempt's
    `completed_at`, while `now` (real server time) still drives Beans
    regeneration, which must reflect real elapsed time regardless of when
    the completion is attributed to. The idempotency check happens before
    timestamp validation so an already-accepted attempt is never rejected
    on retry, no matter what the validator's bounds are.

    Bolt 019 (`008-srs-and-practice`, ADR-10): also updates
    `UserVocabProgress` for every vocab-linked exercise in this lesson --
    first appearance creates a row at box 1; a repeat appearance advances or
    resets it via `LeitnerBoxPolicy`, using `missed_exercise_ids` (an
    exercise id is in this set if it was ever answered wrong before
    eventually being answered correctly, per the client's retry-until-correct
    design) to decide which. Sits inside this same idempotency boundary, so
    a replayed offline-sync completion never double-updates vocab progress.
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

    # Bolt 024 (ADR-12): gated on the lesson's own course, so a completion
    # queued offline before a course switch still syncs (ADR-6).
    if course_repo is not None:
        LessonAccessPolicy().ensure_course_available(
            await course_repo.get_for_skill(lesson.skill_id)
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

    awards = AmoleAwardPolicy().awards_for_completion(
        correct_count=correct_count,
        total_count=total_count,
        previous_streak=streak.current_streak,
        new_streak=completion.streak.current_streak,
    )
    for award in awards:
        await amole_repo.add_if_new(
            AmoleTransaction(
                id=str(uuid.uuid4()),
                user_id=user_id,
                amount=award.amount,
                source=award.source,
                reference_id=attempt_id,
                created_at=client_completed_at,
            )
        )

    for exercise in lesson.exercises:
        if exercise.vocab_item_id is None:
            continue
        await _apply_vocab_progress_update(
            user_id=user_id,
            vocab_item_id=exercise.vocab_item_id,
            was_correct=exercise.id not in missed_exercise_ids,
            now=client_completed_at,
            vocab_progress_repo=vocab_progress_repo,
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


@dataclass(frozen=True)
class DueItem:
    """One due vocab item plus the full exercise that tests it (bolt
    `019-srs-tracking-service`/`020-practice-ui`, story
    `004-due-items-and-count-endpoints`). Never persisted -- assembled
    fresh per request from `UserVocabProgress` + `VocabItem` + the
    resolved `Exercise`.

    Carries the full `Exercise` (not just its id) since bolt 020 found
    `GET /lessons/{lesson_id}` can't be used to fetch it separately -- that
    endpoint's `LessonAccessPolicy` check would 403 a locked skill's
    lesson, which Practice must not be blocked by.
    """

    vocab_item_id: str
    word: str
    translation: str
    exercise: Exercise
    box_level: int
    next_review_at: datetime


DEFAULT_DUE_ITEMS_LIMIT = 20


async def get_due_items(
    user_id: str,
    vocab_progress_repo: UserVocabProgressRepository,
    vocab_item_repo: VocabItemRepository,
    lesson_repo: LessonRepository,
    now: datetime,
    limit: int = DEFAULT_DUE_ITEMS_LIMIT,
    course_id: str | None = None,
) -> list[DueItem]:
    """Story 004: every vocab item due for `user_id` right now, each
    resolved to its word/translation and one exercise that tests it, ready
    for Practice session assembly (bolt 020). A due item whose vocab
    content or linked exercise has since disappeared (shouldn't happen with
    real content) is silently omitted rather than raising. Bolt 024
    (ADR-12): `course_id` limits it to the active course's words.
    """
    due_rows = await vocab_progress_repo.list_due(user_id, now, limit, course_id)
    if not due_rows:
        return []

    vocab_item_ids = [row.vocab_item_id for row in due_rows]
    vocab_items = await vocab_item_repo.list_by_ids(vocab_item_ids)
    vocab_items_by_id = {item.id: item for item in vocab_items}
    exercise_by_vocab_item = await lesson_repo.list_exercises_by_vocab_item_ids(vocab_item_ids)

    items: list[DueItem] = []
    for row in due_rows:
        vocab_item = vocab_items_by_id.get(row.vocab_item_id)
        exercise = exercise_by_vocab_item.get(row.vocab_item_id)
        if vocab_item is None or exercise is None:
            continue
        items.append(
            DueItem(
                vocab_item_id=row.vocab_item_id,
                word=vocab_item.word,
                translation=vocab_item.translation,
                exercise=exercise,
                box_level=row.box_level,
                next_review_at=row.next_review_at,
            )
        )
    return items


async def get_due_count(
    user_id: str,
    vocab_progress_repo: UserVocabProgressRepository,
    now: datetime,
    course_id: str | None = None,
) -> int:
    """Story 004: the Practice entry point's due-count badge. Shares
    `UserVocabProgressRepository`'s predicate with `get_due_items` (via the
    repository's own `count_due`/`list_due` implementations), so the two
    can never disagree.
    """
    return await vocab_progress_repo.count_due(user_id, now, course_id)


@dataclass(frozen=True)
class PracticeSessionCompletionResult:
    xp_earned: int
    amole_earned: int
    correct_count: int
    total_count: int
    accuracy_percent: int


async def complete_practice_session(
    *,
    user_id: str,
    session_id: str,
    results: list[tuple[str, bool]],
    now: datetime,
    vocab_progress_repo: UserVocabProgressRepository,
    amole_repo: AmoleTransactionRepository,
    practice_attempt_repo: PracticeAttemptRepository,
) -> PracticeSessionCompletionResult:
    """Story 002 (bolt `020-practice-ui`): the account-ledger side of one
    completed Practice session -- `results` is `(vocab_item_id, correct)`
    per graded item. Idempotent on `session_id`, same convention as
    `complete_lesson`'s `attempt_id`.

    Deliberately does not touch `UserStreak` or `UserSkillProgress` --
    Practice is independent of skill-tree/streak progression (user
    decision, this bolt's Plan stage). `complete_lesson` could not be
    reused for this at all: a Practice session spans arbitrary lessons/
    skills (no single `lesson_id`) and must work even for a locked skill's
    item, which `LessonAccessPolicy` would otherwise block.
    """
    existing = await practice_attempt_repo.get(session_id)
    if existing is not None:
        total = existing.total_count
        accuracy = round((existing.correct_count / total) * 100) if total > 0 else 0
        return PracticeSessionCompletionResult(
            xp_earned=existing.xp_awarded,
            amole_earned=existing.amole_awarded,
            correct_count=existing.correct_count,
            total_count=existing.total_count,
            accuracy_percent=accuracy,
        )

    total_count = len(results)
    correct_count = sum(1 for _, correct in results if correct)
    if total_count == 0:
        raise InvalidPracticeCompletionError("A practice session must grade at least one item")

    for vocab_item_id, correct in results:
        await _apply_vocab_progress_update(
            user_id=user_id,
            vocab_item_id=vocab_item_id,
            was_correct=correct,
            now=now,
            vocab_progress_repo=vocab_progress_repo,
        )

    xp_awarded = correct_count * XP_PER_CORRECT_ANSWER
    amole_awarded = AMOLE_PRACTICE_SESSION_AWARD
    await amole_repo.add_if_new(
        AmoleTransaction(
            id=str(uuid.uuid4()),
            user_id=user_id,
            amount=amole_awarded,
            source=AmoleSource.PRACTICE_SESSION,
            reference_id=session_id,
            created_at=now,
        )
    )
    await practice_attempt_repo.add(
        PracticeAttempt(
            id=session_id,
            user_id=user_id,
            correct_count=correct_count,
            total_count=total_count,
            xp_awarded=xp_awarded,
            amole_awarded=amole_awarded,
            completed_at=now,
        )
    )

    return PracticeSessionCompletionResult(
        xp_earned=xp_awarded,
        amole_earned=amole_awarded,
        correct_count=correct_count,
        total_count=total_count,
        accuracy_percent=round((correct_count / total_count) * 100),
    )
