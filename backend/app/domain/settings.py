"""Settings with their defaults in code (022-light-and-dark-themes, FR-8 and
FR-9, bolt 071).

Two registries list every key the backend knows, each with its type and
default:

- `ACCOUNT_SETTINGS`: one learner's settings, stored as JSON in
  `users.settings`.
- `APP_CONFIG`: app-wide values the team may change without a deploy, one
  row per key in `app_config`.

**To add a setting**, add one `Setting` line to a registry. No migration,
seed or backfill: reading fills every key missing from storage with its
default, so the new key works at once for every existing account.

**Nothing secret may go in `APP_CONFIG`.** `GET /api/v1/config` returns it
to anyone, signed in or not.

Both start empty: no setting needs them yet (the Appearance choice stays on
the phone, and the bean constants stay in code for now).
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Any

from app.domain.exceptions import InvalidSettingError

_TYPES: dict[str, type] = {"bool": bool, "int": int, "str": str}
_TYPE_NAMES = {"bool": "true or false", "int": "a whole number", "str": "text"}


@dataclass(frozen=True)
class Setting:
    """One known key: its type (`bool`, `int` or `str`), its default, and for
    a `str`, optionally the only values it may take."""

    key: str
    type: str
    default: Any
    choices: tuple[str, ...] | None = None

    def __post_init__(self) -> None:
        if self.type not in _TYPES:
            raise ValueError(f"{self.key}: unknown type {self.type!r}")
        if self.choices is not None and self.type != "str":
            raise ValueError(f"{self.key}: only a str setting takes choices")
        if not self.accepts(self.default):
            raise ValueError(f"{self.key}: the default {self.default!r} is not valid")

    def accepts(self, value: object) -> bool:
        """Whether `value` is of this setting's type (a bool is not an int
        here, though it is one in Python) and, if listed, one of its
        choices."""
        expected = _TYPES[self.type]
        if expected is int and isinstance(value, bool):
            return False
        if not isinstance(value, expected):
            return False
        return self.choices is None or value in self.choices


class SettingsRegistry:
    """A set of known settings: resolves stored maps and checks updates."""

    def __init__(self, settings: Iterable[Setting]) -> None:
        self._settings: dict[str, Setting] = {}
        for setting in settings:
            if setting.key in self._settings:
                raise ValueError(f"{setting.key}: listed twice")
            self._settings[setting.key] = setting

    @property
    def keys(self) -> list[str]:
        return list(self._settings)

    def resolve(self, stored: Mapping[str, Any] | None) -> dict[str, Any]:
        """Every known key: its stored value if that is valid, else its
        default. Stored keys no longer known are left out."""
        stored = stored or {}
        return {
            key: stored[key] if key in stored and setting.accepts(stored[key]) else setting.default
            for key, setting in self._settings.items()
        }

    def invalid_keys(self, stored: Mapping[str, Any] | None) -> list[str]:
        """Known keys whose stored value is not valid (a bad hand edit)."""
        stored = stored or {}
        return [
            key
            for key, setting in self._settings.items()
            if key in stored and not setting.accepts(stored[key])
        ]

    def validate(self, changes: Mapping[str, Any]) -> None:
        """Raises `InvalidSettingError` naming every unknown key and every
        value of the wrong type, so a partial update is all or nothing."""
        problems = []
        for key, value in changes.items():
            setting = self._settings.get(key)
            if setting is None:
                problems.append(f"{key}: unknown setting")
            elif not setting.accepts(value):
                expected = (
                    f"one of {', '.join(setting.choices)}"
                    if setting.choices
                    else _TYPE_NAMES[setting.type]
                )
                problems.append(f"{key}: expected {expected}")
        if problems:
            raise InvalidSettingError("; ".join(problems))


# Account settings, stored in `users.settings`.
ACCOUNT_SETTINGS = SettingsRegistry([])

# App-wide configuration, stored in `app_config`. Never anything secret.
APP_CONFIG = SettingsRegistry([])
