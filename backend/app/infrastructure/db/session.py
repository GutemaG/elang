"""Async SQLAlchemy engine + session factory.

Same engine/session interface for SQLite (`aiosqlite`, local dev/test) and
PostgreSQL (`asyncpg`, real deployment) -- only the connection string differs,
per `data-stack.md`.
"""

from __future__ import annotations

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.config import get_settings
from app.infrastructure.db.url import normalize_database_url

_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        settings = get_settings()
        # Managed Postgres URLs arrive in libpq's dialect and have to be
        # translated before asyncpg will accept them -- see `url.py`.
        url, connect_args = normalize_database_url(settings.database_url)
        if url.startswith("sqlite"):
            # Allows the same connection's objects to be used across the
            # async event loop callbacks FastAPI schedules a request onto.
            connect_args = {"check_same_thread": False}
        _engine = create_async_engine(url, connect_args=connect_args)
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(
            bind=get_engine(), expire_on_commit=False, autoflush=False
        )
    return _session_factory


async def get_db_session() -> AsyncGenerator[AsyncSession]:
    """FastAPI dependency: one `AsyncSession` per request.

    Commits on success, rolls back on any exception -- this is the
    transaction boundary for "account creation + onboarding-selection
    attachment happen in one DB transaction" (per
    `ddd-02-technical-design.md`'s Reliability NFR).
    """
    session_factory = get_session_factory()
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
