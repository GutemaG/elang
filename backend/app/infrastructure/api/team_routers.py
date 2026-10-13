"""The Team page's API (intent 028, FR-10): `/api/v1/admin/team`. Super
admins only, through the router-level `require_super_admin`.

- `GET` lists owners, then members.
- `POST` adds a member; `PUT /{id}` changes their role and courses;
  `DELETE /{id}` removes them. Owners have no id and can't be changed,
  and nobody changes their own access.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import team_use_cases as uc
from app.domain.admin import AdminAccess
from app.infrastructure.api.dependencies import get_owner_emails, require_super_admin
from app.infrastructure.api.team_schemas import (
    AddMemberRequest,
    TeamCourse,
    TeamMemberResponse,
    TeamResponse,
    UpdateMemberRequest,
)
from app.infrastructure.db.admin_member_repository import SqlAlchemyAdminMemberRepository
from app.infrastructure.db.session import get_db_session

router = APIRouter(
    prefix="/api/v1/admin/team", tags=["admin"], dependencies=[Depends(require_super_admin)]
)


async def _repo(session: AsyncSession = Depends(get_db_session)) -> SqlAlchemyAdminMemberRepository:
    return SqlAlchemyAdminMemberRepository(session)


def _member(row: uc.TeamMember) -> TeamMemberResponse:
    m = row.member
    return TeamMemberResponse(
        id=m.id if m else None,
        email=row.email,
        role=row.role,
        is_owner=row.is_owner,
        courses=[TeamCourse(id=i, title=t) for i, t in row.courses],
        last_signed_in_at=row.last_signed_in_at,
        created_by=m.created_by if m else None,
        created_at=m.created_at if m else None,
        updated_by=m.updated_by if m else None,
        updated_at=m.updated_at if m else None,
    )


@router.get("", response_model=TeamResponse)
async def list_team(
    repo: SqlAlchemyAdminMemberRepository = Depends(_repo),
    owners: frozenset[str] = Depends(get_owner_emails),
) -> TeamResponse:
    return TeamResponse(members=[_member(r) for r in await uc.list_team(repo, owners)])


@router.post("", response_model=TeamMemberResponse, status_code=201)
async def add_member(
    body: AddMemberRequest,
    repo: SqlAlchemyAdminMemberRepository = Depends(_repo),
    owners: frozenset[str] = Depends(get_owner_emails),
    access: AdminAccess = Depends(require_super_admin),
) -> TeamMemberResponse:
    row = await uc.add_member(
        repo, access, owners, email=body.email, role=body.role, course_ids=body.course_ids
    )
    return _member(row)


@router.put("/{member_id}", response_model=TeamMemberResponse)
async def update_member(
    member_id: str,
    body: UpdateMemberRequest,
    repo: SqlAlchemyAdminMemberRepository = Depends(_repo),
    access: AdminAccess = Depends(require_super_admin),
) -> TeamMemberResponse:
    row = await uc.update_member(
        repo, access, member_id, role=body.role, course_ids=body.course_ids
    )
    return _member(row)


@router.delete("/{member_id}", status_code=204)
async def remove_member(
    member_id: str,
    repo: SqlAlchemyAdminMemberRepository = Depends(_repo),
    access: AdminAccess = Depends(require_super_admin),
) -> Response:
    await uc.remove_member(repo, access, member_id)
    return Response(status_code=204)
