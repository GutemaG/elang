"""Structured logging setup.

Per `coding-standards.md`: JSON in non-local environments, human-readable in
dev. A filter strips known-sensitive fields from any log record before it is
emitted -- defense-in-depth alongside the discipline of never passing
tokens/PII to `logger.info(...)` calls in the first place (see
`app/application/use_cases.py`, which only ever logs ids and enum values).
"""

from __future__ import annotations

import json
import logging
import sys
from typing import Any

_SENSITIVE_FIELDS = {
    "id_token",
    "identity_token",
    "session_token",
    "token_hash",
    "raw_session_token",
    "token_value",
    "token",
    "authorization",
}


class SensitiveDataFilter(logging.Filter):
    """Strips known-sensitive attributes from a log record's `__dict__`."""

    def filter(self, record: logging.LogRecord) -> bool:
        for field in _SENSITIVE_FIELDS:
            if hasattr(record, field):
                setattr(record, field, "[REDACTED]")
        return True


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            payload["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(payload)


def configure_logging(environment: str) -> None:
    root = logging.getLogger()
    root.handlers.clear()

    handler = logging.StreamHandler(stream=sys.stdout)
    handler.addFilter(SensitiveDataFilter())

    if environment == "local":
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
    else:
        handler.setFormatter(JsonFormatter())

    root.addHandler(handler)
    root.setLevel(logging.INFO if environment != "local" else logging.DEBUG)
