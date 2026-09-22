"""Who may use the content admin API (ADR-16, bolt `034-admin-api-foundation`).

Pure Python, no framework imports.
"""

from __future__ import annotations


def parse_admin_emails(allow_list: str) -> frozenset[str]:
    """`ADMIN_EMAILS` is comma-separated; entries are trimmed and compared
    case-insensitively. Blank entries are ignored."""
    return frozenset(e.strip().lower() for e in allow_list.split(",") if e.strip())


def is_admin(email: str | None, allow_list: str) -> bool:
    """True only for a verified email on the allow-list. Fails closed: no
    email, or an empty allow-list, is never an admin."""
    if not email:
        return False
    return email.strip().lower() in parse_admin_emails(allow_list)
