"""FastAPI router for weekly leagues (023-weekly-leagues, bolt 073):
`GET /api/v1/leagues/current`. The rules live in `app.domain.league`; this
only maps the use case's answer to the response.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends

from app.application.league_use_cases import get_current_league
from app.domain.entities import User
from app.infrastructure.api.dependencies import get_current_user, get_league_repository
from app.infrastructure.api.league_schemas import CurrentLeagueResponse, LeagueMemberResponse
from app.infrastructure.db.league_repository import SqlAlchemyLeagueRepository

router = APIRouter(prefix="/api/v1/leagues", tags=["leagues"])


@router.get("/current", response_model=CurrentLeagueResponse)
async def get_current_league_endpoint(
    user: User = Depends(get_current_user),
    league_repo: SqlAlchemyLeagueRepository = Depends(get_league_repository),
) -> CurrentLeagueResponse:
    """The learner's tier, whether they are in this week's league, and
    their group ranked by the week's XP (FR-4, FR-8)."""
    league = await get_current_league(user=user, now=datetime.now(UTC), league_repo=league_repo)
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
    )
