"""Integration tests: the team store (intent 028, story 002) through the
real SQLAlchemy repository."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import admin_content_use_cases as content_uc
from app.domain.admin import COURSE_ADMIN, SUPER_ADMIN, AdminMember
from app.domain.lesson.exceptions import AdminMemberExistsError
from app.infrastructure.db.admin_content_repository import SqlAlchemyAdminContentRepository
from app.infrastructure.db.admin_member_models import AdminMemberCourseModel
from app.infrastructure.db.admin_member_repository import SqlAlchemyAdminMemberRepository
from app.infrastructure.db.lesson_models import CourseModel
from tests.fakes import EN_AM_COURSE_ID

OWNER = "owner@example.com"
EN_OM_COURSE_ID = "c0000000-0000-0000-0000-0000000000om"


async def _second_course(session: AsyncSession) -> str:
    session.add(
        CourseModel(
            id=EN_OM_COURSE_ID,
            learning_language="om",
            from_language="en",
            title="English to Afaan Oromo",
            status="available",
            order_index=2,
            created_at=datetime.now(UTC),
        )
    )
    await session.flush()
    return EN_OM_COURSE_ID


async def _stored(repo: SqlAlchemyAdminMemberRepository, member_id: str) -> AdminMember:
    member = await repo.get(member_id)
    assert member is not None
    return member


async def _course_rows(session: AsyncSession) -> list[str]:
    rows = (await session.execute(select(AdminMemberCourseModel))).scalars().all()
    return [r.course_id for r in rows]


async def test_add_stores_a_normalised_email_and_find_ignores_case(
    db_session: AsyncSession,
) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)

    added = await repo.add(" Helper@Example.com ", COURSE_ADMIN, [EN_AM_COURSE_ID], admin=OWNER)

    assert added.email == "helper@example.com"
    assert added.role == COURSE_ADMIN
    assert added.course_ids == frozenset({EN_AM_COURSE_ID})
    assert (added.created_by, added.updated_by) == (OWNER, OWNER)
    assert await repo.find_by_email("HELPER@example.com") == added
    assert await repo.get(added.id) == added


async def test_timestamps_read_back_with_a_zone(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    added = await repo.add("a@example.com", SUPER_ADMIN, [], admin=OWNER)
    db_session.expunge_all()

    stored = await _stored(repo, added.id)

    assert stored.created_at is not None and stored.created_at.tzinfo is not None
    assert stored.updated_at is not None and stored.updated_at.tzinfo is not None


async def test_unknown_email_and_id_are_none(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)

    assert await repo.find_by_email("nobody@example.com") is None
    assert await repo.get("missing") is None


async def test_list_is_by_email_with_courses(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    om = await _second_course(db_session)
    await repo.add("zed@example.com", SUPER_ADMIN, [], admin=OWNER)
    await repo.add("amy@example.com", COURSE_ADMIN, [EN_AM_COURSE_ID, om], admin=OWNER)

    members = await repo.list_all()

    assert [m.email for m in members] == ["amy@example.com", "zed@example.com"]
    assert members[0].course_ids == frozenset({EN_AM_COURSE_ID, om})
    assert members[1].course_ids == frozenset()


async def test_a_super_admin_keeps_no_course_rows(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)

    added = await repo.add("a@example.com", SUPER_ADMIN, [EN_AM_COURSE_ID], admin=OWNER)

    assert added.course_ids == frozenset()
    assert await _course_rows(db_session) == []


async def test_a_second_member_with_the_same_email_is_refused(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    await repo.add("a@example.com", COURSE_ADMIN, [], admin=OWNER)

    with pytest.raises(AdminMemberExistsError) as raised:
        await repo.add("A@example.com", SUPER_ADMIN, [], admin=OWNER)

    assert raised.value.details == {"field": "email"}


async def test_update_replaces_role_and_courses(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    om = await _second_course(db_session)
    added = await repo.add("a@example.com", COURSE_ADMIN, [EN_AM_COURSE_ID], admin=OWNER)

    changed = await repo.update(added.id, COURSE_ADMIN, [om], admin="other@example.com")

    assert changed is not None
    assert changed.course_ids == frozenset({om})
    assert changed.updated_by == "other@example.com"
    assert changed.created_by == OWNER


async def test_making_a_course_admin_super_drops_their_courses(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    added = await repo.add("a@example.com", COURSE_ADMIN, [EN_AM_COURSE_ID], admin=OWNER)

    changed = await repo.update(added.id, SUPER_ADMIN, [EN_AM_COURSE_ID], admin=OWNER)

    assert changed is not None and changed.role == SUPER_ADMIN
    assert await _course_rows(db_session) == []


async def test_update_and_remove_of_an_unknown_id(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)

    assert await repo.update("missing", SUPER_ADMIN, [], admin=OWNER) is None
    assert await repo.remove("missing") is False


async def test_remove_deletes_the_member_and_their_courses(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    added = await repo.add("a@example.com", COURSE_ADMIN, [EN_AM_COURSE_ID], admin=OWNER)

    assert await repo.remove(added.id) is True

    assert await repo.find_by_email("a@example.com") is None
    assert await _course_rows(db_session) == []


async def test_forget_course_takes_it_off_every_member(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    om = await _second_course(db_session)
    a = await repo.add("a@example.com", COURSE_ADMIN, [EN_AM_COURSE_ID, om], admin=OWNER)
    b = await repo.add("b@example.com", COURSE_ADMIN, [om], admin=OWNER)

    await repo.forget_course(om)

    assert (await _stored(repo, a.id)).course_ids == frozenset({EN_AM_COURSE_ID})
    assert (await _stored(repo, b.id)).course_ids == frozenset()


async def test_deleting_a_course_takes_it_off_its_admins(db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminMemberRepository(db_session)
    om = await _second_course(db_session)
    member = await repo.add("a@example.com", COURSE_ADMIN, [EN_AM_COURSE_ID, om], admin=OWNER)

    await content_uc.delete_course(
        SqlAlchemyAdminContentRepository(db_session), content_uc.AdminContext(email=OWNER), om
    )

    assert (await _stored(repo, member.id)).course_ids == frozenset({EN_AM_COURSE_ID})
    assert await _course_rows(db_session) == [EN_AM_COURSE_ID]


async def test_a_row_for_a_course_that_is_gone_never_counts(db_session: AsyncSession) -> None:
    # SQLite has no foreign keys in development, so a stray row may exist.
    repo = SqlAlchemyAdminMemberRepository(db_session)
    member = await repo.add("a@example.com", COURSE_ADMIN, [], admin=OWNER)
    db_session.add(AdminMemberCourseModel(member_id=member.id, course_id="gone"))
    await db_session.flush()

    assert (await _stored(repo, member.id)).course_ids == frozenset()
