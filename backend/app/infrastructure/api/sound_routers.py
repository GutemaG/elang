"""The Sounds tab's endpoints.

- `GET /api/v1/sound-charts` and `GET /api/v1/sound-charts/{language}`: the
  charts that are on, for the app. No sign-in, like the course catalog:
  letters and recordings are the same for everyone. Both carry an `ETag`
  built from the charts' versions and answer `304 Not Modified` to a
  matching `If-None-Match`, and say how long a copy may be reused, so the
  app, Vercel's edge and any proxy can all keep one.
- `/api/v1/admin/sound-charts/...`: making and filling charts, admin only.
"""

from __future__ import annotations

import hashlib

from fastapi import APIRouter, Depends, Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import sound_use_cases as uc
from app.application.admin_content_use_cases import AdminContext
from app.config import get_settings
from app.domain.entities import User
from app.infrastructure.api.admin_routers import get_audio_storage
from app.infrastructure.api.admin_schemas import AudioUploadResponse
from app.infrastructure.api.dependencies import require_admin
from app.infrastructure.api.sound_schemas import (
    AdminSoundChart,
    AdminSoundChartList,
    AdminSoundChartSummary,
    AdminSoundCounts,
    AdminSoundGaps,
    AdminSoundGroup,
    AdminSoundLetter,
    CreateSoundChartRequest,
    CreateSoundLetterRequest,
    SoundChart,
    SoundChartIndex,
    SoundChartSummary,
    SoundExample,
    SoundGroup,
    SoundLetter,
    SoundUploadRequest,
    UpdateSoundChartRequest,
    UpdateSoundLettersRequest,
)
from app.infrastructure.db.session import get_db_session
from app.infrastructure.db.sound_models import SoundChartModel, SoundLetterModel
from app.infrastructure.db.sound_repository import SqlAlchemySoundRepository
from app.infrastructure.external.local_audio_storage import LocalAudioStorage
from app.infrastructure.external.r2_storage import R2Storage

router = APIRouter(prefix="/api/v1", tags=["sounds"])
admin_router = APIRouter(
    prefix="/api/v1/admin", tags=["admin"], dependencies=[Depends(require_admin)]
)

# A copy may be used for a minute without asking, shared caches may keep it
# five, and either may show an old copy for a day while they check for a
# newer one. A chart changes rarely, and a stale one is still correct.
CACHE_CONTROL = "public, max-age=60, s-maxage=300, stale-while-revalidate=86400"


async def _repo(session: AsyncSession = Depends(get_db_session)) -> SqlAlchemySoundRepository:
    return SqlAlchemySoundRepository(session)


async def _ctx(admin: User = Depends(require_admin)) -> AdminContext:
    return AdminContext(
        email=admin.email or "", allow_local_media=get_settings().environment == "local"
    )


def _matches(request: Request, etag: str) -> bool:
    header = request.headers.get("if-none-match")
    if not header:
        return False
    if header.strip() == "*":
        return True
    tags = {tag.strip().removeprefix("W/") for tag in header.split(",")}
    return etag in tags


def _cached(request: Request, etag: str, body: object) -> Response:
    headers = {"ETag": etag, "Cache-Control": CACHE_CONTROL}
    if _matches(request, etag):
        return Response(status_code=304, headers=headers)
    return JSONResponse(content=body, headers=headers)


# --- what the app reads ---------------------------------------------------------------


@router.get("/sound-charts", response_model=SoundChartIndex)
async def list_sound_charts(
    request: Request, repo: SqlAlchemySoundRepository = Depends(_repo)
) -> Response:
    """The charts learners can open, so the app knows which courses get a
    Sounds tab and whether its saved copy of each is current."""
    charts = await uc.published_charts(repo)
    body = SoundChartIndex(
        charts=[
            SoundChartSummary(
                language=p.chart.language,
                title=p.chart.title,
                version=p.chart.version,
                letter_count=p.letter_count,
                icon=p.icon,
            )
            for p in charts
        ]
    )
    stamp = ",".join(f"{p.chart.language}:{p.chart.version}" for p in charts)
    etag = f'"charts-{hashlib.sha1(stamp.encode()).hexdigest()[:16]}"'
    return _cached(request, etag, body.model_dump(mode="json"))


def _public_letter(letter: SoundLetterModel, by_id: dict[str, SoundLetterModel]) -> SoundLetter:
    source = by_id.get(letter.same_as_id) if letter.same_as_id else None
    example = None
    if letter.example_word:
        example = SoundExample(
            word=letter.example_word,
            romanization=letter.example_romanization,
            meaning=letter.example_meaning or {},
            audio_url=letter.example_audio_url,
        )
    return SoundLetter(
        id=letter.id,
        glyph=letter.glyph,
        romanization=letter.romanization,
        hint=letter.hint or {},
        audio_url=(source.audio_url if source else letter.audio_url),
        same_as=source.glyph if source else None,
        example=example,
    )


def public_chart(chart: SoundChartModel, letters: list[SoundLetterModel]) -> SoundChart:
    by_id = {r.id: r for r in letters}
    by_group: dict[str, list[SoundLetterModel]] = {}
    for letter in letters:
        by_group.setdefault(letter.group_key, []).append(letter)
    return SoundChart(
        language=chart.language,
        title=chart.title,
        version=chart.version,
        updated_at=chart.updated_at,
        groups=[
            SoundGroup(
                key=g["key"],
                names=g.get("names", {}),
                columns=g.get("columns"),
                column_labels=list(g.get("column_labels") or []),
                letters=[_public_letter(r, by_id) for r in by_group.get(g["key"], [])],
            )
            for g in chart.groups
            if by_group.get(g["key"])
        ],
        credits=sorted({r.recorded_by for r in letters if r.recorded_by}),
    )


@router.get("/sound-charts/{language}", response_model=SoundChart)
async def get_sound_chart(
    language: str, request: Request, repo: SqlAlchemySoundRepository = Depends(_repo)
) -> Response:
    """One chart that is on, with every letter and where its sound plays
    from. `404 content_not_found` when the language has none, or it is off."""
    chart, letters = await uc.published_chart(repo, language)
    etag = f'"sounds-{chart.language}-{chart.version}"'
    if _matches(request, etag):
        return _cached(request, etag, None)
    return _cached(request, etag, public_chart(chart, letters).model_dump(mode="json"))


# --- the admin site ----------------------------------------------------------------------


def _summary(view: uc.AdminChart) -> dict[str, object]:
    c = view.chart
    return {
        "language": c.language,
        "language_name": view.language_name,
        "title": c.title,
        "enabled": c.enabled,
        "version": c.version,
        "updated_at": c.updated_at,
        "counts": AdminSoundCounts(**view.counts.__dict__),
        "gaps": AdminSoundGaps(
            no_letters=view.gaps.no_letters,
            no_romanization=view.gaps.no_romanization,
            no_audio=view.gaps.no_audio,
        ),
    }


def _admin_letter(r: SoundLetterModel) -> AdminSoundLetter:
    return AdminSoundLetter(
        id=r.id,
        group=r.group_key,
        position=r.position,
        glyph=r.glyph,
        romanization=r.romanization,
        hint=r.hint or {},
        audio_url=r.audio_url,
        same_as_id=r.same_as_id,
        example_word=r.example_word,
        example_romanization=r.example_romanization,
        example_meaning=r.example_meaning or {},
        example_audio_url=r.example_audio_url,
        status=r.status,
        recorded_by=r.recorded_by,
        updated_at=r.updated_at,
    )


def _admin_chart(view: uc.AdminChart) -> AdminSoundChart:
    return AdminSoundChart(
        **_summary(view),
        groups=[
            AdminSoundGroup(
                key=g["key"],
                names=g.get("names", {}),
                columns=g.get("columns"),
                column_labels=list(g.get("column_labels") or []),
            )
            for g in view.chart.groups
        ],
        letters=[_admin_letter(r) for r in view.letters],
    )


@admin_router.get("/sound-charts", response_model=AdminSoundChartList)
async def admin_list_sound_charts(
    repo: SqlAlchemySoundRepository = Depends(_repo),
) -> AdminSoundChartList:
    return AdminSoundChartList(
        charts=[AdminSoundChartSummary(**_summary(v)) for v in await uc.list_charts(repo)]
    )


@admin_router.post("/sound-charts", response_model=AdminSoundChart, status_code=201)
async def admin_create_sound_chart(
    body: CreateSoundChartRequest,
    repo: SqlAlchemySoundRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> AdminSoundChart:
    """A new chart, off, filled from a template: `fidel` (the 34 families in
    seven orders and the labialised letters), `qubee` (vowels, consonants
    and letter pairs) or `empty`."""
    return _admin_chart(
        await uc.create_chart(repo, ctx, language=body.language, template=body.template)
    )


@admin_router.get("/sound-charts/{language}", response_model=AdminSoundChart)
async def admin_get_sound_chart(
    language: str, repo: SqlAlchemySoundRepository = Depends(_repo)
) -> AdminSoundChart:
    return _admin_chart(await uc.get_chart(repo, language))


@admin_router.patch("/sound-charts/{language}", response_model=AdminSoundChart)
async def admin_update_sound_chart(
    language: str,
    body: UpdateSoundChartRequest,
    repo: SqlAlchemySoundRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> AdminSoundChart:
    """Turns the chart on or off, or renames it or its groups. Turning it
    on with gaps is `409 sound_chart_incomplete`, counting them."""
    return _admin_chart(
        await uc.update_chart(
            repo,
            ctx,
            language,
            enabled=body.enabled,
            title=body.title,
            group_names=body.group_names,
        )
    )


@admin_router.delete("/sound-charts/{language}", status_code=204)
async def admin_delete_sound_chart(
    language: str,
    repo: SqlAlchemySoundRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_chart(repo, ctx, language)
    return Response(status_code=204)


@admin_router.post(
    "/sound-charts/{language}/letters", response_model=AdminSoundLetter, status_code=201
)
async def admin_add_sound_letter(
    language: str,
    body: CreateSoundLetterRequest,
    repo: SqlAlchemySoundRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> AdminSoundLetter:
    fields = body.model_dump(exclude_unset=True, exclude={"group"})
    return _admin_letter(await uc.add_letter(repo, ctx, language, group=body.group, fields=fields))


@admin_router.patch("/sound-charts/{language}/letters", response_model=AdminSoundChart)
async def admin_update_sound_letters(
    language: str,
    body: UpdateSoundLettersRequest,
    repo: SqlAlchemySoundRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> AdminSoundChart:
    """Changes one or many letters, all or nothing, and returns the chart."""
    return _admin_chart(await uc.update_letters(repo, ctx, language, body.letters))


@admin_router.delete("/sound-charts/{language}/letters/{letter_id}", status_code=204)
async def admin_delete_sound_letter(
    language: str,
    letter_id: str,
    repo: SqlAlchemySoundRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_letter(repo, ctx, language, letter_id)
    return Response(status_code=204)


@admin_router.post(
    "/sound-charts/{language}/audio/uploads",
    response_model=AudioUploadResponse,
    status_code=201,
)
async def admin_create_sound_upload(
    language: str,
    body: SoundUploadRequest,
    repo: SqlAlchemySoundRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
    storage: R2Storage | LocalAudioStorage | None = Depends(get_audio_storage),
) -> AudioUploadResponse:
    """A short-lived PUT link for one recording; save its `public_url` as a
    letter's `audio_url` or `example_audio_url` afterwards."""
    key, upload = await uc.presign_upload(
        repo, ctx, storage, language, content_type=body.content_type, size=body.size
    )
    return AudioUploadResponse(
        upload_url=upload.url,
        headers=upload.headers,
        key=key,
        public_url=upload.public_url,
        expires_in=upload.expires_in,
    )
