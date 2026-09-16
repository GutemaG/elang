"""FastAPI application entrypoint: app instance, router registration, and
exception handlers.

Run locally with: `uv run uvicorn app.main:app --reload` (from `backend/`).
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.infrastructure.api.error_handlers import register_exception_handlers
from app.infrastructure.api.lesson_routers import router as lesson_router
from app.infrastructure.api.routers import router as auth_router
from app.infrastructure.external.apple_verifier import AppleTokenVerifier
from app.infrastructure.external.google_verifier import GoogleTokenVerifier
from app.infrastructure.logging_config import configure_logging


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


def create_app() -> FastAPI:
    app = FastAPI(title="Buna Auth Service", version="0.1.0", lifespan=lifespan)

    settings = get_settings()
    extra_origins = [o.strip() for o in settings.cors_allowed_origins.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=extra_origins,
        # Flutter Web's dev server picks whichever port is free/requested
        # run to run, so pin-listing origins is impractical locally. Only
        # active in `environment == "local"`; staging/production rely
        # solely on `cors_allowed_origins` above.
        allow_origin_regex=r"http://localhost:\d+" if settings.environment == "local" else None,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(app)
    app.include_router(auth_router)
    app.include_router(lesson_router)

    @app.get("/health", tags=["ops"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
