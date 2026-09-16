"""Shared fixtures for the whole test suite.

Per the construction task's guidance: in-memory SQLite has connection-per-
engine quirks with async drivers, so every DB-backed fixture here uses a
fresh temp-file SQLite database per test instead.

Two different construction strategies are used deliberately:

- `async_engine`/`db_session` (pure-async, no HTTP layer): constructed and
  used entirely inside one pytest-asyncio-managed event loop for the test.
- `app_engine`/`make_client` (drives the DB through FastAPI's `TestClient`):
  the `AsyncEngine` is constructed with a plain, synchronous call and never
  touched until `TestClient`'s own event-loop portal opens it for the first
  time. Mixing an engine that has already been used inside a pytest-asyncio
  fixture loop with `TestClient`'s separate portal loop is the classic
  "Future attached to a different loop" failure mode with SQLAlchemy's async
  engine -- keeping these two engines/paths separate avoids it entirely.
"""

from __future__ import annotations

from collections.abc import AsyncGenerator, Generator
from pathlib import Path
from typing import Any

import pytest
import pytest_asyncio
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.infrastructure.api.error_handlers import register_exception_handlers
from app.infrastructure.api.lesson_routers import router as lesson_router
from app.infrastructure.api.routers import router as auth_router

# Imported for its side effect of registering the lesson-content bounded
# context's tables onto the shared `Base.metadata`, so `Base.metadata.create_all`
# below (used by every DB-backed test in the suite) creates them too.
from app.infrastructure.db import lesson_models  # noqa: F401
from app.infrastructure.db.models import Base
from app.infrastructure.db.session import get_db_session


@pytest.fixture
def db_path(tmp_path: Path) -> Path:
    """A fresh SQLite file with the `users`/`auth_sessions` schema created.

    Schema creation uses a plain *sync* SQLAlchemy engine so no event loop
    is ever associated with the file before whichever async engine actually
    exercises it (a test's own, or the FastAPI app under test's) opens it
    for the first time inside its own loop.
    """
    path = tmp_path / "test.db"
    sync_engine = create_engine(f"sqlite:///{path}")
    Base.metadata.create_all(sync_engine)
    sync_engine.dispose()
    return path


@pytest_asyncio.fixture
async def async_engine(db_path: Path) -> AsyncGenerator[AsyncEngine]:
    """An async engine for tests that talk to the DB directly (no HTTP
    layer), constructed and used entirely within this fixture/test's own
    pytest-asyncio event loop.
    """
    engine = create_async_engine(
        f"sqlite+aiosqlite:///{db_path}", connect_args={"check_same_thread": False}
    )
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(async_engine: AsyncEngine) -> AsyncGenerator[AsyncSession]:
    """A single `AsyncSession` for tests that want direct repository access."""
    factory = async_sessionmaker(bind=async_engine, expire_on_commit=False, autoflush=False)
    async with factory() as session:
        yield session


@pytest.fixture
def app_engine(db_path: Path) -> AsyncEngine:
    """An async engine constructed with a plain synchronous call (no loop
    touched yet), for the endpoint tests -- see module docstring.
    """
    return create_async_engine(
        f"sqlite+aiosqlite:///{db_path}", connect_args={"check_same_thread": False}
    )


@pytest.fixture
def make_client(app_engine: AsyncEngine) -> Generator[Any]:
    """Returns a factory `(google_verifier, apple_verifier) -> TestClient`.

    Builds a fresh FastAPI app (no lifespan -- verifiers are injected
    directly as fakes on `app.state`, never the real
    `GoogleTokenVerifier`/`AppleTokenVerifier`) with the real auth router and
    exception handlers, wired to the temp-file SQLite DB via a
    `get_db_session` dependency override that mirrors the production
    dependency's commit/rollback transaction boundary.
    """
    factory = async_sessionmaker(bind=app_engine, expire_on_commit=False, autoflush=False)

    async def override_get_db_session() -> AsyncGenerator[AsyncSession]:
        async with factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    def _make(google_verifier: object, apple_verifier: object) -> TestClient:
        app = FastAPI()
        register_exception_handlers(app)
        app.include_router(auth_router)
        app.include_router(lesson_router)
        app.state.google_verifier = google_verifier
        app.state.apple_verifier = apple_verifier
        app.dependency_overrides[get_db_session] = override_get_db_session
        return TestClient(app)

    yield _make
