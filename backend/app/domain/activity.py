"""The admin activity log (intent 030): what every admin write route records.

Each admin route that isn't a `GET` has an entry in `ADMIN_ACTIONS`, keyed
by method and path as FastAPI declares them. The entry names the area, the
action as the log shows it, and which kind of thing the route changes (read
from its path parameters). `None` is a deliberate "not a change": an upload
link or a link check changes nothing until the exercise is saved.

Use cases can add what only they know (a count, a reason) with
`note_activity`; it reaches the entry of the request that is running.

Pure Python only.
"""

from __future__ import annotations

from contextvars import ContextVar
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any

# How long entries are kept.
ACTIVITY_RETENTION = timedelta(days=730)

# Areas, in the order the admin site lists them.
AREAS: tuple[str, ...] = (
    "curriculum",
    "vocabulary",
    "workbook",
    "sounds",
    "voices",
    "audio_library",
    "languages",
    "team",
    "app_updates",
    "feedback",
    "leagues",
)


@dataclass(frozen=True)
class Action:
    """What one admin write route does."""

    area: str
    label: str
    # The kind of thing it changes, found from the path parameters, or None
    # when the path names nothing (the target is in the body).
    target: str | None = None


_P = "/api/v1/admin"

ADMIN_ACTIONS: dict[tuple[str, str], Action | None] = {
    # Curriculum
    ("POST", f"{_P}/courses"): Action("curriculum", "Added course"),
    ("PATCH", f"{_P}/courses/{{course_id}}"): Action("curriculum", "Edited course", "course"),
    ("DELETE", f"{_P}/courses/{{course_id}}"): Action("curriculum", "Deleted course", "course"),
    ("POST", f"{_P}/courses/{{course_id}}/sections"): Action(
        "curriculum", "Added section", "course"
    ),
    ("PUT", f"{_P}/courses/{{course_id}}/sections/order"): Action(
        "curriculum", "Reordered sections", "course"
    ),
    ("PATCH", f"{_P}/sections/{{section_id}}"): Action("curriculum", "Edited section", "section"),
    ("DELETE", f"{_P}/sections/{{section_id}}"): Action("curriculum", "Deleted section", "section"),
    ("POST", f"{_P}/sections/{{section_id}}/skills"): Action(
        "curriculum", "Added skill", "section"
    ),
    ("PUT", f"{_P}/sections/{{section_id}}/skills/order"): Action(
        "curriculum", "Reordered skills", "section"
    ),
    ("PATCH", f"{_P}/skills/{{skill_id}}"): Action("curriculum", "Edited skill", "skill"),
    ("DELETE", f"{_P}/skills/{{skill_id}}"): Action("curriculum", "Deleted skill", "skill"),
    ("POST", f"{_P}/skills/{{skill_id}}/lessons"): Action("curriculum", "Added lesson", "skill"),
    ("PUT", f"{_P}/skills/{{skill_id}}/lessons/order"): Action(
        "curriculum", "Reordered lessons", "skill"
    ),
    ("PATCH", f"{_P}/lessons/{{lesson_id}}"): Action("curriculum", "Edited lesson", "lesson"),
    ("DELETE", f"{_P}/lessons/{{lesson_id}}"): Action("curriculum", "Deleted lesson", "lesson"),
    ("POST", f"{_P}/lessons/{{lesson_id}}/exercises"): Action(
        "curriculum", "Added exercise", "lesson"
    ),
    ("POST", f"{_P}/lessons/{{lesson_id}}/exercises/import"): Action(
        "curriculum", "Imported exercises", "lesson"
    ),
    ("PUT", f"{_P}/lessons/{{lesson_id}}/exercises/order"): Action(
        "curriculum", "Reordered exercises", "lesson"
    ),
    ("PUT", f"{_P}/exercises/{{exercise_id}}"): Action("curriculum", "Edited exercise", "exercise"),
    ("DELETE", f"{_P}/exercises/{{exercise_id}}"): Action(
        "curriculum", "Deleted exercise", "exercise"
    ),
    # Upload links and link checks change nothing by themselves.
    ("POST", f"{_P}/audio/uploads"): None,
    ("POST", f"{_P}/audio/links"): None,
    ("POST", f"{_P}/images/uploads"): None,
    # Vocabulary
    ("PATCH", f"{_P}/vocab/{{vocab_item_id}}"): Action("vocabulary", "Edited word", "vocab"),
    # Workbook
    ("PUT", f"{_P}/courses/{{course_id}}/curriculum"): Action(
        "workbook", "Imported Workbook", "course"
    ),
    ("PATCH", f"{_P}/courses/{{course_id}}/curriculum/rows/{{ref}}"): Action(
        "workbook", "Edited Workbook row", "workbook_row"
    ),
    ("POST", f"{_P}/courses/{{course_id}}/curriculum/audio/uploads"): None,
    ("PUT", f"{_P}/courses/{{course_id}}/curriculum/lessons/{{ref}}/exercises"): Action(
        "workbook", "Saved draft exercises", "workbook_lesson"
    ),
    ("POST", f"{_P}/courses/{{course_id}}/curriculum/lessons/{{ref}}/publish"): Action(
        "workbook", "Published lesson", "workbook_lesson"
    ),
    # Sounds
    ("POST", f"{_P}/sound-charts"): Action("sounds", "Added sound chart"),
    ("PATCH", f"{_P}/sound-charts/{{language}}"): Action(
        "sounds", "Edited sound chart", "sound_chart"
    ),
    ("DELETE", f"{_P}/sound-charts/{{language}}"): Action(
        "sounds", "Deleted sound chart", "sound_chart"
    ),
    ("POST", f"{_P}/sound-charts/{{language}}/letters"): Action(
        "sounds", "Added letter", "sound_chart"
    ),
    ("PATCH", f"{_P}/sound-charts/{{language}}/letters"): Action(
        "sounds", "Edited letters", "sound_chart"
    ),
    ("DELETE", f"{_P}/sound-charts/{{language}}/letters/{{letter_id}}"): Action(
        "sounds", "Deleted letter", "sound_letter"
    ),
    ("POST", f"{_P}/sound-charts/{{language}}/audio/uploads"): None,
    # Voices
    ("PUT", f"{_P}/voice/settings/{{language}}"): Action(
        "voices", "Changed voice settings", "voice_language"
    ),
    ("POST", f"{_P}/voice/generate"): Action("voices", "Generated audio"),
    # Audio library
    ("POST", f"{_P}/audio-files/trash"): Action("audio_library", "Moved audio to trash"),
    ("POST", f"{_P}/audio-files/trash/restore"): Action("audio_library", "Restored audio"),
    ("POST", f"{_P}/audio-files/trash/delete"): Action("audio_library", "Deleted audio for good"),
    # Languages
    ("POST", f"{_P}/languages"): Action("languages", "Added language"),
    ("PATCH", f"{_P}/languages/{{code}}"): Action("languages", "Edited language", "language"),
    ("DELETE", f"{_P}/languages/{{code}}"): Action("languages", "Deleted language", "language"),
    # Team
    ("POST", f"{_P}/team"): Action("team", "Added team member"),
    ("PUT", f"{_P}/team/{{member_id}}"): Action("team", "Changed team member", "team_member"),
    ("DELETE", f"{_P}/team/{{member_id}}"): Action("team", "Removed team member", "team_member"),
    # App updates
    ("PATCH", f"{_P}/app-config"): Action("app_updates", "Changed app update settings"),
    # Feedback
    ("PATCH", f"{_P}/feedback/{{feedback_id}}"): Action(
        "feedback", "Changed feedback status", "feedback"
    ),
    # Leagues
    ("POST", f"{_P}/leagues/members/{{member_id}}/remove"): Action(
        "leagues", "Removed learner from league", "league_member"
    ),
    ("POST", f"{_P}/leagues/members/{{member_id}}/restore"): Action(
        "leagues", "Restored learner to league", "league_member"
    ),
    ("PUT", f"{_P}/leagues/members/{{member_id}}/xp"): Action(
        "leagues", "Adjusted weekly XP", "league_member"
    ),
}


@dataclass
class ActivityTarget:
    """The thing a route changes, as the log shows it."""

    kind: str | None = None
    id: str | None = None
    name: str | None = None
    course_id: str | None = None
    # Where it opens in the admin site, if it still exists.
    link: str | None = None


@dataclass
class ActivityNote:
    """What a use case adds to the running request's entry."""

    target_name: str | None = None
    course_id: str | None = None
    link: str | None = None
    details: dict[str, Any] = field(default_factory=dict)


_note: ContextVar[ActivityNote | None] = ContextVar("admin_activity_note", default=None)


def start_note() -> ActivityNote:
    """A fresh note for the request that is starting."""
    note = ActivityNote()
    _note.set(note)
    return note


def note_activity(
    *,
    target_name: str | None = None,
    course_id: str | None = None,
    link: str | None = None,
    **details: Any,
) -> None:
    """Adds to the current admin write's log entry. Outside a recorded
    request (a test calling a use case, a GET) it does nothing. Details are
    short values only: never content text, secrets or file bodies."""
    note = _note.get()
    if note is None:
        return
    if target_name is not None:
        note.target_name = target_name
    if course_id is not None:
        note.course_id = course_id
    if link is not None:
        note.link = link
    note.details.update({k: v for k, v in details.items() if v is not None})


@dataclass(frozen=True)
class ActivityEntry:
    id: str
    created_at: datetime
    admin_email: str
    admin_role: str
    method: str
    route: str
    area: str
    action: str
    target_kind: str | None
    target_id: str | None
    target_name: str | None
    course_id: str | None
    link: str | None
    details: dict[str, Any]
