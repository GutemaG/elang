"""Reads and writes the Sounds tables (`sound_models.py`)."""

from __future__ import annotations

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import LanguageModel
from app.infrastructure.db.sound_models import SoundChartModel, SoundLetterModel


class SqlAlchemySoundRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def language(self, code: str) -> LanguageModel | None:
        return await self._session.get(LanguageModel, code)

    async def chart(self, language: str) -> SoundChartModel | None:
        return await self._session.get(SoundChartModel, language)

    async def charts(self, *, enabled_only: bool = False) -> list[SoundChartModel]:
        stmt = select(SoundChartModel).order_by(SoundChartModel.language)
        if enabled_only:
            stmt = stmt.where(SoundChartModel.enabled.is_(True))
        return list((await self._session.execute(stmt)).scalars())

    async def letters(self, language: str) -> list[SoundLetterModel]:
        """Every letter of the chart, by group then position. Groups come
        back in key order; callers order them by the chart's `groups`."""
        stmt = (
            select(SoundLetterModel)
            .where(SoundLetterModel.language == language)
            .order_by(SoundLetterModel.group_key, SoundLetterModel.position)
        )
        return list((await self._session.execute(stmt)).scalars())

    async def letter(self, letter_id: str) -> SoundLetterModel | None:
        return await self._session.get(SoundLetterModel, letter_id)

    async def next_position(self, language: str, group_key: str) -> int:
        stmt = select(func.max(SoundLetterModel.position)).where(
            SoundLetterModel.language == language, SoundLetterModel.group_key == group_key
        )
        current = (await self._session.execute(stmt)).scalar_one()
        return 0 if current is None else int(current) + 1

    async def add(self, row: SoundChartModel | SoundLetterModel) -> None:
        self._session.add(row)
        await self._session.flush()

    async def add_all(self, rows: list[SoundLetterModel]) -> None:
        self._session.add_all(rows)
        await self._session.flush()

    async def delete(self, row: SoundChartModel | SoundLetterModel) -> None:
        await self._session.delete(row)
        await self._session.flush()

    async def delete_chart(self, chart: SoundChartModel) -> None:
        """The chart and every letter, in one statement each, so letters
        pointing at each other go together."""
        await self._session.execute(
            delete(SoundLetterModel).where(SoundLetterModel.language == chart.language)
        )
        await self._session.delete(chart)
        await self._session.flush()

    async def flush(self) -> None:
        await self._session.flush()
