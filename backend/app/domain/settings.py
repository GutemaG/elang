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

`APP_CONFIG` holds the app versions the phone checks itself against (the
bean constants stay in code for now). The Appearance choice stays on the
phone.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Any

from app.domain.exceptions import InvalidSettingError

_TYPES: dict[str, type] = {"bool": bool, "int": int, "str": str}
_TYPE_NAMES = {"bool": "true or false", "int": "a whole number", "str": "text"}


@dataclass(frozen=True)
class Setting:
    """One known key: its type (`bool`, `int` or `str`), its default, and for
    a `str`, optionally the only values it may take, or a `pattern` (a
    regular expression the whole value must match)."""

    key: str
    type: str
    default: Any
    choices: tuple[str, ...] | None = None
    pattern: str | None = None

    def __post_init__(self) -> None:
        if self.type not in _TYPES:
            raise ValueError(f"{self.key}: unknown type {self.type!r}")
        if self.choices is not None and self.type != "str":
            raise ValueError(f"{self.key}: only a str setting takes choices")
        if self.pattern is not None and self.type != "str":
            raise ValueError(f"{self.key}: only a str setting takes a pattern")
        if self.pattern is not None and self.choices is not None:
            raise ValueError(f"{self.key}: takes choices or a pattern, not both")
        if not self.accepts(self.default):
            raise ValueError(f"{self.key}: the default {self.default!r} is not valid")

    def accepts(self, value: object) -> bool:
        """Whether `value` is of this setting's type (a bool is not an int
        here, though it is one in Python) and, if listed, one of its
        choices, or a match for its pattern."""
        expected = _TYPES[self.type]
        if expected is int and isinstance(value, bool):
            return False
        if not isinstance(value, expected):
            return False
        if self.pattern is not None and isinstance(value, str):
            return re.fullmatch(self.pattern, value) is not None
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
                if setting.choices:
                    expected = f"one of {', '.join(setting.choices)}"
                elif setting.pattern is not None:
                    expected = f"text matching {setting.pattern}"
                else:
                    expected = _TYPE_NAMES[setting.type]
                problems.append(f"{key}: expected {expected}")
        if problems:
            raise InvalidSettingError("; ".join(problems))


# Account settings, stored in `users.settings`.
ACCOUNT_SETTINGS = SettingsRegistry(
    [
        # 023-weekly-leagues (bolt 073): off keeps the learner out of
        # leagues, so nobody sees their name.
        Setting("show_in_leagues", "bool", True),
        # 024-app-localization (bolt 077): the language the app's own words
        # are shown in, so it follows the learner to a new phone. "" until
        # chosen. Any 2-3 letter code: the app decides which it has, and
        # shows English for one it lacks, so a new language needs no
        # change here.
        Setting("app_language", "str", "", pattern=r"(?:[a-z]{2,3})?"),
    ]
)

# App-wide configuration, stored in `app_config`. Never anything secret.
APP_CONFIG = SettingsRegistry(
    [
        # App updates: the oldest build number (the `+N` in `pubspec.yaml`,
        # Android's versionCode) still allowed to run on each platform. An
        # older app shows a blocking "Update needed" screen. 0 lets every
        # build run. Raise it only once the new build is out to everyone
        # in that store, and when old builds would break against this API.
        Setting("min_build_android", "int", 0),
        Setting("min_build_ios", "int", 0),
        # The newest iOS build in the App Store: an older app is offered
        # the update, without being made to take it. Android asks Google
        # Play instead, which knows when the update has reached that phone.
        Setting("latest_build_ios", "int", 0),
        # Where the iOS app's "Update" opens, e.g.
        # `https://apps.apple.com/app/id1234567890`. "" until it is listed.
        Setting("ios_store_url", "str", "", pattern=r"(?:https://\S+)?"),
    ]
)
