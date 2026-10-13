"""Which admin routes each role may reach (intent 028). One table, read by
the route tests here and by the sweep in bolt 107, so they can't drift.

Paths are as FastAPI declares them, placeholders included.
"""

from __future__ import annotations

# FR-5: a course admin gets 403 `super_admin_only` on each.
SUPER_ONLY: frozenset[tuple[str, str]] = frozenset(
    {
        ("POST", "/api/v1/admin/courses"),
        ("PATCH", "/api/v1/admin/courses/{course_id}"),
        ("DELETE", "/api/v1/admin/courses/{course_id}"),
        ("POST", "/api/v1/admin/languages"),
        ("PATCH", "/api/v1/admin/languages/{code}"),
        ("DELETE", "/api/v1/admin/languages/{code}"),
        ("GET", "/api/v1/admin/app-config"),
        ("PATCH", "/api/v1/admin/app-config"),
        ("PUT", "/api/v1/admin/voice/settings/{language}"),
        ("GET", "/api/v1/admin/voice/usage"),
        ("POST", "/api/v1/admin/sound-charts"),
        ("DELETE", "/api/v1/admin/sound-charts/{language}"),
        ("GET", "/api/v1/admin/learners"),
        ("GET", "/api/v1/admin/learners/{user_id}"),
        ("GET", "/api/v1/admin/reports"),
        ("GET", "/api/v1/admin/feedback"),
        ("PATCH", "/api/v1/admin/feedback/{feedback_id}"),
        ("GET", "/api/v1/admin/team"),
        ("POST", "/api/v1/admin/team"),
        ("PUT", "/api/v1/admin/team/{member_id}"),
        ("DELETE", "/api/v1/admin/team/{member_id}"),
    }
)

# FR-7: named by `{course_id}`; another course's id is the unknown-course
# 404 for a course admin.
COURSE: frozenset[tuple[str, str]] = frozenset(
    {
        ("GET", "/api/v1/admin/courses/{course_id}/tree"),
        ("POST", "/api/v1/admin/courses/{course_id}/sections"),
        ("PUT", "/api/v1/admin/courses/{course_id}/sections/order"),
        ("GET", "/api/v1/admin/courses/{course_id}/vocab"),
        ("GET", "/api/v1/admin/courses/{course_id}/curriculum"),
        ("PUT", "/api/v1/admin/courses/{course_id}/curriculum"),
        ("PATCH", "/api/v1/admin/courses/{course_id}/curriculum/rows/{ref}"),
        ("POST", "/api/v1/admin/courses/{course_id}/curriculum/audio/uploads"),
        ("GET", "/api/v1/admin/courses/{course_id}/curriculum/lessons/{ref}/exercises"),
        ("PUT", "/api/v1/admin/courses/{course_id}/curriculum/lessons/{ref}/exercises"),
        ("POST", "/api/v1/admin/courses/{course_id}/curriculum/lessons/{ref}/publish"),
    }
)

# FR-7: named by a section, skill, lesson, exercise or vocab item; another
# course's item is that kind's unknown-id 404 for a course admin.
CHILD: dict[tuple[str, str], str] = {
    ("PATCH", "/api/v1/admin/sections/{section_id}"): "section",
    ("DELETE", "/api/v1/admin/sections/{section_id}"): "section",
    ("POST", "/api/v1/admin/sections/{section_id}/skills"): "section",
    ("PUT", "/api/v1/admin/sections/{section_id}/skills/order"): "section",
    ("PATCH", "/api/v1/admin/skills/{skill_id}"): "skill",
    ("DELETE", "/api/v1/admin/skills/{skill_id}"): "skill",
    ("POST", "/api/v1/admin/skills/{skill_id}/lessons"): "skill",
    ("PUT", "/api/v1/admin/skills/{skill_id}/lessons/order"): "skill",
    ("PATCH", "/api/v1/admin/lessons/{lesson_id}"): "lesson",
    ("DELETE", "/api/v1/admin/lessons/{lesson_id}"): "lesson",
    ("GET", "/api/v1/admin/lessons/{lesson_id}/exercises"): "lesson",
    ("POST", "/api/v1/admin/lessons/{lesson_id}/exercises"): "lesson",
    ("POST", "/api/v1/admin/lessons/{lesson_id}/exercises/import"): "lesson",
    ("PUT", "/api/v1/admin/lessons/{lesson_id}/exercises/order"): "lesson",
    ("PUT", "/api/v1/admin/exercises/{exercise_id}"): "exercise",
    ("DELETE", "/api/v1/admin/exercises/{exercise_id}"): "exercise",
    ("PATCH", "/api/v1/admin/vocab/{vocab_item_id}"): "vocab",
}

# FR-7: the lesson is named in the body (`lesson_id`).
BODY_LESSON: frozenset[tuple[str, str]] = frozenset(
    {
        ("POST", "/api/v1/admin/audio/uploads"),
        ("POST", "/api/v1/admin/images/uploads"),
        ("POST", "/api/v1/admin/voice/generate"),
    }
)

# FR-8: a sounds chart route, for the languages a course admin's courses
# teach; any other language is the no-chart 404.
LANGUAGE: frozenset[tuple[str, str]] = frozenset(
    {
        ("GET", "/api/v1/admin/sound-charts/{language}"),
        ("PATCH", "/api/v1/admin/sound-charts/{language}"),
        ("POST", "/api/v1/admin/sound-charts/{language}/letters"),
        ("PATCH", "/api/v1/admin/sound-charts/{language}/letters"),
        ("DELETE", "/api/v1/admin/sound-charts/{language}/letters/{letter_id}"),
        ("POST", "/api/v1/admin/sound-charts/{language}/audio/uploads"),
    }
)

# FR-6: open to any admin. The course list and chart list are filtered
# inside the route; generation checks its lesson or language itself.
OPEN: frozenset[tuple[str, str]] = frozenset(
    {
        ("GET", "/api/v1/admin/me"),
        ("GET", "/api/v1/admin/courses"),
        ("GET", "/api/v1/admin/languages"),
        ("GET", "/api/v1/admin/sound-charts"),
        ("GET", "/api/v1/admin/voice/settings"),
        ("GET", "/api/v1/admin/voice/voices"),
        ("POST", "/api/v1/admin/audio/links"),
    }
)

# Values for path placeholders that match nothing, so a call that gets
# through changes nothing.
PLACEHOLDERS = {
    "course_id": "missing",
    "code": "xx",
    "language": "xx",
    "user_id": "missing",
    "feedback_id": "missing",
    "member_id": "missing",
}


def concrete(path: str) -> str:
    """A declared path with its placeholders filled in."""
    for name, value in PLACEHOLDERS.items():
        path = path.replace("{" + name + "}", value)
    return path
