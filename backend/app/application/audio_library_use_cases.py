"""The Audio library (intent 029): what is stored, what uses it, the trash,
and the export.

A stored link names a key when it starts with the store's public address
(FR-2). Every file is matched to its uses in one pass over the three link
tables; nothing about uses is stored, so the page is always current.

A file can be trashed only when nothing uses it and it is more than a day
old, because a file is uploaded before the exercise that links it is
saved. Trashed files sit under `trash/{key}` until restored or deleted.
"""

from __future__ import annotations

import logging
import re
import unicodedata
from collections.abc import Iterator
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any
from urllib.parse import quote, unquote, urlsplit

from app.domain.activity import note_activity
from app.domain.lesson.exceptions import (
    AudioFileExistsError,
    AudioFileInUseError,
    AudioFileNotFoundError,
    ContentNotFoundError,
    InvalidContentError,
)
from app.infrastructure.db.audio_library_repository import (
    CourseRow,
    SqlAlchemyAudioLibraryRepository,
)
from app.infrastructure.external.media_library import MediaLibrary, is_safe_key

logger = logging.getLogger(__name__)

AUDIO_EXTENSIONS = frozenset({"m4a", "mp3", "webm", "ogg", "wav"})
TRASH_PREFIX = "trash/"
TRASH_AFTER = timedelta(hours=24)
MAX_KEYS = 500

# Where a use is: an exercise, a Workbook row, or a Sounds letter's own
# sound or its example word.
EXERCISE, WORKBOOK, SOUND, SOUND_EXAMPLE = "exercise", "workbook", "sound", "sound_example"


def is_audio(key: str) -> bool:
    return key.rsplit(".", 1)[-1].lower() in AUDIO_EXTENSIONS if "." in key else False


def key_of(url: str, public_prefix: str) -> str | None:
    """The stored key a link names, or None for a link elsewhere. The local
    store's prefix is a path, matched with or without the backend's host."""
    bare = url.strip().split("#", 1)[0].split("?", 1)[0]
    if public_prefix.startswith("/"):
        bare = urlsplit(bare).path if "://" in bare else bare
    if not bare.startswith(public_prefix):
        return None
    key = unquote(bare[len(public_prefix) :])
    return key if is_safe_key(key) else None


def _is_external_audio(url: str) -> bool:
    bare = url.strip().split("?", 1)[0]
    return bare.startswith(("https://", "http://")) and is_audio(bare)


def slug(text: str | None, fallback: str = "x") -> str:
    """ASCII, lower case, dashes: safe in any ZIP tool. Fidel has no ASCII
    form, so a title in Fidel falls back (the manifest keeps the real one)."""
    ascii_text = unicodedata.normalize("NFKD", text or "").encode("ascii", "ignore").decode()
    value = re.sub(r"[^a-z0-9]+", "-", ascii_text.lower()).strip("-")[:40].strip("-")
    return value or fallback


@dataclass(frozen=True)
class Use:
    place: str
    language: str
    admin_path: str
    zip_dir: str
    zip_name: str
    order: tuple[Any, ...]
    course_id: str | None = None
    course_title: str | None = None
    section: str | None = None
    skill: str | None = None
    lesson: str | None = None
    exercise_id: str | None = None
    exercise_number: int | None = None
    exercise_type: str | None = None
    prompt: str | None = None
    text: str | None = None
    english: str | None = None
    letter: str | None = None


@dataclass(frozen=True)
class LibraryFile:
    key: str
    url: str
    size: int
    uploaded_at: datetime
    language: str
    source: str
    uses: list[Use]
    can_trash: bool

    @property
    def status(self) -> str:
        return "in_use" if self.uses else "unused"


@dataclass(frozen=True)
class MissingFile:
    key: str
    url: str
    uses: list[Use]


@dataclass(frozen=True)
class TrashFile:
    key: str
    original_key: str
    size: int
    moved_at: datetime


@dataclass(frozen=True)
class Library:
    storage: str
    files: list[LibraryFile]
    missing: list[MissingFile]
    trash: list[TrashFile]
    external_links: int
    courses: list[CourseRow]


def _strings(value: object) -> Iterator[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from _strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from _strings(v)


@dataclass
class _Uses:
    by_key: dict[str, list[Use]] = field(default_factory=dict)
    external: int = 0

    def add(self, url: str | None, prefix: str, use: Use) -> None:
        if not url:
            return
        key = key_of(url, prefix)
        if key is None:
            if _is_external_audio(url):
                self.external += 1
            return
        if not is_audio(key):
            return
        uses = self.by_key.setdefault(key, [])
        if use not in uses:
            uses.append(use)


async def _uses(
    repo: SqlAlchemyAudioLibraryRepository, prefix: str, courses: list[CourseRow]
) -> _Uses:
    by_id = {c.id: c for c in courses}
    found = _Uses()

    exercises = await repo.exercises()
    numbers: dict[str, int] = {}
    for lesson_id in {e.lesson_id for e in exercises}:
        mine = sorted(
            (e for e in exercises if e.lesson_id == lesson_id), key=lambda e: e.order_index
        )
        numbers.update({e.id: n for n, e in enumerate(mine, start=1)})
    for e in exercises:
        course = by_id.get(e.course_id)
        if course is None:
            continue
        number = numbers[e.id]
        use = Use(
            place=EXERCISE,
            language=course.learning_language,
            admin_path=f"/courses/{e.course_id}/lessons/{e.lesson_id}/exercises/{e.id}",
            zip_dir="/".join(
                [
                    slug(course.title, "course"),
                    f"{e.section_order:02d}-{slug(e.section_title, 'section')}",
                    f"{e.skill_order:02d}-{slug(e.skill_title, 'skill')}",
                    f"{e.lesson_order:02d}-{slug(e.lesson_title, 'lesson')}",
                ]
            ),
            zip_name=f"ex{number:02d}-{slug(e.type)}",
            order=(0, course.order_index, e.section_order, e.skill_order, e.lesson_order, number),
            course_id=e.course_id,
            course_title=course.title,
            section=e.section_title,
            skill=e.skill_title,
            lesson=e.lesson_title,
            exercise_id=e.id,
            exercise_number=number,
            exercise_type=e.type,
            prompt=e.prompt,
        )
        for text in _strings(e.content):
            found.add(text, prefix, use)

    for r in await repo.workbook_rows():
        course = by_id.get(r.course_id)
        if course is None:
            continue
        found.add(
            r.audio_url,
            prefix,
            Use(
                place=WORKBOOK,
                language=course.learning_language,
                admin_path=(
                    f"/courses/{r.course_id}/workbook/lessons/{quote(r.lesson_ref, safe='')}"
                ),
                zip_dir="/".join(
                    [
                        slug(course.title, "course"),
                        "workbook",
                        f"{slug(r.lesson_ref)}-{slug(r.lesson_title, 'lesson')}",
                    ]
                ),
                zip_name=slug(r.ref, "row"),
                order=(1, course.order_index, r.lesson_ref, r.ref),
                course_id=r.course_id,
                course_title=course.title,
                lesson=r.lesson_title,
                text=r.text,
                english=r.english,
            ),
        )

    for letter in await repo.letters():
        for place, url, word in (
            (SOUND, letter.audio_url, None),
            (SOUND_EXAMPLE, letter.example_audio_url, letter.example_word),
        ):
            group, sound = slug(letter.group_key, "group"), slug(letter.romanization, "letter")
            name = f"{group}-{letter.position:02d}-{sound}"
            found.add(
                url,
                prefix,
                Use(
                    place=place,
                    language=letter.language,
                    admin_path=f"/sounds/{letter.language}/letters/{letter.id}",
                    zip_dir=f"sounds/{slug(letter.language)}",
                    zip_name=f"{name}-{'sound' if place == SOUND else 'example'}",
                    order=(2, letter.language, letter.group_key, letter.position, place),
                    letter=letter.glyph,
                    text=word,
                ),
            )
    for uses in found.by_key.values():
        uses.sort(key=lambda u: u.order)
    return found


async def load_library(
    repo: SqlAlchemyAudioLibraryRepository, library: MediaLibrary, *, now: datetime
) -> Library:
    courses = await repo.courses()
    uses = await _uses(repo, library.public_prefix, courses)
    stored = [f for f in await library.list_files() if is_audio(f.key)]

    files, trash = [], []
    for f in stored:
        if f.key.startswith(TRASH_PREFIX):
            trash.append(TrashFile(f.key, f.key[len(TRASH_PREFIX) :], f.size, f.uploaded_at))
            continue
        used = uses.by_key.get(f.key, [])
        name = f.key.rsplit("/", 1)[-1]
        files.append(
            LibraryFile(
                key=f.key,
                url=library.public_url(f.key),
                size=f.size,
                uploaded_at=f.uploaded_at,
                language=f.key.split("/", 1)[0] if "/" in f.key else "",
                source="generated" if name.startswith("gen-") else "recorded",
                uses=used,
                can_trash=not used and now - f.uploaded_at > TRASH_AFTER,
            )
        )
    keys = {f.key for f in files}
    missing = [
        MissingFile(key, library.public_url(key), used)
        for key, used in sorted(uses.by_key.items(), key=lambda kv: kv[1][0].order)
        if key not in keys
    ]
    files.sort(key=lambda f: (f.uploaded_at, f.key), reverse=True)
    trash.sort(key=lambda f: (f.moved_at, f.key), reverse=True)
    return Library(library.name, files, missing, trash, uses.external, courses)


def _clean_keys(keys: list[str]) -> list[str]:
    unique = list(dict.fromkeys(k.strip() for k in keys))
    if not unique or len(unique) > MAX_KEYS:
        raise InvalidContentError("keys", f"Send between 1 and {MAX_KEYS} keys")
    return unique


def _log(action: str, key: str, email: str) -> None:
    logger.info("admin_write action=%s entity=audio_file id=%s admin=%s", action, key, email)


async def trash_files(
    repo: SqlAlchemyAudioLibraryRepository,
    library: MediaLibrary,
    keys: list[str],
    *,
    email: str,
    now: datetime,
) -> int:
    """Moves unused files to the trash; all of them or none."""
    wanted = _clean_keys(keys)
    lib = await load_library(repo, library, now=now)
    files = {f.key: f for f in lib.files}
    unknown = [k for k in wanted if k not in files]
    if unknown:
        raise AudioFileNotFoundError("No stored file has this key", keys=unknown)
    blocked = [k for k in wanted if not files[k].can_trash]
    if blocked:
        raise AudioFileInUseError(
            "Only files nothing uses, uploaded more than a day ago, can go to the trash",
            keys=blocked,
        )
    for key in wanted:
        await library.move(key, f"{TRASH_PREFIX}{key}")
        _log("trash", key, email)
    note_activity(files=len(wanted))
    return len(wanted)


async def _trashed(library: MediaLibrary, keys: list[str]) -> list[str]:
    wanted = _clean_keys(keys)
    there = {f.key for f in await library.list_files(TRASH_PREFIX)}
    unknown = [k for k in wanted if not k.startswith(TRASH_PREFIX) or k not in there]
    if unknown:
        raise AudioFileNotFoundError("No file in the trash has this key", keys=unknown)
    return wanted


async def restore_files(library: MediaLibrary, keys: list[str], *, email: str) -> int:
    wanted = await _trashed(library, keys)
    stored = {f.key for f in await library.list_files()}
    taken = [k for k in wanted if k[len(TRASH_PREFIX) :] in stored]
    if taken:
        raise AudioFileExistsError("A file is already saved under this key", keys=taken)
    for key in wanted:
        await library.move(key, key[len(TRASH_PREFIX) :])
        _log("restore", key, email)
    note_activity(files=len(wanted))
    return len(wanted)


async def delete_files(library: MediaLibrary, keys: list[str], *, email: str) -> int:
    """Deletes trashed files for good. Only ever inside `trash/`."""
    wanted = await _trashed(library, keys)
    for key in wanted:
        await library.delete(key)
        _log("delete", key, email)
    note_activity(files=len(wanted))
    return len(wanted)


# --- Export (FR-5) -----------------------------------------------------------


@dataclass(frozen=True)
class ExportFile:
    zip_path: str
    key: str
    size: int
    download_url: str


@dataclass(frozen=True)
class ExportRow:
    zip_path: str
    status: str
    key: str
    url: str
    size: int | None
    uploaded_at: datetime | None
    use: Use | None


@dataclass(frozen=True)
class Export:
    name: str
    files: list[ExportFile]
    rows: list[ExportRow]


def _ext(key: str) -> str:
    return key.rsplit(".", 1)[-1].lower()


def _short(key: str) -> str:
    stem = key.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    return stem[-6:]


async def export(
    repo: SqlAlchemyAudioLibraryRepository,
    library: MediaLibrary,
    *,
    course_id: str | None,
    include_unused: bool,
    now: datetime,
) -> Export:
    lib = await load_library(repo, library, now=now)
    course: CourseRow | None = None
    if course_id:
        course = next((c for c in lib.courses if c.id == course_id), None)
        if course is None:
            raise ContentNotFoundError("No such course", entity="course", id=course_id)

    def in_scope(use: Use) -> bool:
        if course is None:
            return True
        if use.place in (SOUND, SOUND_EXAMPLE):
            return use.language == course.learning_language
        return use.course_id == course.id

    files: list[ExportFile] = []
    rows: list[ExportRow] = []
    taken: set[str] = set()

    def unique(path: str) -> str:
        base, n = path, 2
        while path in taken:
            stem, ext = base.rsplit(".", 1)
            path, n = f"{stem}-{n}.{ext}", n + 1
        taken.add(path)
        return path

    chosen: list[tuple[tuple[Any, ...], LibraryFile, list[Use]]] = []
    for f in lib.files:
        uses = [u for u in f.uses if in_scope(u)]
        if uses:
            chosen.append((uses[0].order, f, uses))
        elif (
            include_unused
            and not f.uses
            and (course is None or f.language == course.learning_language)
        ):
            chosen.append(((3, f.language, f.key), f, []))
    chosen.sort(key=lambda c: c[0])

    for _, f, uses in chosen:
        if uses:
            first = uses[0]
            path = unique(f"{first.zip_dir}/{first.zip_name}-{_short(f.key)}.{_ext(f.key)}")
        else:
            path = unique(f"unused/{slug(f.language, 'other')}/{f.key.rsplit('/', 1)[-1]}")
        files.append(ExportFile(path, f.key, f.size, library.download_url(f.key)))
        row_uses: list[Use | None] = list(uses) or [None]
        for use in row_uses:
            rows.append(ExportRow(path, f.status, f.key, f.url, f.size, f.uploaded_at, use))

    for m in lib.missing:
        for use in m.uses:
            if in_scope(use):
                rows.append(ExportRow("", "missing", m.key, m.url, None, None, use))

    name = slug(course.title, "course") if course else "all"
    return Export(f"buna-audio-{name}-{now.date().isoformat()}", files, rows)
