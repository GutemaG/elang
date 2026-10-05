"""A course's draft curriculum on the admin site (intent
`025-curriculum-workspace`): importing the curriculum workbook, reading it
with its progress, correcting and recording each row.

Every write is one transaction (`get_db_session`): an import with a single
bad item, or an edit made from an old copy, saves nothing.
"""

from __future__ import annotations

import logging
import secrets
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

from app.application.admin_audio_use_cases import (
    AUDIO_TYPES,
    MAX_UPLOAD_BYTES,
    UPLOAD_LINK_SECONDS,
    AudioStore,
)
from app.application.admin_content_use_cases import AdminContext, create_node
from app.domain.curriculum import (
    CONFIDENCES,
    ENTRY_KINDS,
    MAX_ACCEPTED,
    MAX_COMMENT,
    MAX_EXERCISES,
    MAX_GOAL,
    MAX_GRAMMAR,
    MAX_NOTES,
    MAX_TEXT,
    MAX_TITLE,
    PARENT_KIND,
    REF_PATTERN,
    ROW_KINDS,
    ROW_STATUSES,
    Counts,
    RowFacts,
    blank_in,
    counts_of,
    ready_to_publish,
)
from app.domain.lesson.exceptions import (
    AudioStorageNotConfiguredError,
    ContentChangedError,
    ContentNotFoundError,
    InvalidContentError,
    InvalidExerciseError,
    InvalidImportError,
    LessonNotReadyError,
)
from app.domain.lesson.exercise_parts import validate_exercise
from app.infrastructure.db.admin_content_repository import (
    EXERCISE,
    LESSON,
    SECTION,
    SKILL,
    SqlAlchemyAdminContentRepository,
)
from app.infrastructure.db.curriculum_models import (
    CurriculumEntryModel,
    CurriculumExerciseModel,
    CurriculumRowModel,
)
from app.infrastructure.db.curriculum_repository import SqlAlchemyCurriculumRepository
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
    VocabItemModel,
)
from app.infrastructure.external.r2_storage import PresignedUpload

logger = logging.getLogger("app.admin")

ENTRY_FIELDS = ("kind", "parent_ref", "position", "title", "goal", "grammar")
# What an import sets on a row. Never its audio: the workbook only says
# whether a recording exists.
ROW_IMPORT_FIELDS = (
    "kind",
    "lesson_ref",
    "position",
    "english",
    "text",
    "romanization",
    "blank",
    "accepted",
    "notes",
    "confidence",
    "status",
    "comment",
)
# What an edit may change.
ROW_EDIT_FIELDS = (
    "english",
    "text",
    "romanization",
    "blank",
    "accepted",
    "notes",
    "status",
    "comment",
    "audio_url",
)


def _log(ctx: AdminContext, action: str, entity: str, entity_id: str) -> None:
    logger.info(
        "admin_write action=%s entity=%s id=%s admin=%s", action, entity, entity_id, ctx.email
    )


def _now() -> datetime:
    return datetime.now(UTC)


# --- checking input -----------------------------------------------------------


class _Problems:
    """Every problem in a request, so a file is fixed in one pass."""

    def __init__(self) -> None:
        self.items: list[dict[str, str]] = []

    def add(self, ref: str, field_name: str, message: str) -> None:
        self.items.append({"ref": ref, "field": field_name, "message": message})

    def text(
        self, ref: str, name: str, value: Any, limit: int, *, required: bool = False
    ) -> str | None:
        if value is None:
            if required:
                self.add(ref, name, f"{name} is required")
            return None
        if not isinstance(value, str):
            self.add(ref, name, f"{name} must be text")
            return None
        cleaned = value.strip()
        if required and not cleaned:
            self.add(ref, name, f"{name} must not be empty")
            return None
        if len(cleaned) > limit:
            self.add(ref, name, f"{name} must be at most {limit} characters")
            return None
        return cleaned or None

    def choice(
        self, ref: str, name: str, value: Any, allowed: tuple[str, ...], *, nullable: bool = False
    ) -> str | None:
        if value is None and nullable:
            return None
        if value not in allowed:
            options = ", ".join(allowed) + (", or null" if nullable else "")
            self.add(ref, name, f"{name} must be one of: {options}")
            return None
        return str(value)

    def position(self, ref: str, value: Any) -> int:
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            self.add(ref, "position", "position must be a whole number, 0 or more")
            return 0
        return value

    def accepted(self, ref: str, value: Any) -> list[str]:
        if value is None:
            return []
        if not isinstance(value, list):
            self.add(ref, "accepted", "accepted must be a list of answers")
            return []
        if len(value) > MAX_ACCEPTED:
            self.add(ref, "accepted", f"accepted may hold at most {MAX_ACCEPTED} answers")
            return []
        answers = [self.text(ref, "accepted", v, MAX_TEXT) for v in value]
        return [a for a in answers if a]

    def first(self) -> InvalidContentError:
        item = self.items[0]
        return InvalidContentError(item["field"], item["message"])


def _audio(field_name: str, value: Any, ctx: AdminContext) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str):
        raise InvalidContentError(field_name, f"{field_name} must be text")
    url = value.strip()
    if not url:
        return None
    if len(url) > 1024:
        raise InvalidContentError(field_name, f"{field_name} must be at most 1024 characters")
    if url.startswith("https://") and len(url) > len("https://"):
        return url
    # Local development plays uploads the backend itself serves.
    if ctx.allow_local_media and url.startswith("/media/audio/"):
        return url
    raise InvalidContentError(field_name, f"{field_name} must be an https address")


def _ref(problems: _Problems, value: Any, where: str) -> str | None:
    if not isinstance(value, str) or not REF_PATTERN.match(value):
        shown = value if isinstance(value, str) else ""
        problems.add(shown or where, "ref", "ref must be 1-32 letters, digits, - or _")
        return None
    return value


def _clean_entry(problems: _Problems, raw: dict[str, Any], index: int) -> dict[str, Any] | None:
    ref = _ref(problems, raw.get("ref"), f"entry {index + 1}")
    if ref is None:
        return None
    before = len(problems.items)
    kind = problems.choice(ref, "kind", raw.get("kind"), ENTRY_KINDS)
    parent = raw.get("parent_ref")
    if kind == "section":
        if parent is not None:
            problems.add(ref, "parent_ref", "A section has no parent")
    elif kind is not None and (not isinstance(parent, str) or not REF_PATTERN.match(parent)):
        problems.add(ref, "parent_ref", f"A {kind} needs its {PARENT_KIND[kind]}'s ref")
    entry = {
        "ref": ref,
        "kind": kind,
        "parent_ref": parent if kind != "section" else None,
        "position": problems.position(ref, raw.get("position")),
        "title": problems.text(ref, "title", raw.get("title"), MAX_TITLE, required=True),
        "goal": problems.text(ref, "goal", raw.get("goal"), MAX_GOAL),
        "grammar": problems.text(ref, "grammar", raw.get("grammar"), MAX_GRAMMAR),
    }
    return entry if len(problems.items) == before else None


def _check_blank(problems: _Problems, ref: str, kind: str | None, text: Any, blank: Any) -> None:
    if not blank:
        return
    if kind == "word":
        problems.add(ref, "blank", "Only a sentence has a word to blank")
    elif not blank_in(text, blank):
        problems.add(ref, "blank", f"The word to blank, “{blank}”, is not in the sentence")


def _clean_row(problems: _Problems, raw: dict[str, Any], index: int) -> dict[str, Any] | None:
    ref = _ref(problems, raw.get("ref"), f"row {index + 1}")
    if ref is None:
        return None
    before = len(problems.items)
    kind = problems.choice(ref, "kind", raw.get("kind"), ROW_KINDS)
    lesson = raw.get("lesson_ref")
    if not isinstance(lesson, str) or not REF_PATTERN.match(lesson):
        problems.add(ref, "lesson_ref", "lesson_ref must be a lesson's ref")
    row = {
        "ref": ref,
        "kind": kind,
        "lesson_ref": lesson,
        "position": problems.position(ref, raw.get("position")),
        "english": problems.text(ref, "english", raw.get("english"), MAX_TEXT, required=True),
        "text": problems.text(ref, "text", raw.get("text"), MAX_TEXT),
        "romanization": problems.text(ref, "romanization", raw.get("romanization"), MAX_TEXT),
        "blank": problems.text(ref, "blank", raw.get("blank"), MAX_TEXT),
        "accepted": problems.accepted(ref, raw.get("accepted")),
        "notes": problems.text(ref, "notes", raw.get("notes"), MAX_NOTES),
        "confidence": problems.choice(
            ref, "confidence", raw.get("confidence"), CONFIDENCES, nullable=True
        ),
        "status": problems.choice(ref, "status", raw.get("status", "to_do"), ROW_STATUSES),
        "comment": problems.text(ref, "comment", raw.get("comment"), MAX_COMMENT),
    }
    _check_blank(problems, ref, kind, row["text"], row["blank"])
    return row if len(problems.items) == before else None


# --- reading ---------------------------------------------------------------------


async def _course_or_404(repo: SqlAlchemyCurriculumRepository, course_id: str) -> CourseModel:
    course = await repo.course(course_id)
    if course is None:
        raise ContentNotFoundError("No such course", entity="course", id=course_id)
    return course


def _facts(row: CurriculumRowModel) -> RowFacts:
    return RowFacts(text=row.text, status=row.status, has_audio=bool(row.audio_url))


@dataclass(frozen=True)
class CurriculumView:
    course: CourseModel
    entries: list[CurriculumEntryModel]
    rows: list[CurriculumRowModel]
    # Per lesson ref; a lesson with no rows counts zeros.
    lesson_counts: dict[str, Counts]
    total: Counts
    # Per lesson ref (bolt 085): `not_published`, `published` or `changed`,
    # and how many draft exercises it has.
    publish_states: dict[str, str] = field(default_factory=dict)
    exercise_counts: dict[str, int] = field(default_factory=dict)


def _aware(moment: datetime) -> datetime:
    """SQLite gives times back without their zone; they were saved in UTC."""
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


def publish_state(
    entry: CurriculumEntryModel,
    rows: list[CurriculumRowModel],
    exercises: list[CurriculumExerciseModel],
) -> str:
    """Whether a lesson is published, and whether anything changed since."""
    if entry.published_at is None:
        return "not_published"
    since = _aware(entry.published_at)
    changed = [_aware(r.updated_at) for r in rows] + [_aware(e.updated_at) for e in exercises]
    return "changed" if any(moment > since for moment in changed) else "published"


async def get_curriculum(repo: SqlAlchemyCurriculumRepository, course_id: str) -> CurriculumView:
    course = await _course_or_404(repo, course_id)
    entries = await repo.entries(course_id)
    rows = await repo.rows(course_id)
    exercises = await repo.exercises(course_id)
    lessons = [e for e in entries if e.kind == "lesson"]
    by_lesson: dict[str, list[RowFacts]] = {e.ref: [] for e in lessons}
    for row in rows:
        by_lesson.setdefault(row.lesson_ref, []).append(_facts(row))
    return CurriculumView(
        course=course,
        entries=entries,
        rows=rows,
        lesson_counts={ref: counts_of(facts) for ref, facts in by_lesson.items()},
        total=counts_of([_facts(r) for r in rows]),
        publish_states={
            e.ref: publish_state(
                e,
                [r for r in rows if r.lesson_ref == e.ref],
                [x for x in exercises if x.lesson_ref == e.ref],
            )
            for e in lessons
        },
        exercise_counts={
            e.ref: sum(1 for x in exercises if x.lesson_ref == e.ref) for e in lessons
        },
    )


# --- importing -------------------------------------------------------------------


@dataclass
class Tally:
    added: int = 0
    changed: int = 0
    kept: int = 0
    unchanged: int = 0


@dataclass
class ImportResult:
    entries: Tally = field(default_factory=Tally)
    rows: Tally = field(default_factory=Tally)
    # Rows the file would change but that are reviewed or recorded.
    kept: list[str] = field(default_factory=list)
    # Saved but not in the file; left as they are.
    missing_entries: list[str] = field(default_factory=list)
    missing_rows: list[str] = field(default_factory=list)
    dry_run: bool = False


def _differs(item: CurriculumEntryModel | CurriculumRowModel, new: dict, names: tuple) -> bool:
    return any(getattr(item, name) != new[name] for name in names)


def _check_tree(
    problems: _Problems,
    raw_entries: list[dict[str, Any]],
    entries: list[dict[str, Any]],
    rows: list[dict[str, Any]],
    saved: list[CurriculumEntryModel],
) -> None:
    """A skill sits in a section, a lesson in a skill, and a row in a
    lesson: in the file or already saved. An entry with problems of its own
    still counts as a parent, so one mistake is reported once."""
    kinds = {e.ref: e.kind for e in saved}
    kinds.update(
        {
            e["ref"]: e["kind"]
            for e in raw_entries
            if isinstance(e.get("ref"), str) and e.get("kind") in ENTRY_KINDS
        }
    )
    for entry in entries:
        wanted = PARENT_KIND[entry["kind"]]
        if wanted and kinds.get(entry["parent_ref"]) != wanted:
            message = f"{entry['parent_ref']} is not a {wanted} of this course"
            problems.add(entry["ref"], "parent_ref", message)
    for row in rows:
        if kinds.get(row["lesson_ref"]) != "lesson":
            problems.add(row["ref"], "lesson_ref", f"{row['lesson_ref']} is not a lesson")


def _duplicates(problems: _Problems, items: list[dict[str, Any]]) -> None:
    seen: set[str] = set()
    for item in items:
        if item["ref"] in seen:
            problems.add(item["ref"], "ref", f"{item['ref']} appears more than once")
        seen.add(item["ref"])


async def import_curriculum(
    repo: SqlAlchemyCurriculumRepository,
    ctx: AdminContext,
    course_id: str,
    *,
    entries: list[dict[str, Any]],
    rows: list[dict[str, Any]],
    overwrite_reviewed: bool = False,
    dry_run: bool = False,
) -> ImportResult:
    """Merges the file into the course's draft by ref. All or nothing:
    any problem is `422 invalid_import` listing every one."""
    await _course_or_404(repo, course_id)
    problems = _Problems()
    clean_entries = [e for i, raw in enumerate(entries) if (e := _clean_entry(problems, raw, i))]
    clean_rows = [r for i, raw in enumerate(rows) if (r := _clean_row(problems, raw, i))]
    _duplicates(problems, clean_entries)
    _duplicates(problems, clean_rows)
    saved_entries = {e.ref: e for e in await repo.entries(course_id)}
    saved_rows = {r.ref: r for r in await repo.rows(course_id)}
    _check_tree(problems, entries, clean_entries, clean_rows, list(saved_entries.values()))
    if problems.items:
        raise InvalidImportError(
            f"{len(problems.items)} problem(s) in the curriculum", rows=problems.items
        )

    result = ImportResult(dry_run=dry_run)
    now = _now()
    new_items: list[CurriculumEntryModel | CurriculumRowModel] = []
    for entry in clean_entries:
        saved = saved_entries.get(entry["ref"])
        if saved is None:
            result.entries.added += 1
            new_items.append(CurriculumEntryModel(course_id=course_id, **entry))
        elif _differs(saved, entry, ENTRY_FIELDS):
            result.entries.changed += 1
            if not dry_run:
                for name in ENTRY_FIELDS:
                    setattr(saved, name, entry[name])
                saved.updated_at = now
        else:
            result.entries.unchanged += 1

    for row in clean_rows:
        saved_row = saved_rows.get(row["ref"])
        if saved_row is None:
            result.rows.added += 1
            new_items.append(CurriculumRowModel(course_id=course_id, updated_by=ctx.email, **row))
        elif not _differs(saved_row, row, ROW_IMPORT_FIELDS):
            result.rows.unchanged += 1
        elif (saved_row.status == "reviewed" or saved_row.audio_url) and not overwrite_reviewed:
            result.rows.kept += 1
            result.kept.append(saved_row.ref)
        else:
            result.rows.changed += 1
            if not dry_run:
                retext = saved_row.audio_url and (
                    saved_row.text != row["text"] or saved_row.romanization != row["romanization"]
                )
                for name in ROW_IMPORT_FIELDS:
                    setattr(saved_row, name, row[name])
                if retext:
                    saved_row.status = "draft"
                saved_row.version += 1
                saved_row.updated_by = ctx.email
                saved_row.updated_at = now

    in_file = {e["ref"] for e in clean_entries}
    result.missing_entries = sorted(set(saved_entries) - in_file)
    result.missing_rows = sorted(set(saved_rows) - {r["ref"] for r in clean_rows})
    if not dry_run:
        await repo.add_all(new_items)
        await repo.flush()
        _log(ctx, "import", "curriculum", course_id)
    return result


# --- editing ---------------------------------------------------------------------


async def _row_or_404(
    repo: SqlAlchemyCurriculumRepository, course_id: str, ref: str
) -> CurriculumRowModel:
    await _course_or_404(repo, course_id)
    row = await repo.row(course_id, ref)
    if row is None:
        raise ContentNotFoundError("No such row", entity="curriculum_row", id=ref)
    return row


async def update_row(
    repo: SqlAlchemyCurriculumRepository,
    ctx: AdminContext,
    course_id: str,
    ref: str,
    *,
    version: int,
    changes: dict[str, Any],
) -> tuple[CurriculumRowModel, bool]:
    """Changes the fields sent, if `version` is the saved one. Returns the
    row, and whether a text change sent a recorded row back to Draft."""
    row = await _row_or_404(repo, course_id, ref)
    if version != row.version:
        raise ContentChangedError(
            "Someone saved this row after you opened it. Reload to see their change.",
            current_version=row.version,
        )
    problems = _Problems()
    clean: dict[str, Any] = {}
    for name, value in changes.items():
        if name == "english":
            clean[name] = problems.text(ref, name, value, MAX_TEXT, required=True)
        elif name in ("text", "romanization", "blank"):
            clean[name] = problems.text(ref, name, value, MAX_TEXT)
        elif name == "notes":
            clean[name] = problems.text(ref, name, value, MAX_NOTES)
        elif name == "comment":
            clean[name] = problems.text(ref, name, value, MAX_COMMENT)
        elif name == "accepted":
            clean[name] = problems.accepted(ref, value)
        elif name == "status":
            clean[name] = problems.choice(ref, name, value, ROW_STATUSES)
        elif name == "audio_url":
            clean[name] = _audio(name, value, ctx)
        else:
            problems.add(ref, name, f"{name} cannot be changed")
    if not problems.items:
        _check_blank(
            problems,
            ref,
            row.kind,
            clean.get("text", row.text),
            clean.get("blank", row.blank),
        )
    if problems.items:
        raise problems.first()

    retext = any(
        name in clean and clean[name] != getattr(row, name) for name in ("text", "romanization")
    )
    reset = bool(row.audio_url) and retext and "status" not in clean
    changed = any(getattr(row, name) != value for name, value in clean.items()) or reset
    if not changed:
        return row, False
    for name, value in clean.items():
        setattr(row, name, value)
    if reset:
        row.status = "draft"
    row.version += 1
    row.updated_by = ctx.email
    row.updated_at = _now()
    await repo.flush()
    _log(ctx, "update", "curriculum_row", f"{course_id}/{ref}")
    return row, reset


# --- recordings ------------------------------------------------------------------


async def presign_upload(
    repo: SqlAlchemyCurriculumRepository,
    ctx: AdminContext,
    storage: AudioStore | None,
    course_id: str,
    *,
    row_ref: str,
    content_type: str,
    size: int,
) -> tuple[str, PresignedUpload]:
    """A PUT link for one row's recording; save its address as the row's
    `audio_url` afterwards. The same types and limits as lesson audio."""
    base_type = content_type.split(";")[0].strip().lower()
    if base_type not in AUDIO_TYPES:
        raise InvalidContentError(
            "content_type", f"Audio must be one of: {', '.join(sorted(AUDIO_TYPES))}"
        )
    if not 0 < size <= MAX_UPLOAD_BYTES:
        raise InvalidContentError("size", "Audio must be between 1 byte and 5 MB")
    if storage is None:
        raise AudioStorageNotConfiguredError("Audio storage is not configured on this server")
    await _row_or_404(repo, course_id, row_ref)
    course = await _course_or_404(repo, course_id)
    key = (
        f"{course.learning_language}/curriculum/{row_ref}/"
        f"{secrets.token_hex(6)}.{AUDIO_TYPES[base_type]}"
    )
    upload = storage.presign_put(
        key, content_type=base_type, size=size, expires_in=UPLOAD_LINK_SECONDS
    )
    _log(ctx, "presign", "audio", key)
    return key, upload


# --- draft exercises (bolt 085) ------------------------------------------------


async def _lesson_or_404(
    repo: SqlAlchemyCurriculumRepository, course_id: str, ref: str
) -> tuple[CurriculumEntryModel, dict[str, CurriculumEntryModel], list[CurriculumRowModel]]:
    """The lesson entry, every entry by ref, and the lesson's rows."""
    await _course_or_404(repo, course_id)
    entries = {e.ref: e for e in await repo.entries(course_id)}
    lesson = entries.get(ref)
    if lesson is None or lesson.kind != "lesson":
        raise ContentNotFoundError("No such lesson in the curriculum", entity="lesson", id=ref)
    rows = [r for r in await repo.rows(course_id) if r.lesson_ref == ref]
    return lesson, entries, rows


def _require_ready(rows: list[CurriculumRowModel]) -> None:
    if not ready_to_publish([_facts(r) for r in rows]):
        raise LessonNotReadyError(
            "Every word and sentence must be reviewed and recorded first",
            reason="rows",
            rows=len(rows),
            not_reviewed=sum(1 for r in rows if r.status != "reviewed"),
            not_recorded=sum(1 for r in rows if not r.audio_url),
        )


async def list_draft_exercises(
    repo: SqlAlchemyCurriculumRepository, course_id: str, ref: str
) -> list[CurriculumExerciseModel]:
    await _lesson_or_404(repo, course_id, ref)
    return await repo.exercises(course_id, ref)


@dataclass(frozen=True)
class DraftExerciseInput:
    type: str
    prompt: str
    content: Any
    answer_key: Any
    vocab_ref: str | None = None
    generated: dict[str, Any] | None = None
    edited: bool = False


def _check_exercises(
    items: list[DraftExerciseInput], words: set[str], ctx: AdminContext
) -> list[dict[str, object]]:
    problems: list[dict[str, object]] = []
    for index, item in enumerate(items):
        try:
            validate_exercise(
                item.type,
                item.prompt,
                item.content,
                item.answer_key,
                allow_local_media=ctx.allow_local_media,
            )
        except InvalidExerciseError as exc:
            problems.append({"index": index, "field": exc.field, "message": exc.message})
            continue
        if item.vocab_ref is not None and item.vocab_ref not in words:
            message = f"{item.vocab_ref} is not a word of this lesson"
            problems.append({"index": index, "field": "vocab_ref", "message": message})
    return problems


async def save_draft_exercises(
    repo: SqlAlchemyCurriculumRepository,
    ctx: AdminContext,
    course_id: str,
    ref: str,
    items: list[DraftExerciseInput],
) -> list[CurriculumExerciseModel]:
    """Replaces the lesson's draft exercises, all or nothing. Only for a
    lesson whose rows are all reviewed and recorded."""
    _, _, rows = await _lesson_or_404(repo, course_id, ref)
    _require_ready(rows)
    if not 1 <= len(items) <= MAX_EXERCISES:
        raise InvalidContentError(
            "exercises", f"a lesson has 1 to {MAX_EXERCISES} exercises, not {len(items)}"
        )
    words = {r.ref for r in rows if r.kind == "word"}
    problems = _check_exercises(items, words, ctx)
    if problems:
        raise InvalidImportError(
            f"{len(problems)} of {len(items)} exercises cannot be saved", rows=problems
        )
    await repo.clear_exercises(course_id, ref)
    now = _now()
    await repo.add_all(
        [
            CurriculumExerciseModel(
                course_id=course_id,
                lesson_ref=ref,
                position=i,
                type=item.type,
                prompt=item.prompt.strip(),
                content=item.content,
                answer_key=item.answer_key,
                vocab_ref=item.vocab_ref,
                generated=item.generated,
                edited=item.edited,
                updated_at=now,
            )
            for i, item in enumerate(items)
        ]
    )
    _log(ctx, "update", "curriculum_exercises", f"{course_id}/{ref}")
    return await repo.exercises(course_id, ref)


# --- publishing (bolt 085) -------------------------------------------------------


async def _in_course(
    content: SqlAlchemyAdminContentRepository, model: type[Any], row_id: str | None, course_id: str
) -> Any:
    """The live category, skill or lesson made from an entry, if it is still
    in this course (an admin may have deleted it since)."""
    if row_id is None:
        return None
    row = await content.get(model, row_id)
    if row is None:
        return None
    category_id: str | None = row.id
    if model is LessonModel:
        skill = await content.get(SkillModel, row.skill_id)
        category_id = skill.category_id if skill else None
    elif model is SkillModel:
        category_id = row.category_id
    category = await content.get(CategoryModel, category_id) if category_id else None
    return row if category is not None and category.course_id == course_id else None


@dataclass(frozen=True)
class PublishResult:
    category_id: str
    skill_id: str
    lesson_id: str
    exercise_ids: list[str]
    # What this publish made, of "section", "skill" and "lesson".
    created: list[str]


async def publish_lesson(
    repo: SqlAlchemyCurriculumRepository,
    content: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    course_id: str,
    ref: str,
) -> PublishResult:
    """Copies a finished lesson into the course, beside what is there: its
    section and skill when new, the lesson, a vocabulary item per word, and
    its exercises in place of the ones it published before. One
    transaction."""
    lesson_entry, entries, rows = await _lesson_or_404(repo, course_id, ref)
    _require_ready(rows)
    drafts = await repo.exercises(course_id, ref)
    if not drafts:
        raise LessonNotReadyError("Generate the lesson's exercises first", reason="exercises")
    words = {r.ref for r in rows if r.kind == "word"}
    problems = _check_exercises(
        [
            DraftExerciseInput(d.type, d.prompt, d.content, d.answer_key, d.vocab_ref)
            for d in drafts
        ],
        words,
        ctx,
    )
    if problems:
        raise InvalidImportError(
            f"{len(problems)} of {len(drafts)} exercises cannot be published", rows=problems
        )
    skill_entry = entries[lesson_entry.parent_ref or ""]
    section_entry = entries[skill_entry.parent_ref or ""]
    created: list[str] = []

    category = await _in_course(content, CategoryModel, section_entry.published_id, course_id)
    if category is None:
        category = await create_node(
            content, ctx, SECTION, course_id, title=section_entry.title, subtitle=""
        )
        section_entry.published_id = category.id
        created.append("section")
    skill = await _in_course(content, SkillModel, skill_entry.published_id, course_id)
    if skill is None:
        skill = await create_node(content, ctx, SKILL, category.id, title=skill_entry.title)
        skill_entry.published_id = skill.id
        created.append("skill")
    lesson = await _in_course(content, LessonModel, lesson_entry.published_id, course_id)
    if lesson is None:
        lesson = await create_node(content, ctx, LESSON, skill.id, title=lesson_entry.title)
        lesson_entry.published_id = lesson.id
        created.append("lesson")

    vocab: dict[str, str] = {}
    for row in rows:
        if row.kind != "word":
            continue
        item = await content.get(VocabItemModel, row.vocab_item_id) if row.vocab_item_id else None
        if item is None or item.course_id != course_id:
            item = VocabItemModel(
                id=str(uuid.uuid4()),
                course_id=course_id,
                word=row.text or "",
                translation=row.english,
            )
            await content.add(item)
            row.vocab_item_id = item.id
        else:
            item.word = row.text or ""
            item.translation = row.english
        vocab[row.ref] = item.id

    for old_id in lesson_entry.published_exercise_ids or []:
        old = await content.get(ExerciseModel, old_id)
        if old is not None and old.lesson_id == lesson.id:
            await content.delete_row(old)
    start = await content.next_order_index(EXERCISE, lesson.id)
    published: list[str] = []
    for offset, draft in enumerate(drafts):
        exercise = ExerciseModel(
            id=str(uuid.uuid4()),
            lesson_id=lesson.id,
            order_index=start + offset,
            type=draft.type,
            prompt=draft.prompt,
            content=draft.content,
            answer_key=draft.answer_key,
            vocab_item_id=vocab.get(draft.vocab_ref) if draft.vocab_ref else None,
        )
        await content.add(exercise)
        published.append(exercise.id)
    await content.touch_lesson(lesson)

    lesson_entry.published_exercise_ids = published
    lesson_entry.published_at = _now()
    await repo.flush()
    _log(ctx, "publish", "curriculum_lesson", f"{course_id}/{ref}")
    return PublishResult(
        category_id=category.id,
        skill_id=skill.id,
        lesson_id=lesson.id,
        exercise_ids=published,
        created=created,
    )
