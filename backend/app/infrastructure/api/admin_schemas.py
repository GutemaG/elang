"""Pydantic response schemas for the content admin API (`admin_routers.py`)."""

from __future__ import annotations

from pydantic import BaseModel


class AdminMeResponse(BaseModel):
    email: str
