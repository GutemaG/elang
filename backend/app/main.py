"""FastAPI application entrypoint: app instance, router registration, and
exception handlers.

Run locally with: `uv run uvicorn app.main:app --reload` (from `backend/`).
"""

from __future__ import annotations

import re
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import Settings, get_settings
from app.infrastructure.api.admin_routers import router as admin_router
from app.infrastructure.api.audio_file_routers import image_router as image_file_router
from app.infrastructure.api.audio_file_routers import router as audio_file_router
from app.infrastructure.api.course_routers import router as course_router
from app.infrastructure.api.error_handlers import register_exception_handlers
from app.infrastructure.api.lesson_routers import router as lesson_router
from app.infrastructure.api.practice_routers import router as practice_router
from app.infrastructure.api.routers import router as auth_router
from app.infrastructure.api.user_routers import router as user_router
from app.infrastructure.external.apple_verifier import AppleTokenVerifier
from app.infrastructure.external.google_verifier import GoogleTokenVerifier
from app.infrastructure.logging_config import configure_logging
from app.infrastructure.media import MEDIA_DIR, MEDIA_URL_PREFIX


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    configure_logging(settings.environment)

    # App-level singletons: both verifiers own long-lived resources (an HTTP
    # client, and for Apple, an in-memory JWKS cache) that must persist across
    # requests, not be rebuilt per-request.
    app.state.google_verifier = GoogleTokenVerifier(client_id=settings.google_oauth_client_id)
    app.state.apple_verifier = AppleTokenVerifier(
        jwks_url=settings.apple_jwks_url,
        issuer=settings.apple_issuer,
        audiences=[settings.apple_bundle_id, settings.apple_services_id],
        cache_ttl_seconds=settings.apple_jwks_cache_ttl_seconds,
    )
    try:
        yield
    finally:
        await app.state.apple_verifier.aclose()


def cors_origins(settings: Settings) -> tuple[list[str], str | None]:
    """`CORS_ALLOWED_ORIGINS` as exact origins plus one pattern.

    An entry with `*` matches one DNS label there: `https://*.vercel.app`
    admits `https://admin-ethio-lang.vercel.app` but not `http://...`,
    `https://a.b.vercel.app` or `https://x.vercel.app.evil.com`. In local
    development any `http://localhost:<port>` is allowed as well, since
    Flutter Web's dev server picks whichever port is free run to run.
    """
    entries = [o.strip().rstrip("/") for o in settings.cors_allowed_origins.split(",") if o.strip()]
    exact = [o for o in entries if "*" not in o]
    patterns = [re.escape(o).replace(r"\*", "[a-z0-9-]+") for o in entries if "*" in o]
    if settings.environment == "local":
        patterns.append(r"http://localhost:\d+")
    return exact, "|".join(f"(?:{p})" for p in patterns) or None


def create_app() -> FastAPI:
    app = FastAPI(title="Buna Auth Service", version="0.1.0", lifespan=lifespan)

    settings = get_settings()
    exact_origins, origin_pattern = cors_origins(settings)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=exact_origins,
        allow_origin_regex=origin_pattern,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(app)
    app.include_router(auth_router)
    app.include_router(lesson_router)
    app.include_router(user_router)
    app.include_router(practice_router)
    app.include_router(course_router)
    app.include_router(admin_router)
    app.include_router(audio_file_router)
    app.include_router(image_file_router)

    @app.get("/health", tags=["ops"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    # `backend/media` (see `app/infrastructure/media.py`). Locally it is
    # mounted even before it exists, since the local audio store creates it
    # on the first upload (bolt 041).
    if MEDIA_DIR.is_dir() or settings.environment == "local":
        app.mount(MEDIA_URL_PREFIX, StaticFiles(directory=MEDIA_DIR, check_dir=False), name="media")

    return app


app = create_app()
