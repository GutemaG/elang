"""The Sounds tab: charts of a language's letters and their recordings.

Admins make and fill a chart on the admin site (`/api/v1/admin/sound-charts`)
and turn it on; the app reads the charts that are on
(`/api/v1/sound-charts`). Every write raises the chart's `version`, which
the app and HTTP caches use to tell an unchanged chart from a newer one.
A chart that is on must stay complete (`missing_for_learners`): a write
that would leave learners a gap is refused and saves nothing.
"""

from __future__ import annotations

import logging
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from app.application.admin_audio_use_cases import (
    AUDIO_TYPES,
    MAX_UPLOAD_BYTES,
    UPLOAD_LINK_SECONDS,
    AudioStore,
)
from app.application.admin_content_use_cases import AdminContext
from app.domain.lesson.exceptions import (
    AudioStorageNotConfiguredError,
    ContentExistsError,
    ContentInUseError,
    ContentNotFoundError,
    InvalidContentError,
    SoundChartIncompleteError,
)
from app.domain.sounds import (
    LETTER_STATUSES,
    MAX_EXAMPLE,
    MAX_GLYPH,
    MAX_GROUP_NAME,
    MAX_HINT,
    MAX_MEANING,
    MAX_RECORDED_BY,
    MAX_ROMANIZATION,
    TEMPLATES,
    Gaps,
    LetterFacts,
    chart_template,
    missing_for_learners,
)
from app.domain.value_objects import LANGUAGE_CODE_PATTERN
from app.infrastructure.db.sound_models import SoundChartModel, SoundLetterModel
from app.infrastructure.db.sound_repository import SqlAlchemySoundRepository
from app.infrastructure.external.r2_storage import PresignedUpload

logger = logging.getLogger("app.admin")

# What `update_letter` may change, and what a new letter may carry.
LETTER_FIELDS = (
    "glyph",
    "romanization",
    "hint",
    "audio_url",
    "same_as_id",
    "example_word",
    "example_romanization",
    "example_meaning",
    "example_audio_url",
    "status",
    "recorded_by",
)


def _log(ctx: AdminContext, action: str, entity: str, entity_id: str) -> None:
    logger.info(
        "admin_write action=%s entity=%s id=%s admin=%s", action, entity, entity_id, ctx.email
    )


def _now() -> datetime:
    return datetime.now(UTC)


# --- checking input -----------------------------------------------------------


def _text(field: str, value: Any, limit: int, *, required: bool = False) -> str | None:
    if value is None:
        if required:
            raise InvalidContentError(field, f"{field} is required")
        return None
    if not isinstance(value, str):
        raise InvalidContentError(field, f"{field} must be text")
    cleaned = value.strip()
    if required and not cleaned:
        raise InvalidContentError(field, f"{field} must not be empty")
    if len(cleaned) > limit:
        raise InvalidContentError(field, f"{field} must be at most {limit} characters")
    return cleaned or None


def _localized(field: str, value: Any, limit: int) -> dict[str, str]:
    """Text by app language, e.g. {"en": "...", "am": "..."}. Empty entries
    are dropped."""
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise InvalidContentError(field, f"{field} must map language codes to text")
    cleaned: dict[str, str] = {}
    for code, text in value.items():
        if not isinstance(code, str) or not LANGUAGE_CODE_PATTERN.match(code):
            raise InvalidContentError(field, f"{field} has an unknown language code {code!r}")
        item = _text(f"{field}.{code}", text, limit)
        if item:
            cleaned[code] = item
    return cleaned


def _audio(field: str, value: Any, ctx: AdminContext) -> str | None:
    url = _text(field, value, 1024)
    if url is None:
        return None
    if url.startswith("https://") and len(url) > len("https://"):
        return url
    # Local development plays uploads the backend itself serves.
    if ctx.allow_local_media and url.startswith("/media/audio/"):
        return url
    raise InvalidContentError(field, f"{field} must be an https address")


# --- reading ---------------------------------------------------------------------


async def _chart_or_404(repo: SqlAlchemySoundRepository, language: str) -> SoundChartModel:
    chart = await repo.chart(language)
    if chart is None:
        raise ContentNotFoundError(
            "This language has no sounds chart", entity="sound_chart", id=language
        )
    return chart


def ordered(chart: SoundChartModel, letters: list[SoundLetterModel]) -> list[SoundLetterModel]:
    """Letters in the chart's group order, then position."""
    rank = {group["key"]: i for i, group in enumerate(chart.groups)}
    return sorted(letters, key=lambda r: (rank.get(r.group_key, len(rank)), r.position))


def gaps_of(letters: list[SoundLetterModel]) -> Gaps:
    return missing_for_learners(
        [
            LetterFacts(
                id=r.id,
                romanization=r.romanization,
                has_audio=bool(r.audio_url),
                same_as_id=r.same_as_id,
            )
            for r in letters
        ]
    )


@dataclass(frozen=True)
class ChartCounts:
    letters: int
    ready: int
    needs_review: int
    draft: int
    # Letters that need a recording of their own and have none.
    needs_recording: int
    same_sound: int


def counts_of(letters: list[SoundLetterModel]) -> ChartCounts:
    return ChartCounts(
        letters=len(letters),
        ready=sum(1 for r in letters if r.status == "ready"),
        needs_review=sum(1 for r in letters if r.status == "needs_review"),
        draft=sum(1 for r in letters if r.status == "draft"),
        needs_recording=sum(1 for r in letters if not r.same_as_id and not r.audio_url),
        same_sound=sum(1 for r in letters if r.same_as_id),
    )


@dataclass(frozen=True)
class AdminChart:
    chart: SoundChartModel
    letters: list[SoundLetterModel]
    language_name: str
    counts: ChartCounts
    gaps: Gaps


async def _admin_chart(repo: SqlAlchemySoundRepository, chart: SoundChartModel) -> AdminChart:
    letters = ordered(chart, await repo.letters(chart.language))
    language = await repo.language(chart.language)
    return AdminChart(
        chart=chart,
        letters=letters,
        language_name=language.name if language else chart.language,
        counts=counts_of(letters),
        gaps=gaps_of(letters),
    )


async def list_charts(repo: SqlAlchemySoundRepository) -> list[AdminChart]:
    return [await _admin_chart(repo, chart) for chart in await repo.charts()]


async def get_chart(repo: SqlAlchemySoundRepository, language: str) -> AdminChart:
    return await _admin_chart(repo, await _chart_or_404(repo, language))


# --- charts -------------------------------------------------------------------------


def _touch(chart: SoundChartModel) -> None:
    chart.version += 1
    chart.updated_at = _now()


async def _keep_complete(repo: SqlAlchemySoundRepository, chart: SoundChartModel) -> None:
    """Refuses a write that would leave a chart learners see with gaps.
    Raised before the request's transaction commits, so nothing is saved."""
    if not chart.enabled:
        return
    gaps = gaps_of(await repo.letters(chart.language))
    if gaps.any:
        raise SoundChartIncompleteError(
            "Learners can see this chart, so every letter needs its romanization "
            "and every sound its recording",
            no_letters=gaps.no_letters,
            no_romanization=gaps.no_romanization,
            no_audio=gaps.no_audio,
        )


async def create_chart(
    repo: SqlAlchemySoundRepository, ctx: AdminContext, *, language: str, template: str
) -> AdminChart:
    """A new, hidden chart for a language, filled from a template."""
    language = (language or "").strip().lower()
    if await repo.language(language) is None:
        raise ContentNotFoundError("No such language", entity="language", id=language)
    if template not in TEMPLATES:
        raise InvalidContentError("template", f"template must be one of: {', '.join(TEMPLATES)}")
    if await repo.chart(language) is not None:
        raise ContentExistsError(f"{language!r} already has a sounds chart", language=language)

    shape = chart_template(template)
    chart = SoundChartModel(
        language=language,
        title=dict(shape.title),
        groups=[
            {
                "key": g.key,
                "names": dict(g.names),
                "columns": g.columns,
                "column_labels": list(g.column_labels),
            }
            for g in shape.groups
        ],
        enabled=False,
        version=1,
    )
    await repo.add(chart)

    positions: dict[str, int] = {}
    rows: list[SoundLetterModel] = []
    by_glyph: dict[str, SoundLetterModel] = {}
    for letter in shape.letters:
        position = positions.get(letter.group, 0)
        positions[letter.group] = position + 1
        row = SoundLetterModel(
            # Set here, not on insert: other rows' `same_as` needs it.
            id=_new_id(),
            language=language,
            group_key=letter.group,
            position=position,
            glyph=letter.glyph,
            romanization=letter.romanization,
            hint=dict(letter.hint),
            example_meaning={},
            status="draft",
        )
        rows.append(row)
        by_glyph[letter.glyph] = row
    await repo.add_all(rows)
    # Linked once every row exists: a letter may share the sound of one
    # later in the chart (ሠ comes before ሰ), and the database checks the
    # link as each row goes in.
    for letter, row in zip(shape.letters, rows, strict=True):
        if letter.same_as is not None:
            row.same_as_id = by_glyph[letter.same_as].id
    await repo.flush()
    _log(ctx, "create", "sound_chart", language)
    return await _admin_chart(repo, chart)


def _new_id() -> str:
    return str(uuid.uuid4())


async def update_chart(
    repo: SqlAlchemySoundRepository,
    ctx: AdminContext,
    language: str,
    *,
    enabled: bool | None = None,
    title: dict[str, str] | None = None,
    group_names: dict[str, dict[str, str]] | None = None,
) -> AdminChart:
    """Turns a chart on or off, or renames it or its groups. Turning it on
    is refused while it has gaps."""
    chart = await _chart_or_404(repo, language)
    if title is not None:
        cleaned = _localized("title", title, MAX_GROUP_NAME)
        if "en" not in cleaned:
            raise InvalidContentError("title", "title needs an English name")
        chart.title = cleaned
    if group_names is not None:
        groups = [dict(g) for g in chart.groups]
        known = {g["key"]: g for g in groups}
        for key, names in group_names.items():
            if key not in known:
                raise InvalidContentError("group_names", f"there is no group {key!r}")
            cleaned = _localized(f"group_names.{key}", names, MAX_GROUP_NAME)
            if "en" not in cleaned:
                raise InvalidContentError(f"group_names.{key}", "a group needs an English name")
            known[key]["names"] = cleaned
        chart.groups = groups
    if enabled is not None:
        chart.enabled = enabled
    _touch(chart)
    await repo.flush()
    await _keep_complete(repo, chart)
    _log(ctx, "update", "sound_chart", language)
    return await _admin_chart(repo, chart)


async def delete_chart(repo: SqlAlchemySoundRepository, ctx: AdminContext, language: str) -> None:
    """Only a chart learners cannot see may go."""
    chart = await _chart_or_404(repo, language)
    if chart.enabled:
        raise ContentInUseError("Turn the chart off before deleting it")
    await repo.delete_chart(chart)
    _log(ctx, "delete", "sound_chart", language)


# --- letters ---------------------------------------------------------------------------


async def _apply(
    repo: SqlAlchemySoundRepository,
    ctx: AdminContext,
    chart: SoundChartModel,
    letter: SoundLetterModel,
    changes: dict[str, Any],
    *,
    where: str = "",
) -> None:
    unknown = set(changes) - set(LETTER_FIELDS)
    if unknown:
        raise InvalidContentError(where + sorted(unknown)[0], "this field cannot be changed")

    def f(name: str) -> str:
        return where + name

    if "glyph" in changes:
        letter.glyph = _text(f("glyph"), changes["glyph"], MAX_GLYPH, required=True) or ""
    if "romanization" in changes:
        letter.romanization = (
            _text(f("romanization"), changes["romanization"], MAX_ROMANIZATION) or ""
        )
    if "hint" in changes:
        letter.hint = _localized(f("hint"), changes["hint"], MAX_HINT)
    if "audio_url" in changes:
        letter.audio_url = _audio(f("audio_url"), changes["audio_url"], ctx)
    if "example_word" in changes:
        letter.example_word = _text(f("example_word"), changes["example_word"], MAX_EXAMPLE)
    if "example_romanization" in changes:
        letter.example_romanization = _text(
            f("example_romanization"), changes["example_romanization"], MAX_EXAMPLE
        )
    if "example_meaning" in changes:
        letter.example_meaning = _localized(
            f("example_meaning"), changes["example_meaning"], MAX_MEANING
        )
    if "example_audio_url" in changes:
        letter.example_audio_url = _audio(f("example_audio_url"), changes["example_audio_url"], ctx)
    if "status" in changes:
        if changes["status"] not in LETTER_STATUSES:
            raise InvalidContentError(
                f("status"), f"status must be one of: {', '.join(LETTER_STATUSES)}"
            )
        letter.status = changes["status"]
    if "recorded_by" in changes:
        letter.recorded_by = _text(f("recorded_by"), changes["recorded_by"], MAX_RECORDED_BY)
    if "same_as_id" in changes:
        letter.same_as_id = await _same_as(
            repo, chart, letter, changes["same_as_id"], f("same_as_id")
        )
    letter.updated_at = _now()


async def _same_as(
    repo: SqlAlchemySoundRepository,
    chart: SoundChartModel,
    letter: SoundLetterModel,
    value: Any,
    field: str,
) -> str | None:
    """Another letter of this chart that has a sound of its own. One step
    only: a letter others point at cannot point elsewhere itself."""
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        raise InvalidContentError(field, "same_as_id must be a letter id")
    if value == letter.id:
        raise InvalidContentError(field, "a letter cannot sound the same as itself")
    target = await repo.letter(value)
    if target is None or target.language != chart.language:
        raise InvalidContentError(field, "same_as_id must be a letter of this chart")
    if target.same_as_id is not None:
        raise InvalidContentError(field, "point at the letter with its own recording instead")
    letters = await repo.letters(chart.language)
    if any(other.same_as_id == letter.id for other in letters):
        raise InvalidContentError(
            field, "other letters share this letter's sound, so it needs its own"
        )
    return target.id


async def _letter_of(
    repo: SqlAlchemySoundRepository, chart: SoundChartModel, letter_id: str
) -> SoundLetterModel:
    letter = await repo.letter(letter_id)
    if letter is None or letter.language != chart.language:
        raise ContentNotFoundError(
            "No such letter in this chart", entity="sound_letter", id=letter_id
        )
    return letter


async def add_letter(
    repo: SqlAlchemySoundRepository,
    ctx: AdminContext,
    language: str,
    *,
    group: str,
    fields: dict[str, Any],
) -> SoundLetterModel:
    """A new letter at the end of `group`."""
    chart = await _chart_or_404(repo, language)
    if group not in {g["key"] for g in chart.groups}:
        raise InvalidContentError("group", f"there is no group {group!r}")
    letter = SoundLetterModel(
        id=_new_id(),
        language=language,
        group_key=group,
        position=await repo.next_position(language, group),
        glyph="",
        romanization="",
        hint={},
        example_meaning={},
        status="draft",
    )
    await _apply(repo, ctx, chart, letter, {"glyph": None, **fields})
    await repo.add(letter)
    _touch(chart)
    await repo.flush()
    await _keep_complete(repo, chart)
    _log(ctx, "create", "sound_letter", letter.id)
    return letter


async def update_letters(
    repo: SqlAlchemySoundRepository,
    ctx: AdminContext,
    language: str,
    updates: list[dict[str, Any]],
) -> AdminChart:
    """Changes several letters at once (an import, an upload of many files,
    or one letter's form). All or nothing: one bad change saves none, and
    names its place as `letters[i].field`."""
    chart = await _chart_or_404(repo, language)
    if not updates:
        raise InvalidContentError("letters", "nothing to change")
    for i, update in enumerate(updates):
        where = f"letters[{i}]."
        letter_id = update.get("id")
        if not isinstance(letter_id, str):
            raise InvalidContentError(where + "id", "each change needs the letter's id")
        letter = await _letter_of(repo, chart, letter_id)
        changes = {k: v for k, v in update.items() if k != "id"}
        await _apply(repo, ctx, chart, letter, changes, where=where)
        await repo.flush()
    _touch(chart)
    await repo.flush()
    await _keep_complete(repo, chart)
    _log(ctx, "update", "sound_letters", f"{language}:{len(updates)}")
    return await _admin_chart(repo, chart)


async def delete_letter(
    repo: SqlAlchemySoundRepository, ctx: AdminContext, language: str, letter_id: str
) -> None:
    chart = await _chart_or_404(repo, language)
    letter = await _letter_of(repo, chart, letter_id)
    others = [r for r in await repo.letters(language) if r.same_as_id == letter.id]
    if others:
        raise ContentInUseError(
            f"{len(others)} letter(s) share this letter's sound; change them first",
            letters=len(others),
        )
    await repo.delete(letter)
    _touch(chart)
    await repo.flush()
    await _keep_complete(repo, chart)
    _log(ctx, "delete", "sound_letter", letter_id)


async def presign_upload(
    repo: SqlAlchemySoundRepository,
    ctx: AdminContext,
    storage: AudioStore | None,
    language: str,
    *,
    content_type: str,
    size: int,
) -> tuple[str, PresignedUpload]:
    """A PUT link for one recording of this chart. Keys are new for every
    upload, so a recording's address never changes what it plays and can be
    cached for good."""
    base_type = content_type.split(";")[0].strip().lower()
    if base_type not in AUDIO_TYPES:
        raise InvalidContentError(
            "content_type", f"Audio must be one of: {', '.join(sorted(AUDIO_TYPES))}"
        )
    if not 0 < size <= MAX_UPLOAD_BYTES:
        raise InvalidContentError("size", "Audio must be between 1 byte and 5 MB")
    if storage is None:
        raise AudioStorageNotConfiguredError("Audio storage is not configured on this server")
    await _chart_or_404(repo, language)
    key = f"{language}/sounds/{secrets.token_hex(6)}.{AUDIO_TYPES[base_type]}"
    upload = storage.presign_put(
        key, content_type=base_type, size=size, expires_in=UPLOAD_LINK_SECONDS
    )
    _log(ctx, "presign", "sound_audio", key)
    return key, upload


# --- what the app reads ---------------------------------------------------------------


@dataclass(frozen=True)
class PublishedChart:
    chart: SoundChartModel
    letter_count: int
    icon: str


def icon_of(letters: list[SoundLetterModel]) -> str:
    """The chart's first letter, spaces dropped and at most two characters:
    ሀ for the Fidel, "Aa" for Qubee's "A a"."""
    if not letters:
        return ""
    return "".join(letters[0].glyph.split())[:2]


async def published_charts(repo: SqlAlchemySoundRepository) -> list[PublishedChart]:
    """The charts that are on, with their letter counts and icons."""
    out: list[PublishedChart] = []
    for chart in await repo.charts(enabled_only=True):
        letters = ordered(chart, await repo.letters(chart.language))
        out.append(PublishedChart(chart=chart, letter_count=len(letters), icon=icon_of(letters)))
    return out


async def published_chart(
    repo: SqlAlchemySoundRepository, language: str
) -> tuple[SoundChartModel, list[SoundLetterModel]]:
    """A chart that is on, with its letters in order. One that is off is
    not found, exactly like one that does not exist."""
    chart = await repo.chart(language)
    if chart is None or not chart.enabled:
        raise ContentNotFoundError(
            "This language has no sounds chart", entity="sound_chart", id=language
        )
    return chart, ordered(chart, await repo.letters(language))
