"""Normalizes a managed-Postgres URL into what SQLAlchemy + asyncpg accept.

Managed providers (Neon, Supabase, RDS) hand out libpq-style URLs:

    postgresql://user:pass@host/db?sslmode=require&channel_binding=require

Two things in that are wrong for this app, and both fail loudly but
unhelpfully if left alone:

- **The driver.** Bare `postgresql://` makes SQLAlchemy reach for psycopg2,
  which isn't installed and wouldn't be async anyway. It needs the explicit
  `postgresql+asyncpg://` prefix.
- **The query parameters.** `sslmode` and `channel_binding` are libpq's
  spelling. SQLAlchemy forwards unknown query params straight to the driver's
  `connect()`, and asyncpg has never accepted either, so they surface as
  `TypeError: connect() got an unexpected keyword argument 'sslmode'` --
  a message that says nothing about the real cause.

TLS is not dropped in the process: `sslmode=require` is translated into
asyncpg's own `ssl="require"` connect argument, which is the same guarantee
under a different name.

SQLite URLs pass through untouched, so local dev and the whole test suite
are unaffected by this module existing.
"""

from __future__ import annotations

from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

# libpq spells these; asyncpg does not accept them as `connect()` kwargs.
# `sslmode` is translated (see `_SSLMODE_TO_ASYNCPG`); the rest are dropped
# because asyncpg either negotiates them itself or does not support them.
_LIBPQ_ONLY_PARAMS = frozenset(
    {"sslmode", "channel_binding", "target_session_attrs", "options", "application_name"}
)

# asyncpg's `ssl` argument takes the same vocabulary as libpq's `sslmode`
# for the modes it supports. `prefer` has no asyncpg equivalent and is its
# default behaviour anyway, so it maps to no argument at all.
_SSLMODE_TO_ASYNCPG = {
    "require": "require",
    "verify-ca": "verify-ca",
    "verify-full": "verify-full",
    "disable": False,
    "allow": None,
    "prefer": None,
}


def normalize_database_url(database_url: str) -> tuple[str, dict[str, Any]]:
    """Return `(url, connect_args)` ready for `create_async_engine`.

    Non-Postgres URLs are returned unchanged with empty connect args; the
    SQLite `check_same_thread` argument stays where it was, in `session.py`,
    since it is about the event loop rather than about the URL.
    """
    scheme = urlsplit(database_url).scheme
    if not scheme.startswith("postgres"):
        return database_url, {}

    parts = urlsplit(database_url)
    connect_args: dict[str, Any] = {}

    kept_params: list[tuple[str, str]] = []
    for key, value in parse_qsl(parts.query, keep_blank_values=True):
        if key not in _LIBPQ_ONLY_PARAMS:
            kept_params.append((key, value))
            continue
        if key == "sslmode":
            ssl_value = _SSLMODE_TO_ASYNCPG.get(value.lower())
            if ssl_value is not None:
                connect_args["ssl"] = ssl_value

    # `postgres://` is the legacy alias some providers still emit; both it
    # and `postgresql://` become the async driver's own scheme. A URL that
    # already names a driver (`postgresql+asyncpg`) is left as-is.
    normalized_scheme = parts.scheme
    if "+" not in normalized_scheme:
        normalized_scheme = "postgresql+asyncpg"

    normalized = urlunsplit(
        (normalized_scheme, parts.netloc, parts.path, urlencode(kept_params), parts.fragment)
    )
    return normalized, connect_args
