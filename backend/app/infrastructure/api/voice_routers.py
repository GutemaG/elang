"""Generated voices (intent 027), admin only:

- `GET /api/v1/admin/voice/settings`: each language's voices and speed.
- `PUT /api/v1/admin/voice/settings/{language}`: change one language's.
- `GET /api/v1/admin/voice/voices?language=`: the voices Addis offers now.
- `GET /api/v1/admin/voice/usage`: the Addis credit left.
- `POST /api/v1/admin/voice/generate`: an mp3 take of a text, not stored.
"""

from __future__ import annotations

from urllib.parse import quote

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import voice_use_cases as uc
from app.application.admin_content_use_cases import AdminContext
from app.config import get_settings
from app.domain.entities import User
from app.domain.lesson.exceptions import VoiceNotConfiguredError
from app.infrastructure.api.dependencies import require_admin
from app.infrastructure.api.voice_schemas import (
    AdminVoiceCatalogResponse,
    AdminVoiceLanguageResponse,
    AdminVoiceOption,
    AdminVoiceSettingsResponse,
    AdminVoiceUsageResponse,
    GenerateVoiceRequest,
    UpdateVoiceSettingsRequest,
)
from app.infrastructure.db.admin_content_repository import SqlAlchemyAdminContentRepository
from app.infrastructure.db.session import get_db_session
from app.infrastructure.db.voice_settings_repository import SqlAlchemyVoiceSettingsRepository
from app.infrastructure.external.addis_voice_client import AddisVoice, AddisVoiceClient

# What a take's response tells the admin besides the audio. Exposed to
# the admin site's origin by the CORS setup in `app/main.py`.
VOICE_HEADERS = ["X-Voice-Id", "X-Voice-Name", "X-Duration-Seconds", "X-Credits-Remaining"]

admin_router = APIRouter(
    prefix="/api/v1/admin/voice", tags=["admin"], dependencies=[Depends(require_admin)]
)


async def _repo(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyVoiceSettingsRepository:
    return SqlAlchemyVoiceSettingsRepository(session)


async def _ctx(admin: User = Depends(require_admin)) -> AdminContext:
    return AdminContext(email=admin.email or "")


def voice_generation_configured() -> bool:
    """Whether this server can generate audio: an Addis AI key is set."""
    return bool(get_settings().addis_api_key.strip())


def get_addis_voice_client() -> AddisVoiceClient | None:
    """Overridable in tests, which never reach Addis. None without a key."""
    settings = get_settings()
    key = settings.addis_api_key.strip()
    if not key:
        return None
    return AddisVoiceClient(
        key, base_url=settings.addis_api_base_url, timeout=settings.addis_timeout_seconds
    )


# Shared by every request this process serves (FR-6: one Addis call per
# language per 10 minutes).
voice_catalog = uc.VoiceCatalog()


def _client(
    client: AddisVoiceClient | None = Depends(get_addis_voice_client),
) -> AddisVoiceClient:
    if client is None:
        raise VoiceNotConfiguredError("Generated voices aren't set up on this server.")
    return client


def _language(v: uc.AdminVoiceLanguage) -> AdminVoiceLanguageResponse:
    s = v.settings
    return AdminVoiceLanguageResponse(
        language=s.language,
        language_name=v.language_name,
        male_voice_id=s.male_voice_id,
        female_voice_id=s.female_voice_id,
        speed=s.speed,
        updated_by=s.updated_by,
        updated_at=s.updated_at,
    )


@admin_router.get("/settings", response_model=AdminVoiceSettingsResponse)
async def admin_get_voice_settings(
    repo: SqlAlchemyVoiceSettingsRepository = Depends(_repo),
    configured: bool = Depends(voice_generation_configured),
) -> AdminVoiceSettingsResponse:
    result = await uc.list_voice_settings(repo, configured=configured)
    return AdminVoiceSettingsResponse(
        configured=result.configured, languages=[_language(v) for v in result.languages]
    )


@admin_router.put("/settings/{language}", response_model=AdminVoiceLanguageResponse)
async def admin_update_voice_settings(
    language: str,
    body: UpdateVoiceSettingsRequest,
    repo: SqlAlchemyVoiceSettingsRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
    client: AddisVoiceClient | None = Depends(get_addis_voice_client),
) -> AdminVoiceLanguageResponse:
    voices: uc.AvailableVoices | None = None
    if client is not None:
        source = client

        async def offered() -> list[AddisVoice]:
            return await voice_catalog.available(source, language)

        voices = offered
    return _language(
        await uc.update_voice_settings(
            repo,
            ctx,
            language,
            male_voice_id=body.male_voice_id,
            female_voice_id=body.female_voice_id,
            speed=body.speed,
            voices=voices,
        )
    )


@admin_router.get("/voices", response_model=AdminVoiceCatalogResponse)
async def admin_list_voices(
    language: str = Query(...),
    client: AddisVoiceClient = Depends(_client),
) -> AdminVoiceCatalogResponse:
    voices = await uc.list_voice_options(client, voice_catalog, language)
    return AdminVoiceCatalogResponse(
        language=language,
        voices=[
            AdminVoiceOption(
                id=v.id,
                name=v.name,
                descriptor=v.descriptor,
                gender=v.gender,
                style=v.style,
                preview_audio_url=v.preview_audio_url,
            )
            for v in voices
        ],
    )


@admin_router.get("/usage", response_model=AdminVoiceUsageResponse)
async def admin_voice_usage(
    client: AddisVoiceClient = Depends(_client),
) -> AdminVoiceUsageResponse:
    u = await uc.get_voice_usage(client)
    return AdminVoiceUsageResponse(
        balance=u.balance,
        currency=u.currency,
        formatted_balance=u.formatted_balance,
        price_per_minute=u.price_per_minute,
        max_characters=u.max_characters,
    )


@admin_router.post("/generate", response_class=Response)
async def admin_generate_voice(
    body: GenerateVoiceRequest,
    repo: SqlAlchemyVoiceSettingsRepository = Depends(_repo),
    session: AsyncSession = Depends(get_db_session),
    ctx: AdminContext = Depends(_ctx),
    client: AddisVoiceClient | None = Depends(get_addis_voice_client),
) -> Response:
    take = await uc.generate_voice(
        repo,
        SqlAlchemyAdminContentRepository(session),
        client,
        ctx,
        text=body.text,
        gender=body.gender,
        language=body.language,
        lesson_id=body.lesson_id,
        speed=body.speed,
        voice_id=body.voice_id,
    )
    clip = take.clip
    remaining = "" if clip.credits_remaining is None else f"{clip.credits_remaining:g}"
    return Response(
        content=clip.audio,
        media_type="audio/mpeg",
        headers={
            "X-Voice-Id": take.voice_id,
            "X-Voice-Name": quote(clip.voice_name),
            "X-Duration-Seconds": f"{clip.duration_seconds:g}",
            "X-Credits-Remaining": remaining,
            "Cache-Control": "no-store",
        },
    )
