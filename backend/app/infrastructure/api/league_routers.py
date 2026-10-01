"""FastAPI router for weekly leagues (023-weekly-leagues):
`GET /api/v1/leagues/current` (bolt 073) and
`POST /api/v1/leagues/last-result/seen` (bolt 074). The rules live in
`app.domain.league`; this only maps the use cases' answers.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Response

from app.application.league_use_cases import get_current_league, mark_last_result_seen
from app.domain.entities import User
from app.domain.lesson.repositories import AmoleTransactionRepository
from app.infrastructure.api.dependencies import get_current_user, get_league_repository
from app.infrastructure.api.league_schemas import (
    CurrentLeagueResponse,
    LastResultResponse,
    LeagueMemberResponse,
)
from app.infrastructure.api.lesson_dependencies import get_amole_transaction_repository
from app.infrastructure.db.league_repository import SqlAlchemyLeagueRepository

router = APIRouter(prefix="/api/v1/leagues", tags=["leagues"])


@router.get("/current", response_model=CurrentLeagueResponse)
async def get_current_league_endpoint(
    user: User = Depends(get_current_user),
    league_repo: SqlAlchemyLeagueRepository = Depends(get_league_repository),
    amole_repo: AmoleTransactionRepository = Depends(get_amole_transaction_repository),
) -> CurrentLeagueResponse:
    """The learner's tier, whether they are in this week's league, and
    their group ranked by the week's XP (FR-4, FR-8). Closes their ended
    weeks first and returns the last one's result until it is seen
    (FR-5)."""
    league = await get_current_league(
        user=user, now=datetime.now(UTC), league_repo=league_repo, amole_repo=amole_repo
    )
    last = league.last_result
    return CurrentLeagueResponse(
        tier=league.tier.value,
        status=league.status.value,
        week_ends_at=league.week_ends_at,
        promote_count=league.promote_count,
        demote_count=league.demote_count,
        rewards=list(league.rewards),
        members=[
            LeagueMemberResponse(
                name=m.name,
                initial=m.initial,
                avatar_colour=m.avatar_colour,
                weekly_xp=m.weekly_xp,
                rank=m.rank,
                is_me=m.is_me,
            )
            for m in league.members
        ],
        last_result=None
        if last is None
        else LastResultResponse(
            week_start=last.week_start,
            tier=last.tier.value,
            tier_after=last.tier_after.value,
            movement=last.movement.value,
            rank=last.rank,
            group_size=last.group_size,
            weekly_xp=last.weekly_xp,
            reward_amole=last.reward_amole,
        ),
    )


@router.post("/last-result/seen", status_code=204)
async def mark_last_result_seen_endpoint(
    user: User = Depends(get_current_user),
    league_repo: SqlAlchemyLeagueRepository = Depends(get_league_repository),
) -> Response:
    """The app showed the last-week result, so it is not offered again.
    Safe to repeat."""
    await mark_last_result_seen(user_id=user.id, now=datetime.now(UTC), league_repo=league_repo)
    return Response(status_code=204)
