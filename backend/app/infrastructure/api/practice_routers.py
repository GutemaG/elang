"""FastAPI router: `GET /api/v1/practice/due-count`,
`GET /api/v1/practice/due-items`, `POST /api/v1/practice/complete` (bolt
`019-srs-tracking-service`/`020-practice-ui`).

A separate router module from `lesson_routers.py` -- same one-file-per-
bounded-concern convention as `user_routers.py` alongside `routers.py` --
since Practice/SRS is its own concept, not an extension of the core lesson
loop's own endpoints.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query

from app.application.lesson_use_cases import (
    complete_practice_session,
    get_due_count,
    get_due_items,
)
from app.domain.entities import User
from app.domain.lesson.repositories import (
    AmoleTransactionRepository,
    LessonRepository,
    PracticeAttemptRepository,
    UserVocabProgressRepository,
    VocabItemRepository,
)
from app.infrastructure.api.dependencies import get_current_user
from app.infrastructure.api.exercise_mapping import to_exercise_response
from app.infrastructure.api.lesson_dependencies import (
    get_amole_transaction_repository,
    get_lesson_repository,
    get_practice_attempt_repository,
    get_user_vocab_progress_repository,
    get_vocab_item_repository,
)
from app.infrastructure.api.lesson_schemas import (
    CompletePracticeSessionRequest,
    CompletePracticeSessionResponse,
    DueCountResponse,
    DueItemResponse,
    DueItemsResponse,
)

router = APIRouter(prefix="/api/v1/practice", tags=["practice"])


@router.get("/due-count", response_model=DueCountResponse)
async def get_due_count_endpoint(
    user: User = Depends(get_current_user),
    vocab_progress_repo: UserVocabProgressRepository = Depends(get_user_vocab_progress_repository),
) -> DueCountResponse:
    """Story 004: the Practice entry point's due-count badge."""
    count = await get_due_count(user.id, vocab_progress_repo, datetime.now(UTC))
    return DueCountResponse(due_count=count)


@router.get("/due-items", response_model=DueItemsResponse)
async def get_due_items_endpoint(
    limit: int = Query(default=20, ge=1, le=100),
    user: User = Depends(get_current_user),
    vocab_progress_repo: UserVocabProgressRepository = Depends(get_user_vocab_progress_repository),
    vocab_item_repo: VocabItemRepository = Depends(get_vocab_item_repository),
    lesson_repo: LessonRepository = Depends(get_lesson_repository),
) -> DueItemsResponse:
    """Story 004: due vocab items ready for Practice session assembly
    (bolt 020), each resolved to its full exercise content so the existing
    exercise-engine UI can render it with no further round trip. No
    access-policy check here -- due-ness is Practice's only gate; a locked
    skill's item must still appear (story 002's edge case).
    """
    items = await get_due_items(
        user.id, vocab_progress_repo, vocab_item_repo, lesson_repo, datetime.now(UTC), limit
    )
    return DueItemsResponse(
        items=[
            DueItemResponse(
                vocab_item_id=item.vocab_item_id,
                word=item.word,
                translation=item.translation,
                exercise=to_exercise_response(item.exercise),
                box_level=item.box_level,
                next_review_at=item.next_review_at,
            )
            for item in items
        ]
    )


@router.post("/complete", response_model=CompletePracticeSessionResponse)
async def complete_practice_session_endpoint(
    request: CompletePracticeSessionRequest,
    user: User = Depends(get_current_user),
    vocab_progress_repo: UserVocabProgressRepository = Depends(get_user_vocab_progress_repository),
    amole_repo: AmoleTransactionRepository = Depends(get_amole_transaction_repository),
    practice_attempt_repo: PracticeAttemptRepository = Depends(get_practice_attempt_repository),
) -> CompletePracticeSessionResponse:
    """Story 002: a completed Practice session's account-ledger side --
    XP/Amole award and vocab-progress update. Idempotent on
    `request.session_id`. Deliberately does not touch streak or
    skill-progress (user decision, this bolt's Plan stage). 422
    `invalid_practice_completion` for an empty result list.
    """
    result = await complete_practice_session(
        user_id=user.id,
        session_id=request.session_id,
        results=[(r.vocab_item_id, r.correct) for r in request.results],
        now=datetime.now(UTC),
        vocab_progress_repo=vocab_progress_repo,
        amole_repo=amole_repo,
        practice_attempt_repo=practice_attempt_repo,
    )
    return CompletePracticeSessionResponse(
        xp_earned=result.xp_earned,
        amole_earned=result.amole_earned,
        correct_count=result.correct_count,
        total_count=result.total_count,
        accuracy_percent=result.accuracy_percent,
    )
