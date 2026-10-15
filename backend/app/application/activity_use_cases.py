"""The admin activity log (intent 030): recording each successful admin
change, and reading the log.

`require_admin` starts a recording for every admin write route before the
route runs, and finishes it only when the route succeeded. The target is
named before the change, so a deleted lesson keeps its title in the log.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta

from app.domain.activity import (
    ACTIVITY_RETENTION,
    ADMIN_ACTIONS,
    AREAS,
    Action,
    ActivityEntry,
    ActivityNote,
    ActivityTarget,
    start_note,
)
from app.domain.admin import AdminAccess
from app.domain.lesson.exceptions import InvalidContentError
from app.infrastructure.db.activity_repository import (
    ActivityCursor,
    ActivityFilters,
    SqlAlchemyActivityRepository,
)

logger = logging.getLogger("app.admin.activity")

PAGE_SIZE = 50


def _now() -> datetime:
    return datetime.now(UTC)


@dataclass
class Recording:
    """One admin write in progress."""

    repo: SqlAlchemyActivityRepository
    access: AdminAccess
    method: str
    route: str
    action: Action
    target: ActivityTarget
    note: ActivityNote
    params: dict[str, str]

    async def finish(self, now: datetime | None = None) -> None:
        """Writes the entry. Never raises: the change already succeeded.
        Anything but a delete is named again, so a renamed lesson shows its
        new title; a delete keeps the name read before it."""
        at = now or _now()
        try:
            if self.method != "DELETE" and self.action.target is not None:
                after = await self.repo.describe(self.action.target, self.params)
                if after.name is not None:
                    self.target = after
            await self.repo.add(
                ActivityEntry(
                    id=str(uuid.uuid4()),
                    created_at=at,
                    admin_email=self.access.email,
                    admin_role=self.access.role,
                    method=self.method,
                    route=self.route,
                    area=self.action.area,
                    action=self.action.label,
                    target_kind=self.target.kind,
                    target_id=self.target.id,
                    target_name=self.note.target_name or self.target.name,
                    course_id=self.note.course_id or self.target.course_id,
                    link=None if self.method == "DELETE" else self.note.link or self.target.link,
                    details=self.note.details,
                )
            )
            await self.repo.prune(at - ACTIVITY_RETENTION)
        except Exception:
            logger.exception(
                "admin_activity_not_recorded route=%s %s admin=%s",
                self.method,
                self.route,
                self.access.email,
            )


async def start_recording(
    repo: SqlAlchemyActivityRepository,
    *,
    access: AdminAccess,
    method: str,
    route: str | None,
    params: dict[str, str],
) -> Recording | None:
    """A recording for an admin write route, or None for a read or a route
    that changes nothing. A route missing from `ADMIN_ACTIONS` is still
    recorded, under its own path, so nothing is lost (the route test fails
    on it anyway)."""
    if method in ("GET", "HEAD", "OPTIONS") or route is None:
        return None
    key = (method, route)
    if key in ADMIN_ACTIONS:
        action = ADMIN_ACTIONS[key]
        if action is None:
            return None
    else:
        logger.warning("admin_activity_unlabelled route=%s %s", method, route)
        action = Action("other", f"{method} {route}")
    note = start_note()
    target = ActivityTarget()
    if action.target is not None:
        try:
            target = await repo.describe(action.target, params)
        except Exception:
            logger.exception("admin_activity_target_unreadable route=%s %s", method, route)
            target = ActivityTarget(kind=action.target)
    return Recording(repo, access, method, route, action, target, note, params)


# --- Reading -----------------------------------------------------------------


@dataclass(frozen=True)
class ActivityPage:
    items: list[ActivityEntry]
    total: int
    next_cursor: str | None
    admins: list[str]
    areas: list[str]
    courses: list[tuple[str, str]]


def _cursor_text(entry: ActivityEntry) -> str:
    return f"{entry.created_at.isoformat()}|{entry.id}"


def _parse_cursor(text: str) -> ActivityCursor:
    try:
        at, entry_id = text.split("|", 1)
        moment = datetime.fromisoformat(at)
    except ValueError as e:
        raise InvalidContentError("cursor", "That page link isn't valid") from e
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=UTC)
    return ActivityCursor(moment, entry_id)


def _day(value: date) -> datetime:
    return datetime(value.year, value.month, value.day, tzinfo=UTC)


async def list_activity(
    repo: SqlAlchemyActivityRepository,
    *,
    admin_email: str | None = None,
    area: str | None = None,
    course_id: str | None = None,
    since: date | None = None,
    until: date | None = None,
    search: str = "",
    cursor: str | None = None,
) -> ActivityPage:
    """Newest first, `PAGE_SIZE` at a time. `since` and `until` are whole
    days (UTC), both included."""
    if area is not None and area not in AREAS and area != "other":
        raise InvalidContentError("area", "Choose one of the listed areas")
    if since is not None and until is not None and until < since:
        raise InvalidContentError("until", "The end date is before the start date")
    filters = ActivityFilters(
        admin_email=(admin_email or "").strip().lower() or None,
        area=area,
        course_id=course_id or None,
        since=_day(since) if since else None,
        before=_day(until) + timedelta(days=1) if until else None,
        search=search.strip(),
    )
    after = _parse_cursor(cursor) if cursor else None
    items = await repo.entries(filters, after, PAGE_SIZE + 1)
    more = len(items) > PAGE_SIZE
    items = items[:PAGE_SIZE]
    present: set[str] = set(await repo.areas())
    return ActivityPage(
        items=items,
        total=await repo.count(filters),
        next_cursor=_cursor_text(items[-1]) if more and items else None,
        admins=await repo.admins(),
        areas=[a for a in (*AREAS, "other") if a in present],
        courses=await repo.courses(),
    )
