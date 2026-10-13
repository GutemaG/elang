"""The sweep (intent 028, story 010): every route under `/api/v1/admin` has
exactly one rule in `admin_route_rules.py`, and the route carries the
dependency that rule needs. A new admin route without a rule fails here,
so a course admin never reaches it by accident.

The cross-course attempts themselves are in `test_course_id_routes.py`,
`test_child_id_routes.py` and `test_language_routes.py`.
"""

from __future__ import annotations

from collections.abc import Callable, Iterator
from typing import Any

import pytest
from fastapi.dependencies.models import Dependant
from fastapi.routing import APIRoute

from app.infrastructure.api import dependencies as d
from app.main import create_app
from tests.integration.admin_route_rules import (
    BODY_LESSON,
    CHILD,
    COURSE,
    LANGUAGE,
    OPEN,
    SUPER_ONLY,
)

PREFIX = "/api/v1/admin"
CHILD_GUARD: dict[str, Callable[..., Any]] = {
    "section": d.require_section_course,
    "skill": d.require_skill_course,
    "lesson": d.require_lesson_course,
    "exercise": d.require_exercise_course,
    "vocab": d.require_vocab_course,
}


def _admin_routes() -> Iterator[tuple[tuple[str, str], Any]]:
    """(method, path) -> the route as served, with the dependencies of its
    routers. FastAPI 0.141 keeps included routers whole, so their routes
    are read through `effective_candidates()`."""
    for entry in create_app().routes:
        routes = entry.effective_candidates() if hasattr(entry, "effective_candidates") else [entry]
        for route in routes:
            if isinstance(route, APIRoute) or hasattr(route, "dependant"):
                if route.path.startswith(PREFIX):
                    for method in sorted(route.methods):
                        yield (method, route.path), route


def _calls(dependant: Dependant) -> set[Callable[..., Any]]:
    found: set[Callable[..., Any]] = set()
    for sub in dependant.dependencies:
        if sub.call is not None:
            found.add(sub.call)
        found |= _calls(sub)
    return found


def _rules() -> dict[tuple[str, str], list[str]]:
    rules: dict[tuple[str, str], list[str]] = {}
    for name, table in [
        ("super", SUPER_ONLY),
        ("course", COURSE),
        ("child", set(CHILD)),
        ("body_lesson", BODY_LESSON),
        ("language", LANGUAGE),
        ("open", OPEN),
    ]:
        for key in table:
            rules.setdefault(key, []).append(name)
    return rules


ROUTES = dict(_admin_routes())


def test_every_admin_route_has_exactly_one_rule() -> None:
    rules = _rules()

    missing = sorted(set(ROUTES) - set(rules))
    stale = sorted(set(rules) - set(ROUTES))
    doubled = sorted(k for k, v in rules.items() if len(v) > 1)

    assert missing == [], f"admin routes with no rule in admin_route_rules.py: {missing}"
    assert stale == [], f"rules for routes that don't exist: {stale}"
    assert doubled == [], f"routes with more than one rule: {doubled}"


@pytest.mark.parametrize("key", sorted(ROUTES))
def test_every_admin_route_requires_an_admin(key: tuple[str, str]) -> None:
    assert d.require_admin in _calls(ROUTES[key].dependant)


@pytest.mark.parametrize("key", sorted(SUPER_ONLY & set(ROUTES)))
def test_super_admin_routes_carry_the_super_admin_check(key: tuple[str, str]) -> None:
    assert d.require_super_admin in _calls(ROUTES[key].dependant)


@pytest.mark.parametrize("key", sorted(COURSE & set(ROUTES)))
def test_course_routes_carry_the_course_check(key: tuple[str, str]) -> None:
    assert d.require_course in _calls(ROUTES[key].dependant)


@pytest.mark.parametrize(("key", "kind"), sorted(CHILD.items()))
def test_child_routes_carry_their_kinds_check(key: tuple[str, str], kind: str) -> None:
    assert CHILD_GUARD[kind] in _calls(ROUTES[key].dependant)


@pytest.mark.parametrize("key", sorted(LANGUAGE & set(ROUTES)))
def test_language_routes_carry_the_language_check(key: tuple[str, str]) -> None:
    assert d.require_language in _calls(ROUTES[key].dependant)


@pytest.mark.parametrize("key", sorted((OPEN | BODY_LESSON) & set(ROUTES)))
def test_open_routes_are_not_super_admin_only(key: tuple[str, str]) -> None:
    assert d.require_super_admin not in _calls(ROUTES[key].dependant)
