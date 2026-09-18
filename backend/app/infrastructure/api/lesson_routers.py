"""FastAPI routers: `GET /api/v1/skill-tree`, `GET /api/v1/lessons/{lesson_id}`.

Parses/validates the HTTP request (via the shared `get_current_user`
dependency for session auth), calls the relevant application use case, and
maps the result to the HTTP response shapes in this bolt's
`ddd-02-technical-design.md`. No business logic lives here.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends

from app.application.lesson_use_cases import (
    LessonContentResult,
    SkillTreeSummary,
    complete_lesson,
    get_beans_status,
    get_lesson_content,
    get_skill_tree,
    refill_beans,
)
from app.domain.entities import User
from app.domain.lesson.repositories import (
    AmoleTransactionRepository,
    LessonAttemptRepository,
    LessonRepository,
    SkillRepository,
    UserBeansRepository,
    UserSkillProgressRepository,
    UserStreakRepository,
    UserVocabProgressRepository,
)
from app.domain.lesson.value_objects import BEAN_REGEN_MINUTES
from app.infrastructure.api.dependencies import get_current_user
from app.infrastructure.api.exercise_mapping import to_exercise_response
from app.infrastructure.api.lesson_dependencies import (
    get_amole_transaction_repository,
    get_lesson_attempt_repository,
    get_lesson_repository,
    get_skill_repository,
    get_user_beans_repository,
    get_user_skill_progress_repository,
    get_user_streak_repository,
    get_user_vocab_progress_repository,
)
from app.infrastructure.api.lesson_schemas import (
    BeansStatusResponse,
    CompleteLessonRequest,
    CompleteLessonResponse,
    LessonContentResponse,
    LessonSummaryResponse,
    RefillResponse,
    SkillTreeEntryResponse,
    SkillTreeResponse,
)

router = APIRouter(prefix="/api/v1", tags=["lessons"])


def _to_skill_tree_response(summary: SkillTreeSummary) -> SkillTreeResponse:
    return SkillTreeResponse(
        unit_title=summary.unit_title,
        unit_subtitle=summary.unit_subtitle,
        skills=[
            SkillTreeEntryResponse(
                id=entry.skill.id,
                title=entry.skill.title,
                order_index=entry.skill.order_index,
                state=entry.state.value,
                crown_level=entry.crown_level,
                lesson_id=summary.lesson_id_by_skill.get(entry.skill.id),
                content_version=summary.content_version_by_skill[entry.skill.id],
            )
            for entry in summary.entries
        ],
        streak_count=summary.streak_count,
        beans=summary.beans,
        beans_max=summary.beans_max,
        total_xp=summary.total_xp,
    )


def _to_lesson_content_response(result: LessonContentResult) -> LessonContentResponse:
    lesson = result.lesson
    return LessonContentResponse(
        lesson=LessonSummaryResponse(
            id=lesson.id,
            skill_id=lesson.skill_id,
            title=lesson.title,
            order_index=lesson.order_index,
        ),
        exercises=[to_exercise_response(e) for e in lesson.exercises],
        content_version=result.content_version,
    )


@router.get("/skill-tree", response_model=SkillTreeResponse)
async def get_skill_tree_endpoint(
    user: User = Depends(get_current_user),
    skill_repo: SkillRepository = Depends(get_skill_repository),
    progress_repo: UserSkillProgressRepository = Depends(get_user_skill_progress_repository),
    beans_repo: UserBeansRepository = Depends(get_user_beans_repository),
    streak_repo: UserStreakRepository = Depends(get_user_streak_repository),
    attempt_repo: LessonAttemptRepository = Depends(get_lesson_attempt_repository),
    lesson_repo: LessonRepository = Depends(get_lesson_repository),
) -> SkillTreeResponse:
    """Story 001: the caller's skill tree with accurate per-skill
    locked/active/completed state and crown level -- including a brand-new
    user with zero progress rows. Extended (bolt 005) with the account's
    streak/beans/lifetime-XP HUD stats, and (bolt 007) each skill's next
    lesson id to navigate to, all in this same request.
    """
    summary = await get_skill_tree(
        user.id,
        skill_repo,
        progress_repo,
        beans_repo,
        streak_repo,
        attempt_repo,
        lesson_repo,
        datetime.now(UTC),
    )
    return _to_skill_tree_response(summary)


@router.get("/lessons/{lesson_id}", response_model=LessonContentResponse)
async def get_lesson_content_endpoint(
    lesson_id: str,
    user: User = Depends(get_current_user),
    lesson_repo: LessonRepository = Depends(get_lesson_repository),
    skill_repo: SkillRepository = Depends(get_skill_repository),
    progress_repo: UserSkillProgressRepository = Depends(get_user_skill_progress_repository),
) -> LessonContentResponse:
    """Story 001: a lesson's full, ordered exercise list in one request.
    404 if the lesson doesn't exist; 403 if its owning skill is locked for
    this user (even by direct lesson ID). Since ADR-5, each exercise also
    carries its correct-answer data, so the client can grade instantly and
    locally with zero further network calls.
    """
    result = await get_lesson_content(user.id, lesson_id, lesson_repo, skill_repo, progress_repo)
    return _to_lesson_content_response(result)


@router.get("/beans", response_model=BeansStatusResponse)
async def get_beans_status_endpoint(
    user: User = Depends(get_current_user),
    beans_repo: UserBeansRepository = Depends(get_user_beans_repository),
    amole_repo: AmoleTransactionRepository = Depends(get_amole_transaction_repository),
) -> BeansStatusResponse:
    """Story 002: the account's current Beans/Amole state, for the
    out-of-beans modal and dashboard HUD. Amole balance is now ledger-backed
    (bolt 017, ADR-8) -- same response shape as before.
    """
    result = await get_beans_status(user.id, beans_repo, amole_repo, datetime.now(UTC))
    return BeansStatusResponse(
        beans=result.beans,
        beans_max=result.beans_max,
        next_bean_at=result.next_bean_at.isoformat() if result.next_bean_at else None,
        regen_minutes_per_bean=BEAN_REGEN_MINUTES,
        amole_balance=result.amole_balance,
        refill_cost_amole=result.refill_cost_amole,
    )


@router.post("/beans/refill", response_model=RefillResponse)
async def refill_beans_endpoint(
    user: User = Depends(get_current_user),
    beans_repo: UserBeansRepository = Depends(get_user_beans_repository),
    amole_repo: AmoleTransactionRepository = Depends(get_amole_transaction_repository),
) -> RefillResponse:
    """Story 003: an immediate Beans refill using the account's Amole
    balance. 422 (`insufficient_amole`) if the balance can't cover it.
    """
    result = await refill_beans(user.id, beans_repo, amole_repo, datetime.now(UTC))
    return RefillResponse(beans=result.beans, amole_balance=result.amole_balance)


@router.post("/lessons/{lesson_id}/complete", response_model=CompleteLessonResponse)
async def complete_lesson_endpoint(
    lesson_id: str,
    request: CompleteLessonRequest,
    user: User = Depends(get_current_user),
    lesson_repo: LessonRepository = Depends(get_lesson_repository),
    skill_repo: SkillRepository = Depends(get_skill_repository),
    progress_repo: UserSkillProgressRepository = Depends(get_user_skill_progress_repository),
    beans_repo: UserBeansRepository = Depends(get_user_beans_repository),
    streak_repo: UserStreakRepository = Depends(get_user_streak_repository),
    attempt_repo: LessonAttemptRepository = Depends(get_lesson_attempt_repository),
    amole_repo: AmoleTransactionRepository = Depends(get_amole_transaction_repository),
    vocab_progress_repo: UserVocabProgressRepository = Depends(get_user_vocab_progress_repository),
) -> CompleteLessonResponse:
    """Stories 002/003/004: the account-ledger side of one completed lesson
    attempt (Beans consumption, XP award, skill-progress/crown-level
    update, streak update, bolt-017 Amole awards, and bolt-019 vocab
    progress -- ADR-10). Idempotent on `request.attempt_id`. 404 if the
    lesson doesn't exist; 422 `beans_exhausted`/`invalid_completion` for a
    malformed or beans-implausible completion (ADR-5).
    """
    outcome = await complete_lesson(
        user_id=user.id,
        lesson_id=lesson_id,
        attempt_id=request.attempt_id,
        correct_count=request.correct_count,
        total_count=request.total_count,
        time_spent_seconds=request.time_spent_seconds,
        daily_xp_target=user.daily_xp_target.xp_per_day,
        client_completed_at=request.client_completed_at,
        account_created_at=user.created_at,
        lesson_repo=lesson_repo,
        skill_repo=skill_repo,
        progress_repo=progress_repo,
        beans_repo=beans_repo,
        streak_repo=streak_repo,
        attempt_repo=attempt_repo,
        amole_repo=amole_repo,
        vocab_progress_repo=vocab_progress_repo,
        missed_exercise_ids=frozenset(request.missed_exercise_ids),
        now=datetime.now(UTC),
    )
    return CompleteLessonResponse(
        xp_earned=outcome.xp_awarded,
        daily_xp_total=outcome.daily_xp_total,
        daily_xp_target=outcome.daily_xp_target,
        streak_count=outcome.streak_count,
        streak_increased_today=outcome.streak_increased_today,
        accuracy_percent=outcome.accuracy_percent,
        correct_count=outcome.correct_count,
        total_count=outcome.total_count,
        time_spent_seconds=outcome.time_spent_seconds,
        skill_unlocked_title=outcome.skill_unlocked_title,
        crown_level=outcome.crown_level,
        crown_leveled_up=outcome.crown_leveled_up,
        streak_freeze_unlocked=outcome.streak_freeze_unlocked,
    )
