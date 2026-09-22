"""Application configuration, loaded from environment variables (`.env` in
local dev, real environment variables in deployment). See `.env.example` for
the full list of placeholders -- no real secret values ever live in code.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    environment: str = "local"

    database_url: str = "sqlite+aiosqlite:///./dev.db"

    google_oauth_client_id: str = ""

    apple_services_id: str = ""
    apple_team_id: str = ""
    apple_key_id: str = ""
    # Apple's identity tokens are issued for either the app's bundle ID
    # (native Sign in with Apple) or the Services ID (web-based flow).
    # Both are accepted audiences; empty values are simply not checked.
    apple_bundle_id: str = ""

    apple_jwks_url: str = "https://appleid.apple.com/auth/keys"
    apple_issuer: str = "https://appleid.apple.com"

    session_ttl_days: int = 30

    # Comma-separated extra CORS origins (e.g. a deployed web app's real
    # domain). In `environment == "local"`, any `http://localhost:<port>`
    # origin is already allowed regardless of this list, since Flutter Web's
    # dev server port isn't fixed run to run -- see `main.py`.
    cors_allowed_origins: str = ""

    # Comma-separated Google-verified emails allowed on `/api/v1/admin/*`
    # (ADR-16, bolt `034-admin-api-foundation`). Empty means nobody is an
    # admin.
    admin_emails: str = ""

    # Recorded lesson audio on Cloudflare R2 (bolt `036-admin-audio-api`).
    # `audio_base_url` is the bucket's public address; the rest sign upload
    # links on the server. All are server-side only -- never sent to a
    # browser. Uploads answer 503 until every one is set.
    audio_base_url: str = ""
    r2_account_id: str = ""
    r2_bucket: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""

    # Cache TTL for Apple's JWKS, independent of key-rotation-triggered
    # refetches (ADR-2 / open item: refetch-once on an unknown `kid`).
    apple_jwks_cache_ttl_seconds: int = 3600


@lru_cache
def get_settings() -> Settings:
    return Settings()
