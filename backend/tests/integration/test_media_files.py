"""Recorded lesson audio is served from `backend/media` at `/media`."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import MEDIA_DIR, create_app

# The clips are git-ignored, so a fresh clone has none to check.
pytestmark = pytest.mark.skipif(
    not (MEDIA_DIR / "audio").is_dir(), reason="no local recordings in backend/media"
)


async def test_a_recorded_clip_is_served() -> None:
    async with AsyncClient(transport=ASGITransport(app=create_app()), base_url="http://test") as c:
        response = await c.get("/media/audio/am/hello.m4a")

    assert response.status_code == 200
    assert len(response.content) > 0


async def test_a_missing_clip_is_a_404() -> None:
    async with AsyncClient(transport=ASGITransport(app=create_app()), base_url="http://test") as c:
        response = await c.get("/media/audio/am/no-such-word.m4a")

    assert response.status_code == 404
