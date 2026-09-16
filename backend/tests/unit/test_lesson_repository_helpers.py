"""Direct unit tests for `_ensure_utc` in
`app/infrastructure/db/lesson_repositories.py` -- the SQLite timezone-
round-trip normalization helper (same concern as `001-auth-service`'s
equivalent helper and its documented "bug #2" regression).
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta, timezone

from app.infrastructure.db.lesson_repositories import _ensure_utc


class TestEnsureUtc:
    def test_naive_datetime_is_treated_as_utc(self) -> None:
        naive = datetime(2026, 1, 1, 12, 0, 0)

        result = _ensure_utc(naive)

        assert result.tzinfo is UTC
        assert result.hour == 12

    def test_timezone_aware_datetime_in_another_zone_is_converted_to_utc(self) -> None:
        plus_five = timezone(timedelta(hours=5))
        aware = datetime(2026, 1, 1, 12, 0, 0, tzinfo=plus_five)

        result = _ensure_utc(aware)

        assert result.tzinfo == UTC
        assert result.hour == 7  # 12:00 +05:00 == 07:00 UTC

    def test_already_utc_datetime_is_returned_unchanged_in_value(self) -> None:
        already_utc = datetime(2026, 1, 1, 12, 0, 0, tzinfo=UTC)

        result = _ensure_utc(already_utc)

        assert result == already_utc
