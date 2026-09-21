"""`normalize_database_url` -- the translation between a managed provider's
libpq-style URL and what SQLAlchemy's asyncpg driver actually accepts.

The failure this guards against is not subtle in effect but is very subtle
in its error message: leaving `sslmode` on the URL produces
`TypeError: connect() got an unexpected keyword argument 'sslmode'` from deep
inside asyncpg, which points at nothing useful.
"""

from __future__ import annotations

from app.infrastructure.db.url import normalize_database_url

NEON = (
    "postgresql://user:pw@ep-cool-name-123456-pooler.eu-central-1.aws.neon.tech"
    "/neondb?sslmode=require&channel_binding=require"
)


def test_sqlite_url_is_untouched() -> None:
    url, connect_args = normalize_database_url("sqlite+aiosqlite:///./dev.db")
    assert url == "sqlite+aiosqlite:///./dev.db"
    assert connect_args == {}


def test_neon_url_gets_the_async_driver() -> None:
    url, _ = normalize_database_url(NEON)
    assert url.startswith("postgresql+asyncpg://")


def test_libpq_only_params_are_stripped_from_the_url() -> None:
    url, _ = normalize_database_url(NEON)
    assert "sslmode" not in url
    assert "channel_binding" not in url


def test_sslmode_require_becomes_an_asyncpg_connect_arg() -> None:
    """TLS must survive the translation -- dropping `sslmode` without
    replacing it would silently downgrade the connection."""
    _, connect_args = normalize_database_url(NEON)
    assert connect_args == {"ssl": "require"}


def test_sslmode_disable_is_honoured() -> None:
    _, connect_args = normalize_database_url(
        "postgresql://user:pw@localhost:5432/buna?sslmode=disable"
    )
    assert connect_args == {"ssl": False}


def test_sslmode_prefer_adds_no_connect_arg() -> None:
    """`prefer` is asyncpg's own default; naming it explicitly would be a
    no-op at best and is not a value asyncpg's `ssl` argument accepts."""
    _, connect_args = normalize_database_url(
        "postgresql://user:pw@localhost:5432/buna?sslmode=prefer"
    )
    assert connect_args == {}


def test_legacy_postgres_scheme_is_upgraded() -> None:
    url, _ = normalize_database_url("postgres://user:pw@localhost:5432/buna")
    assert url.startswith("postgresql+asyncpg://")


def test_an_explicit_driver_is_left_alone() -> None:
    """A URL that already names its driver is one someone chose deliberately;
    overriding it would silently ignore that choice."""
    url, _ = normalize_database_url("postgresql+psycopg://user:pw@localhost:5432/buna")
    assert url.startswith("postgresql+psycopg://")


def test_host_and_database_survive_normalization() -> None:
    url, _ = normalize_database_url(NEON)
    assert "ep-cool-name-123456-pooler.eu-central-1.aws.neon.tech" in url
    assert url.endswith("/neondb")


def test_unknown_params_are_preserved() -> None:
    """Only the params asyncpg is known to reject are removed; anything else
    may be a driver argument someone set on purpose."""
    url, _ = normalize_database_url(
        "postgresql://user:pw@host/db?sslmode=require&statement_cache_size=0"
    )
    assert "statement_cache_size=0" in url
